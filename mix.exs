defmodule Copper.Mixfile do
  use Mix.Project

  def project do
    [
      app: :copper,
      version: "0.0.1",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: "Pure Elixir HTTP/2 client based on Ankh",
      package: package(),
      deps: deps()
    ]
  end

  defp package() do
    [
      maintainers: ["Luca Corti"],
      licenses: ["MIT"],
      links: %{GitHub: "https://github.com/lucacorti/copper"}
    ]
  end

  def application() do
    [extra_applications: [:logger], mod: {Copper, []}]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:credo, ">= 0.0.0", only: :dev},
      {:dialyxir, ">= 0.0.0", only: :dev},
      {:ankh, ">= 0.4.3"}
    ]
  end
end
