defmodule CopperTest do
  use ExUnit.Case
  doctest Copper

  alias Copper.Client

  setup do
    {:ok, pid} = Client.start_link(address: "https://www.google.it")
    %{client: pid}
  end

  test "get", %{client: client} do
    assert :ok = Client.get(client)
    assert_receive {:ankh, :headers, 1, _headers} = msg, 1_000
    assert_receive {:ankh, :data, 1, _data, _end_stream} = msg, 1_000
  end
end
