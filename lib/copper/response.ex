defmodule Copper.Response do
  @moduledoc """
  Copper Response
  """
  defstruct body: [],
            headers: [],
            trailers: []

  @type header_name :: String.t()
  @type header_value :: String.t()

  @status ":status"

  @spec status!(%__MODULE__{}) :: header_value
  def status!(%__MODULE__{} = response),
    do:
      response
      |> header(@status)
      |> hd()

  @spec header(%__MODULE__{}, header_name) :: [header_value]
  def header(%__MODULE__{headers: headers}, name) do
    headers
    |> Enum.reduce([], fn
      {^name, value}, acc -> [value | acc]
      _, acc -> acc
    end)
  end

  @spec trailer(%__MODULE__{}, header_name) :: [header_value]
  def trailer(%__MODULE__{trailers: trailers}, name) do
    trailers
    |> Enum.reduce([], fn
      {^name, value}, acc -> [value | acc]
      _, acc -> acc
    end)
  end
end
