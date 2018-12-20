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
end
