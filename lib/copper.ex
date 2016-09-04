defmodule Copper do
  use Application

  def start(_type, _args) do
    Copper.Supervisor.start_link()
  end
end
