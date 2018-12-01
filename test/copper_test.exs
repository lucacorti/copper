defmodule CopperTest do
  use ExUnit.Case
  doctest Copper

  alias Copper.{Client, Request}

  setup do
    {:ok, pid} = Client.start_link(address: "https://www.google.it")
    %{client: pid}
  end

  test "head", %{client: client} do
    assert :ok = Client.request(client, %Request{method: "HEAD"})
    assert_receive {:ankh, :headers, 1, _headers}, 1_000
  end

  test "get", %{client: client} do
    assert :ok = Client.request(client, %Request{})
    assert_receive {:ankh, :headers, 1, _headers}, 1_000
    assert_receive {:ankh, :data, 1, _data, _end_stream}, 1_000
  end

  test "post", %{client: client} do
    assert :ok = Client.request(client, %Request{method: "POST", data: "data"})
    assert_receive {:ankh, :headers, 1, _headers}, 1_000
    assert_receive {:ankh, :data, 1, _data, _end_stream}, 1_000
  end
end
