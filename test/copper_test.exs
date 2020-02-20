defmodule CopperTest do
  use ExUnit.Case, async: true
  doctest Copper

  alias Ankh.HTTP.Request
  alias Copper.Client

  @uri URI.parse("https://www.google.com")

  test "sync get" do
    assert client = Client.new(@uri)
    assert {:ok, client, response} = Client.request(client, %Request{})
  end

  test "async get" do
    assert client = Client.new(@uri)
    assert {:ok, client, reference} = Client.async(client, %Request{})
    assert {:ok, client, response} = Client.await(client, reference)
  end
end
