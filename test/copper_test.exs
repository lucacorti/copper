defmodule CopperTest do
  use ExUnit.Case
  doctest Copper

  alias Copper.Client
  require Logger

  setup_all do
    {:ok, pid} = Client.start_link(address: "https://www.google.it")
    %{client: pid}
  end

  test "get", ctx do
    :ok = Client.get(ctx.client)
  end
end
