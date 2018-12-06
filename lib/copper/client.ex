defmodule Copper.Client do
  @moduledoc """
  Copper Client
  """

  use GenServer

  require Logger

  alias Ankh.{Connection, Stream}
  alias Copper.Request

  def start_link(args, options \\ []) do
    GenServer.start_link(__MODULE__, args, options)
  end

  def init(args) do
    {:ok, address} = Keyword.fetch(args, :address)

    {:ok,
     %{
       uri: %URI{Request.parse_address(address) | path: nil},
       connection: nil,
       ssl_options: Keyword.get(args, :ssl_options, [])
     }}
  end

  def request(client, %Request{options: options} = request) do
    options = [controlling_process: self()]
    |> Keyword.merge(options)

    GenServer.call(client, {:request, %{request | options: options}})
  end

  def handle_call(
        {:request, request},
        from,
        %{
          connection: nil,
          uri: uri,
        } = state
      ) do
    {:ok, connection} = Connection.start_link(uri: uri)
    :ok = Connection.connect(connection)
    handle_call({:request, request}, from, %{state | connection: connection})
  end

  def handle_call(
        {:request, %Request{options: options} = request},
        _from,
        %{
          connection: connection,
          uri: uri,
        } = state
      ) do
    request = %Request{request | uri: uri}

    with {:ok, stream} <- Connection.start_stream(connection, options),
         :ok <- send_headers(stream, request),
         :ok <- send_data(stream, request) do
      {:reply, :ok, state}
    else
      error ->
        {:reply, {:error, error}, state}
    end
  end

  def terminate(reason, %{connection: nil}) do
    Logger.error("Connection terminate: #{reason}")
  end

  def terminate(reason, %{connection: connection}) do
    Logger.error("Connection terminate: #{reason}")
    Connection.close(connection)
  end

  defp send_data(stream, request) do
    case Request.data(request) do
      nil ->
        :ok

      data ->
        with {:ok, _stream_state} <- Stream.send(stream, data) do
          :ok
        else
          error ->
            {:error, error}
        end
      end
  end

  defp send_headers(stream, request) do
    with {:ok, _stream_state} <- Stream.send(stream, Request.headers(request)) do
      :ok
    else
      error ->
        {:error, error}
    end
  end
end
