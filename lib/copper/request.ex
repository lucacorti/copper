defmodule Copper.Request do

  alias Ankh.Frame.{Data, Headers}

  defstruct uri: nil,
            method: "GET",
            path: "/",
            headers: [],
            data: nil,
            options: []

  def data(%__MODULE__{data: nil}), do: nil
  def data(%__MODULE__{data: data}) do
    %Data{
      flags: %Data.Flags{end_stream: true},
      payload: %Data.Payload{data: data}
    }
  end

  def headers(%__MODULE__{headers: headers, method: method, path: path, uri: %URI{scheme: scheme, authority: authority}}) do
    headers = [{":method", method}, {":scheme", scheme}, {":authority", authority}, {":path", path}]
      |> Enum.into(headers)

    %Headers{
      payload: %Headers.Payload{hbf: headers}
    }
  end

  def parse_address(address) when is_binary(address) do
    address
    |> URI.parse()
    |> parse_address
  end

  def parse_address(%URI{scheme: nil}), do: raise("No scheme present in address")
  def parse_address(%URI{scheme: "http"}), do: raise("Plaintext HTTP is not supported")
  def parse_address(%URI{host: nil}), do: raise("No hostname present in address")
  def parse_address(%URI{} = uri), do: uri
end
