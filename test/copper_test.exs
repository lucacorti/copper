defmodule CopperTest do
  use ExUnit.Case
  doctest Copper

  alias Copper.{Client, Request}

  @address "https://www.google.com"

  setup do
    {:ok, pid} = Client.start_link(address: @address)
    %{client: pid}
  end

  test "head", %{client: client} do
    assert :ok = Client.request(client, %Request{method: "HEAD"})
    assert_receive {:ankh, :headers, 1, _headers}, 1_000
  end

  test "get", %{client: client} do
    assert :ok = Client.request(client, %Request{})
    assert_receive {:ankh, :headers, _, _headers}, 1_000
    assert_receive {:ankh, :data, _, _data, _end_stream}, 1_000
  end

  test "post", %{client: client} do
    assert :ok = Client.request(client, %Request{method: "POST", data: "data"})
    assert_receive {:ankh, :headers, _, _headers}, 1_000
    assert_receive {:ankh, :data, _, _data, _end_stream}, 1_000
  end

  test "multiple requests", %{client: client} do
    assert :ok = Client.request(client, %Request{method: "HEAD"})
    assert_receive {:ankh, :headers, 1, _headers}, 1_000

    assert :ok = Client.request(client, %Request{})
    assert_receive {:ankh, :headers, 3, _headers}, 1_000
    assert_receive {:ankh, :data, 3, _data, _end_stream}, 1_000

    assert :ok = Client.request(client, %Request{method: "POST", data: "data"})
    assert_receive {:ankh, :headers, 5, _headers}, 1_000
    assert_receive {:ankh, :data, 5, _data, _end_stream}, 1_000
  end
end
