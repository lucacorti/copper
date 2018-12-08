defmodule CopperTest do
  use ExUnit.Case, async: true
  doctest Copper

  alias Copper.{Client, Request}

  @address "https://www.google.com"

  setup do
    {:ok, pid} = Client.start_link(address: @address)
    sync_request = %Request{}
    async_request =
      sync_request
      |> Request.put_option(:controlling_process, self())
    %{client: pid, async_request: async_request, sync_request: sync_request}
  end

  test "sync get", %{client: client, sync_request: sync_request} do
    assert {:ok, response} = Client.request(client, sync_request)
  end

  test "async head", %{client: client, async_request: async_request} do
    request =
      async_request
      |> Request.put_method("HEAD")

    assert :ok = Client.request(client, request)
    receive_headers(1)
    receive_closed(1)
  end

  test "async get", %{client: client, async_request: async_request} do
    assert :ok = Client.request(client, async_request)
    receive_headers(1)
    receive_data(1)
    receive_closed(1)
  end

  test "async post", %{client: client, async_request: async_request} do
    request =
      async_request
      |> Request.put_method("POST")
      |> Request.put_body("data")

    assert :ok = Client.request(client, request)
    receive_headers(1)
    receive_data(1)
  end

  test "async multiple streams", %{client: client, async_request: async_request} do
    request =
      async_request
      |> Request.put_method("HEAD")
    assert :ok = Client.request(client, request)
    receive_headers(1)
    receive_closed(1)

    assert :ok = Client.request(client, async_request)
    receive_headers(3)
    receive_data(3)
    receive_closed(3)

    request =
      async_request
      |> Request.put_method("POST")
      |> Request.put_body("data")
    assert :ok = Client.request(client, request)
    receive_headers(5)
    receive_data(5)
    receive_closed(5)
  end

  defp receive_headers(stream_id) do
    assert_receive {:ankh, :headers, ^stream_id, _headers}, 1_000
  end

  defp receive_data(stream_id) do
    assert_receive {:ankh, :data, ^stream_id, _data, end_stream}, 1_000

    unless end_stream do
      receive_data(stream_id)
    end
  end

  defp receive_closed(stream_id) do
    assert_receive {:ankh, :stream, ^stream_id, :closed}, 1_000
  end
end
