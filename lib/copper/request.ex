defmodule Copper.Request do
  @moduledoc """
  Copper Request
  """

  alias Ankh.Frame.{Data, Headers}

  defstruct uri: nil,
            method: "GET",
            path: "/",
            headers: [],
            trailers: [],
            body: nil,
            options: []

  def put_uri(%__MODULE__{} = request, uri),
    do: %__MODULE__{request | uri: uri}

  def put_body(%__MODULE__{} = request, body),
    do: %__MODULE__{request | body: body}

  def put_header(%__MODULE__{headers: headers} = request, header, value),
    do: %__MODULE__{request | headers: [{header, value} | headers]}

  def put_trailer(%__MODULE__{trailers: trailers} = request, trailer, value),
    do: %__MODULE__{request | trailers: [{trailer, value} | trailers]}

  def put_method(%__MODULE__{} = request, method),
    do: %__MODULE__{request | method: method}

  def put_option(%__MODULE__{options: options} = request, option, value),
    do: %__MODULE__{request | options: [{option, value} | options]}

  def put_path(%__MODULE__{} = request, path),
    do: %__MODULE__{request | path: path}

  def parse_address(address) when is_binary(address) do
    address
    |> URI.parse()
    |> parse_address
  end

  def parse_address(%URI{scheme: nil}), do: raise("No scheme present in address")
  def parse_address(%URI{scheme: "http"}), do: raise("Plaintext HTTP is not supported")
  def parse_address(%URI{host: nil}), do: raise("No hostname present in address")
  def parse_address(%URI{} = uri), do: %{uri | path: nil}

  def headers_frame(%__MODULE__{
        body: body,
        headers: headers,
        method: method,
        path: path,
        trailers: trailers,
        uri: %URI{scheme: scheme, authority: authority}
      }) when method == "HEAD" or method == "GET" do
    headers =
      [{":method", method}, {":scheme", scheme}, {":authority", authority}, {":path", path}]
      |> Enum.into(headers)

    %Headers{
      flags: %Headers.Flags{end_stream: body == nil && List.first(trailers) == nil},
      payload: %Headers.Payload{hbf: headers}
    }
  end

  def headers_frame(%__MODULE__{
        headers: headers,
        method: method,
        path: path,
        trailers: _trailers,
        uri: %URI{scheme: scheme, authority: authority}
      }) do
    headers =
      [{":method", method}, {":scheme", scheme}, {":authority", authority}, {":path", path}]
      |> Enum.into(headers)

    %Headers{
      payload: %Headers.Payload{hbf: headers}
    }
  end

  def data_frame(%__MODULE__{body: nil}), do: nil

  def data_frame(%__MODULE__{
        body: body,
        trailers: trailers
    }) do
    %Data{
      flags: %Data.Flags{end_stream: List.first(trailers) == nil},
      payload: %Data.Payload{data: body}
    }
  end

  def trailers_frame(%__MODULE__{trailers: []}), do: nil

  def trailers_frame(%__MODULE__{
        trailers: trailers
      }) do
    %Headers{
      flags: %Headers.Flags{end_stream: true},
      payload: %Headers.Payload{hbf: trailers}
    }
  end
end
