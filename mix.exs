defmodule HttpEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :http_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      dialyzer: dialyzer_config(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.3", optional: true, only: [:dev], runtime: false},
      {:httpoison, "~> 2.0"},
      {:styler, "~> 1.0", optional: true, only: [:dev, :test]},
      {:nimble_ownership, "~> 1.0"},
      {:tracing, "~> 0.2.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp dialyzer_config do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_file: {:no_warn, "priv/plts/project.plt"},
      format: :dialyxir,
      ignore_warnings: ".dialyzer_ignore.exs",
      list_unused_filters: true,
      flags: ["-Wunmatched_returns", :error_handling, :underspecs]
    ]
  end
end
