defmodule Copper.Response do
  @moduledoc """
  Copper Response
  """
  defstruct body: [],
            headers: [],
            trailers: []

  @type header_name :: String.t
  @type header_value :: String.t

  @content_length "content-length"
  @content_type "content-type"
  @date "date"
  @status ":status"

  @spec content_length!(%__MODULE__{}) :: header_value
  def content_length!(%__MODULE__{} = response),
    do: response
          |> find_header!(@content_length)

  @spec content_type!(%__MODULE__{}) :: header_value
  def content_type!(%__MODULE__{} = response),
    do: response
          |> find_header!(@content_type)

  @spec date!(%__MODULE__{}) :: header_value
  def date!(%__MODULE__{} = response),
    do: response
          |> find_header!(@date)

  @spec status!(%__MODULE__{}) :: header_value
  def status!(%__MODULE__{} = response),
    do: response
          |> find_header!(@status)

  @spec find_header!(%__MODULE__{}, header_name) :: header_value
  def find_header!(%__MODULE__{} = response, name),
    do: response
          |> find_headers(name)
          |> hd()

  @spec find_header(%__MODULE__{}, header_name) :: header_value
  def find_header(%__MODULE__{} = response, name) do
    try do
      response
        |> find_header!(name)
    rescue
      _ ->
        nil
    end
  end

  @spec find_headers(%__MODULE__{}, header_name) :: [header_value]
  def find_headers(%__MODULE__{headers: headers}, name) do
    headers
    |> Enum.reduce([], fn
      {^name, value}, acc -> [value | acc]
      _, acc -> acc
    end)
  end
end
