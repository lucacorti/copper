defmodule Copper do
  @moduledoc """
  Copper HTTP Client
  """

  alias Ankh.HTTP
  alias HTTP.{Request, Response}

  @type options :: keyword()

  @opaque t :: %__MODULE__{protocol: Ankh.Protocol.t() | nil, uri: URI.t()}
  defstruct protocol: nil, uri: nil

  @doc """
  Returns a new Http struct.
  """
  @spec new(URI.t()) :: t()
  def new(uri), do: %__MODULE__{uri: uri}

  @doc """
  Performs an HTTP request

  Returns the client stucture to use for subsequent requests.
  """
  @spec request(t(), Request.t(), options) :: {:ok, t(), Response.t()} | {:error, term}
  def request(client, request, options \\ [])

  def request(%__MODULE__{protocol: nil, uri: uri} = client, request, options) do
    with {:ok, protocol} <- HTTP.connect(uri, options) do
      request(%{client | protocol: protocol}, request, options)
    end
  end

  def request(%__MODULE__{} = client, request, options) do
    with {:ok, client, reference} <- async(client, request, options) do
      await(client, reference)
    end
  end

  @doc """
  Performs an asynchronous HTTP request

  Returns the request reference to be used with `await/2`.
  """
  @spec async(t(), Request.t(), options()) :: {:ok, t(), reference()} | {:error, any()}
  def async(client, request, options \\ [])

  def async(%__MODULE__{protocol: nil, uri: uri} = client, request, options) do
    with {:ok, protocol} <- HTTP.connect(uri, options) do
      async(%__MODULE__{client | protocol: protocol}, request)
    end
  end

  def async(%__MODULE__{protocol: protocol} = client, request, _options) do
    request = HTTP.put_header(request, "user-agent", "copper/1.0")

    with {:ok, protocol, reference} <- HTTP.request(protocol, request) do
      {:ok, %{client | protocol: protocol}, reference}
    end
  end

  @doc """
  Returns a response for an asynchronous HTTP request

  Returns the client stucture to use for subsequent requests.
  """
  @spec await(t(), reference()) :: {:ok, t(), Response.t()} | {:error, any()}
  def await(%__MODULE__{protocol: protocol} = client, reference) do
    with {:ok, protocol, response} <- receive_msg(protocol, %Response{}, reference) do
      {:ok, %{client | protocol: protocol}, response}
    end
  end

  defp receive_msg(protocol, response, request_ref) do
    receive do
      msg ->
        handle_msg(protocol, request_ref, msg, response)
    after
      5_000 ->
        {:error, :timeout}
    end
  end

  defp handle_msg(protocol, request_ref, msg, response) do
    with {:ok, protocol, responses} <- HTTP.stream(protocol, msg),
         {:ok, protocol, {response, true = _complete}} <-
           handle_responses(protocol, response, responses, request_ref) do
      {:ok, protocol, response}
    else
      :unknown ->
        receive_msg(protocol, response, request_ref)

      {:error, reason} ->
        {:error, reason}

      {:ok, protocol, {response, false = _complete}} ->
        receive_msg(protocol, response, request_ref)
    end
  end

  defp handle_responses(protocol, response, responses, request_ref) do
    {response, complete} =
      responses
      |> Enum.reduce({response, false}, fn
        {:data, ^request_ref, data, complete}, {%Response{body: body} = response, _complete} ->
          body = if is_nil(body), do: [data], else: [data | body]
          {%Response{response | body: body}, complete}

        {:headers, ^request_ref, headers, complete}, {response, _complete} ->
          {%Response{response | headers: headers}, complete}

        {:error, ^request_ref, reason, complete}, {_response, _complete} ->
          {{:error, reason}, complete}
      end)

    {:ok, protocol, {response, complete}}
  end
end
