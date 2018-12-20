defmodule Copper.Request do
  @moduledoc """
  Copper Request
  """

  defstruct uri: nil,
            method: "GET",
            path: "/",
            headers: [],
            trailers: [],
            body: nil,
            options: []

  @type header_name :: String.t()
  @type header_value :: String.t()

  @spec put_uri(%__MODULE__{}, %URI{}) :: %__MODULE__{}
  def put_uri(%__MODULE__{} = request, uri),
    do: %__MODULE__{request | uri: uri}

  @spec put_body(%__MODULE__{}, iodata) :: %__MODULE__{}
  def put_body(%__MODULE__{} = request, body),
    do: %__MODULE__{request | body: body}

  @spec put_header(%__MODULE__{}, header_name, header_value) :: %__MODULE__{}
  def put_header(%__MODULE__{headers: headers} = request, header, value),
    do: %__MODULE__{request | headers: [{header, value} | headers]}

  @spec put_trailer(%__MODULE__{}, header_name, header_value) :: %__MODULE__{}
  def put_trailer(%__MODULE__{trailers: trailers} = request, trailer, value),
    do: %__MODULE__{request | trailers: [{trailer, value} | trailers]}

  @spec put_method(%__MODULE__{}, String.t()) :: %__MODULE__{}
  def put_method(%__MODULE__{} = request, method),
    do: %__MODULE__{request | method: method}

  @spec put_option(%__MODULE__{}, atom, term) :: %__MODULE__{}
  def put_option(%__MODULE__{options: options} = request, option, value),
    do: %__MODULE__{request | options: [{option, value} | options]}

  @spec put_path(%__MODULE__{}, String.t()) :: %__MODULE__{}
  def put_path(%__MODULE__{} = request, path),
    do: %__MODULE__{request | path: path}
end
