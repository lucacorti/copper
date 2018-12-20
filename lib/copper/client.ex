defmodule Copper.Client do
  @moduledoc """
  Copper Client
  """

  use GenServer

  require Logger

  alias Ankh.{Connection, Stream}
  alias Copper.{Request, Response}

  def start_link(args, options \\ []) do
    GenServer.start_link(__MODULE__, args, options)
  end

  def init(args) do
    {:ok, address} = Keyword.fetch(args, :address)

    {:ok,
     %{
       connection: nil,
       streams: %{},
       ssl_options: Keyword.get(args, :ssl_options, []),
       uri: Request.parse_address(address)
     }}
  end

  def request(client, %Request{options: options} = request) do
    controlling_process = Keyword.get(options, :controlling_process)
    GenServer.call(client, {:request, request, controlling_process})
  end

  def handle_call(
        {:request, request, controlling_process},
        from,
        %{
          connection: nil,
          uri: uri
        } = state
      ) do
    with {:ok, connection} <- Connection.start_link(uri: uri),
         :ok <- Connection.connect(connection) do
      handle_call({:request, request, controlling_process}, from, %{
        state
        | connection: connection
      })
    end
  end

  def handle_call(
        {:request, %Request{options: options} = request, nil = _controlling_process},
        from,
        %{
          connection: connection,
          streams: streams,
          uri: uri
        } = state
      ) do
    request =
      request
      |> Request.put_uri(uri)

    with {:ok, stream_id, stream} <- Connection.start_stream(connection, options),
         :ok <- send_headers(stream, request),
         :ok <- send_data(stream, request) do
      {:noreply, %{state | streams: Map.put(streams, stream_id, {from, %Response{}})}}
    else
      error ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call(
        {:request, %Request{options: options} = request, controlling_process},
        _from,
        %{
          connection: connection,
          uri: uri
        } = state
      )
      when is_pid(controlling_process) do
    request =
      request
      |> Request.put_uri(uri)

    with {:ok, stream_id, stream} <- Connection.start_stream(connection, options),
         :ok <- send_headers(stream, request),
         :ok <- send_data(stream, request),
         :ok <- send_trailers(stream, request) do
      {:reply, {:ok, stream_id}, state}
    else
      error ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_info({:ankh, :headers, stream_id, headers}, %{streams: streams} = state) do
    with {to, response} <- Map.get(streams, stream_id) do
      streams =
        streams
        |> Map.put(stream_id, {to, %{response | headers: headers}})

      {:noreply, %{state | streams: streams}}
    else
      error ->
        {:stop, error, error, state}
    end
  end

  def handle_info({:ankh, :data, stream_id, data, _end_stream}, %{streams: streams} = state) do
    with {to, %Response{body: body} = response} <- Map.get(streams, stream_id) do
      streams =
        streams
        |> Map.put(stream_id, {to, %{response | body: [data | body]}})

      {:noreply, %{state | streams: streams}}
    else
      error ->
        {:stop, error, error, state}
    end
  end

  def handle_info({:ankh, :stream, stream_id, :closed}, %{streams: streams} = state) do
    with {to, %Response{body: body} = response} <- Map.get(streams, stream_id) do
      GenServer.reply(to, {:ok, %{response | body: Enum.reverse(body)}})
      {:noreply, %{state | streams: Map.delete(streams, stream_id)}}
    else
      error ->
        {:stop, error, error, state}
    end
  end

  def handle_info({:ankh, :error, 0 = _stream_id, error}, state) do
    {:stop, error, error, state}
  end

  def handle_info({:ankh, :error, stream_id, error}, %{streams: streams} = state) do
    with {to, _response} <- Map.get(streams, stream_id) do
      GenServer.reply(to, {:error, error})
    end

    {:stop, error, error, state}
  end

  defp send_data(stream, request) do
    case Request.data_frame(request) do
      nil ->
        :ok

      data ->
        with {:ok, _stream_state} <- Stream.send(stream, data) do
          :ok
        else
          error ->
            {:error, error}
        end
    end
  end

  defp send_headers(stream, request) do
    with {:ok, _stream_state} <- Stream.send(stream, Request.headers_frame(request)) do
      :ok
    else
      error ->
        {:error, error}
    end
  end

  defp send_trailers(stream, request) do
    case Request.trailers_frame(request) do
      nil ->
        :ok

      trailers ->
        with {:ok, _stream_state} <- Stream.send(stream, trailers) do
          :ok
        else
          error ->
            {:error, error}
        end
    end
  end
end
