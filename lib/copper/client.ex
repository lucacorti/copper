defmodule Copper.Client do
  use GenServer

  alias Copper.Client
  alias Ankh.{Connection, Frame}
  alias Ankh.Frame.{Data, Headers}

  def start_link(%URI{} = uri, options \\ []) do
    GenServer.start_link(__MODULE__, uri, options)
  end

  def init(uri) do
    {:ok, %{uri: uri, last_stream_id: -1, connection: nil}}
  end

  def get(address, headers \\ [], data \\ nil) do
    request("GET", address, headers, data)
  end

  def head(address, headers \\ [], data \\ nil) do
    request("HEAD", address, headers, data)
  end

  def post(address, headers \\ [], data \\ nil) do
    request("POST", address, headers, data)
  end

  def put(address, headers \\ [], data \\ nil) do
    request("PUT", address, headers, data)
  end

  def delete(address, headers \\ [], data \\ nil) do
    request("DELETE", address, headers, data)
  end

  def connect(address, headers \\ [], data \\ nil) do
    request("CONNECT", address, headers, data)
  end

  def options(address, headers \\ [], data \\ nil) do
    request("OPTIONS", address, headers, data)
  end

  def trace(address, headers \\ [], data \\ nil) do
    request("TRACE", address, headers, data)
  end

  def request(method, address, headers, data) do
    uri = parse_address(address)
    via = {:via, Client.Registry, uri}

    with :undefined <- Client.Registry.whereis_name(uri) do
      options = [name: via]
      {:ok, pid} = Supervisor.start_child(Client.Supervisor, [uri, options])
    end

    full_headers = [{":method", method} | headers_for_uri(uri)] ++ headers
    GenServer.call(via, {:request, method, full_headers, data})
  end

  def handle_call(request, from, %{uri: uri, connection: nil} = state) do
    with {:ok, pid} <- Connection.start_link(uri) do
      handle_call(request, from, %{state | connection: pid})
    else
      _ ->
        raise "Can't start connection for #{uri}"
    end
  end

  def handle_call({:request, method, headers, data}, _from,
  %{last_stream_id: last_stream_id, connection: connection} = state) do
    stream_id = last_stream_id + 2
    with :ok <- do_request(connection, stream_id, method, headers, data) do
      {:reply, :ok, %{state | last_stream_id: stream_id}}
    else
      error ->
        {:reply, error, state}
    end
  end

  defp do_request(connection, stream_id, "GET", headers, nil) do
    Connection.send(connection, %Frame{stream_id: stream_id, type: :headers,
      flags: %Headers.Flags{end_headers: true},
      payload: %Headers.Payload{header_block_fragment: headers}
    })
  end

  defp do_request(connection, stream_id, "GET", headers, data) do
    Connection.send(connection, %Frame{stream_id: stream_id, type: :headers,
      flags: %Headers.Flags{end_headers: true},
      payload: %Headers.Payload{header_block_fragment: headers}
    })
    Connection.send(connection, %Frame{stream_id: stream_id, type: :data,
      flags: %Data.Flags{end_stream: true},
      payload: %Data.Payload{data: data}
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

  defp parse_address(%URI{host: nil}) do
    raise "No hostname present in address"
  end

  defp parse_address(%URI{scheme: "http"}) do
    raise "Plaintext HTTP is not supported"
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
