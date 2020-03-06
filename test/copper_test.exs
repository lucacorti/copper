defmodule CopperTest do
  use ExUnit.Case, async: true
  doctest Copper

  alias Ankh.HTTP.Request

  @uri URI.parse("https://www.google.com")

  test "sync get" do
    assert client = Copper.new(@uri)
    assert {:ok, client, response} = Copper.request(client, %Request{})
  end

  test "async get" do
    assert client = Copper.new(@uri)
    assert {:ok, client, reference} = Copper.async(client, %Request{})
    assert {:ok, client, response} = Copper.await(client, reference)
  end
end
