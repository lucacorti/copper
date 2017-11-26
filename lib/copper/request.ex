defmodule Copper.Request do
  alias Ankh.Frame.{Data, Headers, Utils}

  def headers(stream_id, "GET", headers, max_frame_size) do
    {:ok, Utils.split(%Headers{
        stream_id: stream_id,
        payload: %Headers.Payload{hbf: headers}
      }, max_frame_size)}
  end

  def headers(stream_id, "HEAD", headers, max_frame_size) do
    {:ok, Utils.split(%Headers{
        stream_id: stream_id,
        payload: %Headers.Payload{hbf: headers}
      }, max_frame_size)}
  end

  def headers(_stream_id, method, _headers, _max_frame_size) do
    {:error, "Method #{method} not implemented yet."}
  end

  def data(_stream_id, _method, nil, _max_frame_size), do: {:ok, []}

  def data(stream_id, "GET", data, max_frame_size) do
    {:ok, Utils.split(%Data{
        stream_id: stream_id,
        payload: %Data.Payload{data: data}
      }, max_frame_size, true)
    }
  end

  def parse_address(address) when is_binary(address) do
    address
    |> URI.parse
    |> parse_address
  end

  def parse_address(%URI{scheme: nil}), do: raise "No scheme present in address"
  def parse_address(%URI{scheme: "http"}), do: raise "Plaintext HTTP is not supported"
  def parse_address(%URI{host: nil}), do: raise "No hostname present in address"
  def parse_address(%URI{} = uri), do: uri

  def headers_for_uri(%URI{scheme: scheme, authority: authority, path: path}, method) do
    [{":method", method}, {":scheme", scheme}, {":authority", authority}, {":path", path}]
  end
end
