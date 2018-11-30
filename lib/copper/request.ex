defmodule Copper.Request do
  def parse_address(address) when is_binary(address) do
    address
    |> URI.parse()
    |> parse_address
  end

  def parse_address(%URI{scheme: nil}), do: raise("No scheme present in address")
  def parse_address(%URI{scheme: "http"}), do: raise("Plaintext HTTP is not supported")
  def parse_address(%URI{host: nil}), do: raise("No hostname present in address")
  def parse_address(%URI{} = uri), do: uri

  def headers_for_uri(%URI{scheme: scheme, authority: authority, path: path}, method) do
    [{":method", method}, {":scheme", scheme}, {":authority", authority}, {":path", path}]
  end
end
