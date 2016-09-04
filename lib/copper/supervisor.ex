defmodule Copper.Supervisor do
  use Supervisor

  alias Copper.Client

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    [
      worker(Client.Supervisor, []),
      worker(Client.Registry, [])
    ]
    |> supervise(strategy: :one_for_one)
  end
end
