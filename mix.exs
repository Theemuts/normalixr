defmodule Normalixr.Mixfile do
  use Mix.Project

  @version "0.3.1"

  def project do
    [app: :normalixr,
     version: @version,
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
     deps: deps,
     description: "Normalization and backfilling Ecto Schemas",
     package: package,
     name: "Normalixr",
     docs: [source_ref: "v#{@version}"],
            source_url: "https://github.com/theemuts/normalixr"]
  end

  def application do
    [applications: [:logger, :ecto]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp package do
    [maintainers: ["Thomas van Doornmalen"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/theemuts/normalixr"}]
  end

  defp deps do
    [{:ecto, ">= 2.0.0-beta and < 2.1.0"},
     # Docs dependencies
     {:earmark, "~> 0.2", only: :dev},
     {:ex_doc, "~> 0.11", only: :dev}]
  end
end
