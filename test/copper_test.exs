defmodule CopperTest do
  use ExUnit.Case, async: true
  doctest Copper

  alias Ankh.HTTP.{Request, Response}

  @uri URI.parse("https://www.google.com")

  test "sync get" do
    assert {:ok, _client, %Response{}} =
             @uri
             |> Copper.new()
             |> Copper.request(%Request{})
  end

  test "async get" do
    assert {:ok, client, reference} =
             @uri
             |> Copper.new()
             |> Copper.async(%Request{})

    assert {:ok, _client, %Response{}} = Copper.await(client, reference)
  end
end
