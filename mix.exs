defmodule Copper.Mixfile do
  use Mix.Project

  def project do
    [
      app: :copper,
      version: "0.0.1",
      elixir: "~> 1.2",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      description: "Pure Elixir HTTP/2 client based on Ankh",
      package: package,
      deps: deps
    ]
  end

  defp package do
    [
      maintainers: ["Luca Corti"],
      licenses: ["MIT"],
      links: %{ "GitHub": "https://github.com/lucacorti/copper" }
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ssl],
     mod: {Copper, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:credo, ">= 0.0.0", only: :dev},
      {:dialyxir, ">= 0.0.0", only: :dev},
      {:ankh, "~> 0.0.5"}
    ]
  end
end
