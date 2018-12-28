defmodule Copper.Client do
  @moduledoc """
  Copper Client
  """

  use GenServer

  require Logger

  alias Ankh.{Connection, Stream}
  alias Ankh.Frame.{Data, Headers}
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
       uri: parse_address(address)
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
        {:request, request, controlling_process},
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

    with {:ok, stream_id, stream} <-
           Connection.start_stream(connection, nil, controlling_process),
         :ok <- send_headers(stream, request),
         :ok <- send_data(stream, request),
         :ok <- send_trailers(stream, request) do
      if controlling_process == nil do
        {:noreply, %{state | streams: Map.put(streams, stream_id, {from, %Response{}})}}
      else
        {:reply, {:ok, stream_id}, state}
      end
    else
      error ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_info({:ankh, :headers, stream_id, headers, end_stream}, %{streams: streams} = state) do
    with {to, response} <- Map.get(streams, stream_id) do
      if end_stream do
        GenServer.reply(to, {:ok, %{response | headers: headers}})
        {:noreply, %{state | streams: Map.delete(streams, stream_id)}}
      else
        streams =
          streams
          |> Map.put(stream_id, {to, %{response | headers: headers}})

        {:noreply, %{state | streams: streams}}
      end
    else
      error ->
        {:stop, error, error, state}
    end
  end

  def handle_info({:ankh, :data, stream_id, data, end_stream}, %{streams: streams} = state) do
    with {to, %Response{body: body} = response} <- Map.get(streams, stream_id) do
      if end_stream do
        GenServer.reply(to, {:ok, %{response | body: Enum.reverse([data | body])}})
        {:noreply, %{state | streams: Map.delete(streams, stream_id)}}
      else
        streams =
          streams
          |> Map.put(stream_id, {to, %{response | body: [data | body]}})

        {:noreply, %{state | streams: streams}}
      end
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
    case data_frame(request) do
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
    with {:ok, _stream_state} <- Stream.send(stream, headers_frame(request)) do
      :ok
    else
      error ->
        {:error, error}
    end
  end

  defp send_trailers(stream, request) do
    case trailers_frame(request) do
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

  defp headers_frame(%Request{
         body: body,
         headers: headers,
         method: method,
         path: path,
         trailers: trailers,
         uri: %URI{scheme: scheme, authority: authority}
       }) do
    headers =
      [{":method", method}, {":scheme", scheme}, {":authority", authority}, {":path", path}]
      |> Enum.into(headers)

    %Headers{
      flags: %Headers.Flags{end_stream: body == nil && List.first(trailers) == nil},
      payload: %Headers.Payload{hbf: headers}
    }
  end

  defp data_frame(%Request{body: nil}), do: nil

  defp data_frame(%Request{
         body: body,
         trailers: trailers
       }) do
    %Data{
      flags: %Data.Flags{end_stream: List.first(trailers) == nil},
      payload: %Data.Payload{data: body}
    }
  end

  defp trailers_frame(%Request{trailers: []}), do: nil

  defp trailers_frame(%Request{
         trailers: trailers
       }) do
    %Headers{
      flags: %Headers.Flags{end_stream: true},
      payload: %Headers.Payload{hbf: trailers}
    }
  end

  defp parse_address(address) when is_binary(address) do
    address
    |> URI.parse()
    |> parse_address
  end

  defp parse_address(%URI{scheme: nil}), do: raise("No scheme present in address")
  defp parse_address(%URI{scheme: "http"}), do: raise("Plaintext HTTP is not supported")
  defp parse_address(%URI{host: nil}), do: raise("No hostname present in address")
  defp parse_address(%URI{} = uri), do: %{uri | path: nil}
end
