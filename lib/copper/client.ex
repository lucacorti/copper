defmodule Copper.Client do
  use GenServer

  require Logger

  alias Ankh.{Connection, Stream}
  alias Ankh.Frame.{Headers, Settings}
  alias Copper.Request

  def start_link(args, options \\ []) do
    {_, args} =
      Keyword.get_and_update(args, :controlling_process, fn
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

    {:ok,
     %{
       uri: %URI{Request.parse_address(address) | path: nil},
       controlling_process: Keyword.get(args, :controlling_process),
       connection: nil,
       ssl_options: Keyword.get(args, :ssl_options, []),
       send_settings: settings,
       recv_settings: settings,
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

  def handle_call(
        {:request, _, _, _, _, _} = request,
        from,
        %{
          connection: nil,
          uri: uri,
          controlling_process: controlling_process
        } = state
      ) do
    {:ok, connection} = Connection.start_link(uri: uri, controlling_process: controlling_process)
    :ok = Connection.connect(connection)
    handle_call(request, from, %{state | connection: connection})
  end

  def handle_call(
        {:request, method, path, headers, _data, options},
        _from,
        %{
          connection: connection,
          uri: uri,
        } = state
      ) do
    headers =
      %URI{uri | path: path}
      |> Request.headers_for_uri(method)
      |> Enum.into(headers)

    mode = Keyword.get(options, :mode, :reassemble)

    with {:ok, stream} <- Connection.start_stream(connection, mode),
         {:ok, _stream_state} <-
           Stream.send(stream, %Headers{
             payload: %Headers.Payload{hbf: headers}
           }) do
      {:reply, :ok, state}
    else
      error ->
        {:reply, {:error, error}, state}
    end
  end

  def terminate(reason, %{connection: nil}) do
    Logger.error("Connection terminate: #{reason}")
  end

  def terminate(reason, %{connection: connection}) do
    Logger.error("Connection terminate: #{reason}")
    Connection.close(connection)
  end
end
