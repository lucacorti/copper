defmodule Copper.Client do
  use GenServer

  alias Copper.Client
  alias Ankh.Connection
  alias Ankh.Frame.{Data, Headers, Settings}

  @max_stream_id 2_147_483_647

  def start_link(args, options \\ []) do
    GenServer.start_link(__MODULE__, args, options)
  end

  def init([target: target, stream: stream, ssl_options: ssl_opts]) do
    {:ok, %{last_stream_id: -1, connection: nil, target: target,
    stream: stream, ssl_options: ssl_opts}}
  end

  def get(address, headers \\ [], data \\ nil, options \\ []) do
    request("GET", address, headers, data, options)
  end

  def head(address, headers \\ [], data \\ nil, options \\ []) do
    request("HEAD", address, headers, data, options)
  end

  def post(address, headers \\ [], data \\ nil, options \\ []) do
    request("POST", address, headers, data, options)
  end

  def put(address, headers \\ [], data \\ nil, options \\ []) do
    request("PUT", address, headers, data, options)
  end

  def delete(address, headers \\ [], data \\ nil, options \\ []) do
    request("DELETE", address, headers, data, options)
  end

  def connect(address, headers \\ [], data \\ nil, options \\ []) do
    request("CONNECT", address, headers, data, options)
  end

  def options(address, headers \\ [], data \\ nil, options \\ []) do
    request("OPTIONS", address, headers, data, options)
  end

  def trace(address, headers \\ [], data \\ nil, options \\ []) do
    request("TRACE", address, headers, data, options)
  end

  def request(method, address, headers \\ [], data \\ nil, options \\ []) do
    uri = parse_address(address)
    via = {:via, Client.Registry, uri}

    with :undefined <- Client.Registry.whereis_name(uri) do
      receiver = Keyword.get(options, :receiver)
      target = if is_pid(receiver), do: receiver, else: self()
      stream = Keyword.get(options, :stream, false)
      mode = if is_boolean(stream), do: stream, else: false
      ssl_opts = Keyword.get(options, :ssl_options, [])
      args = [target: target, stream: mode, ssl_options: ssl_opts]
      opts = [name: via]
      {:ok, _pid} = Supervisor.start_child(Client.Supervisor, [args, opts])
    end

    full_headers = [{":method", method} | headers_for_uri(uri)] ++ headers
    GenServer.call(via, {:request, uri, method, full_headers, data})
  end

  def handle_call({:request, uri, _method, _headers, _data} = request, from,
  %{connection: nil, target: target, stream: stream, ssl_options: ssl_opts}
  = state) do
    opts = [receiver: target, stream: stream, ssl_options: ssl_opts]
    with {:ok, pid} <- Connection.start_link(opts),
         :ok <- Connection.connect(pid, uri),
         :ok <- Connection.send(pid, %Settings{}) do
      handle_call(request, from, %{state | connection: pid})
    else
      _ ->
        raise "Can't start connection for #{uri}"
    end
  end

  def handle_call(request, from, %{connection: connection,
  last_stream_id: lsid} = state) when lsid == @max_stream_id do
    Connection.close(connection)
    handle_call(request, from, %{state | connection: nil, last_stream_id: -1})
  end

  def handle_call({:request, _uri, method, headers, data}, _from,
  %{last_stream_id: last_stream_id, connection: connection} = state) do
    stream_id = last_stream_id + 2
    with :ok <- do_request(connection, stream_id, method, headers, data) do
      {:reply, :ok, %{state | last_stream_id: stream_id}}
    else
      error ->
        {:reply, error, state}
    end
  end

  defp do_request(nil, _stream_id, _method, _headers, _data) do
    {:error, :not_connected}
  end

  defp do_request(connection, stream_id, "GET", headers, nil) do
    Connection.send(connection, %Headers{stream_id: stream_id,
      flags: %Headers.Flags{end_headers: true},
      payload: %Headers.Payload{header_block_fragment: headers}
    })
  end

  defp do_request(connection, stream_id, "GET", headers, data) do
    Connection.send(connection, %Headers{stream_id: stream_id,
      flags: %Headers.Flags{end_headers: true},
      payload: %Headers.Payload{header_block_fragment: headers}
    })
    Connection.send(connection, %Data{stream_id: stream_id,
      flags: %Data.Flags{end_stream: true},
      payload: %Data.Payload{data: data}
    })
  end

  defp do_request(connection, stream_id, "HEAD", headers, nil) do
    Connection.send(connection, %Headers{stream_id: stream_id,
      flags: %Headers.Flags{end_headers: true},
      payload: %Headers.Payload{header_block_fragment: headers}
    })
  end

  defp do_request(_connection, _stream_id, method, _headers, _data) do
    raise "Method \"#{method}\" not implemented yet."
  end

  defp parse_address(address) when is_binary(address) do
    address
    |> URI.parse
    |> parse_address
  end

  defp parse_address(%URI{scheme: nil}) do
    raise "No scheme present in address"
  end

  defp parse_address(%URI{scheme: "http"}) do
    raise "Plaintext HTTP is not supported"
  end

  defp parse_address(%URI{host: nil}) do
    raise "No hostname present in address"
  end

  defp parse_address(%URI{} = uri), do: uri

  defp headers_for_uri(%URI{path: nil} = uri) do
    headers_for_uri(%URI{uri | path: "/"})
  end

  defp headers_for_uri(%URI{scheme: scheme, authority: authority, path: path})
  do
    [{":scheme", scheme}, {":authority", authority}, {":path", path}]
  end
end
