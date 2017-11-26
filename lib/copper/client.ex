defmodule Copper.Client do
  use GenServer

  require Logger

  alias Ankh.{Connection, Stream}
  alias Ankh.Frame.{Data, GoAway, Ping, Settings, WindowUpdate}
  alias HPack.Table
  alias Copper.Request

  @max_stream_id 2_147_483_647

  def start_link(args, options \\ []) do
    {_, args} = Keyword.get_and_update(args, :controlling_process, fn
      nil ->
        {self(), self()}
      value ->
        {value, value}
    end)
    GenServer.start_link(__MODULE__, args, options)
  end

  def init(args) do
    {:ok, address} = Keyword.fetch(args, :address)
    %Settings{payload: settings} = Keyword.get(args, :settings, %Settings{})
    {:ok, send_hpack} = Table.start_link(settings.header_table_size)
    {:ok, recv_hpack} = Table.start_link(settings.header_table_size)

    {:ok, %{
      uri: %URI{Request.parse_address(address) | path: nil},
      controlling_process: Keyword.get(args, :controlling_process),
      connection: nil,
      last_stream_id: -1,
      streams: %{},
      ssl_options: Keyword.get(args, :ssl_options, []),
      send_hpack: send_hpack,
      send_settings: settings,
      recv_hpack: recv_hpack,
      recv_settings: settings,
      window_size: 0
    }}
  end

  def get(client, path \\ "/", headers \\ [], data \\ nil, options \\ []) do
    request(client, "GET", path, headers, data, options)
  end

  def head(client, path \\ "/", headers \\ [], data \\ nil, options \\ []) do
    request(client, "HEAD", path, headers, data, options)
  end

  def post(client, path \\ "/", headers \\ [], data \\ nil, options \\ []) do
    request(client, "POST", path, headers, data, options)
  end

  def put(client, path \\ "/", headers \\ [], data \\ nil, options \\ []) do
    request(client, "PUT", path, headers, data, options)
  end

  def delete(client, path \\ "/", headers \\ [], data \\ nil, options \\ []) do
    request(client, "DELETE", path, headers, data, options)
  end

  def connect(client, path \\ "/", headers \\ [], data \\ nil, options \\ []) do
    request(client, "CONNECT", path, headers, data, options)
  end

  def options(client, path \\ "/", headers \\ [], data \\ nil, options \\ []) do
    request(client, "OPTIONS", path, headers, data, options)
  end

  def trace(client, path \\ "/", headers \\ [], data \\ nil, options \\ []) do
    request(client, "TRACE", path, headers, data, options)
  end

  def request(client, method, path, headers, data, options) do
    GenServer.call(client, {:request, method, path, headers, data, options})
  end

  def handle_call({:request, _, _, _, _, _} = request, from,
  %{connection: nil, uri: uri, recv_settings: recv_settings} = state) do
    {:ok, connection} = Connection.start_link(uri: uri)
    :ok = Connection.connect(connection)
    :ok = Connection.send(connection, %Settings{payload: recv_settings})
    handle_call(request, from, %{state | connection: connection})
  end

  def handle_call({:request, _, _, _, _, _} = request, from,
  %{connection: connection, last_stream_id: lsid} = state) when lsid === @max_stream_id do
    Connection.close(connection)
    handle_call(request, from, %{state | connection: nil, last_stream_id: -1})
  end

  def handle_call({:request, method, path, headers, data, options}, _from,
  %{connection: connection, uri: uri, last_stream_id: last_stream_id, streams: streams, send_hpack: table, send_settings: settings} = state) do
    headers = %URI{uri | path: path}
    |> Request.headers_for_uri(method)
    |> Enum.into(headers)
    |> HPack.encode(table)
    id = last_stream_id + 2
    mode = Keyword.get(options, :mode, :reassemble)
    with stream <- Stream.new(connection, id, mode),
         {:ok, frames} <- Request.headers(id, method, headers, settings.max_frame_size),
         {:ok, stream} <- Stream.send(stream, frames),
         {:ok, frames} <- Request.data(id, method, data, settings.max_frame_size),
         {:ok, stream } <- Stream.send(stream, frames) do
      streams = Map.put(streams, id, stream)
      {:reply, :ok, %{state | streams: streams, last_stream_id: id}}
    else
      error ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_info({:ankh, :frame, %Ping{stream_id: 0, length: 8, flags: %{ack: false} = flags} = frame},
  %{connection: connection} = state) do
    :ok = Connection.send(connection, %Ping{frame |
      flags: %{
        flags | ack: true
      }
    })
    {:noreply, state}
  end

  def handle_info({:ankh, :frame, %Settings{stream_id: 0, flags: %{ack: false}, payload: payload} = frame},
  %{connection: connection, send_hpack: send_hpack} = state) do
    :ok = Connection.send(connection, %Settings{frame |
      flags: %Settings.Flags{ack: true}, payload: nil, length: 0
    })
    HPack.Table.resize(payload.header_table_size, send_hpack)
    {:noreply, %{state | send_settings: payload}}
  end

  def handle_info({:ankh, :frame, %Settings{stream_id: 0, flags: %{ack: true}}}, state) do
    {:noreply, state}
  end

  def handle_info({:ankh, :frame, %WindowUpdate{stream_id: 0, payload: %{window_size_increment: 0}}}, state) do
    Logger.error "PROTOCOL ERROR: received WINDOW_UPDATE with window_size_increment == 0"
    {:stop, :protocol_error, state}
  end

  def handle_info({:ankh, :frame, %WindowUpdate{stream_id: 0, payload: %{window_size_increment: increment}}},
  %{window_size: window_size} = state) do
    {:noreply, %{state | window_size: window_size + increment}}
  end

  def handle_info({:ankh, :frame, %GoAway{stream_id: 0, payload: %{error_code: code}}}, state) do
    {:stop, code, state}
  end

  def handle_info({:ankh, :frame, %{stream_id: id} = frame}, %{connection: connection, streams: streams} = state) do
    with stream when not is_nil(stream) <- Map.get(streams, id),
         {:ok, stream} <- Stream.recv(stream, frame) do
      process_frame(frame, stream, state)

      case frame do
        %Data{length: length} when length > 0 ->
          spawn(fn ->
            window_update = %WindowUpdate{
              payload: %WindowUpdate.Payload{
                window_size_increment: length
              }
            }
            Connection.send(connection, %{window_update | stream_id: 0})
            Stream.send(stream, %{window_update | stream_id: id})
        end)
        _ ->
          :ok
      end

      {:noreply, %{state | streams: Map.put(streams, id, stream)}}
    else
      nil ->
        Logger.error "STREAM #{id} ERROR: unknown stream, received #{inspect frame}"
        {:noreply, state}
      {:error, reason} = error ->
        Logger.error "STREAM #{id} ERROR: received #{inspect frame}: #{inspect reason}"
        {:stop, error, state}
    end
  end

  def terminate(_reason, %{connection: connection, last_stream_id: lsid}) do
    Connection.send(connection, %GoAway{
      payload: %GoAway.Payload{
        last_stream_id: lsid,
        error_code: :no_error
      }
    })
    :ok = Connection.close(connection)
  end

  defp process_frame(%{flags: %{end_headers: true}},
  %{id: id, recv_hbf: hbf}, %{recv_hpack: recv_hpack, controlling_process: controlling_process}) do
    headers = hbf
    |> Enum.join()
    |> HPack.decode(recv_hpack)
    |> Enum.into(%{})
    Logger.debug fn -> "STREAM #{id} received headers: #{inspect headers}" end
    Process.send(controlling_process, {:copper, :headers, id, headers}, [])
  end

  defp process_frame(%Data{flags: %{end_stream: true}},
  %{id: id, recv_data: recv_data, mode: :reassemble}, %{controlling_process: controlling_process}) do
    Logger.debug fn -> "STREAM #{id} mode: reassemble, received full data" end
    Process.send(controlling_process, {:copper, :data, id, recv_data}, [])
  end

  defp process_frame(%Data{flags: %{end_stream: end_stream}, payload: %{data: data}},
  %{id: id, mode: :streaming}, %{controlling_process: controlling_process}) do
    Logger.debug fn -> "STREAM #{id} mode: streaming, received partial data" end
    Process.send(controlling_process, {:copper, :stream_data, id, data, end_stream}, [])
  end

  defp process_frame(_frame, _stream, _state), do: :ok
end
