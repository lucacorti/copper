# Copper

**Pure Elixir HTTP/2 client based on Ankh**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add copper to your list of dependencies in `mix.exs`:

        def deps do
          [{:copper, "~> 0.0.1"}]
        end

  2. Ensure copper is started before your application:

        def application do
          [applications: [:copper]]
        end
