defmodule HttpEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :http_ex,
      deps: deps(),
      description: "Abstract HTTP library with unique mocking capabilities",
      dialyzer: dialyzer_config(),
      docs: docs(),
      elixir: "~> 1.18",
      name: "HTTPEx",
      organization: "wuunder",
      package: package(),
      source_url: "https://github.com/wuunder/http_ex",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.1.0"
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
      {:excoveralls, "~> 0.18.0", optional: true, only: :test},
      {:ex_doc, "~> 0.31", optional: true, only: :dev, runtime: false},
      {:finch, "~> 0.18", optional: true},
      {:httpoison, "~> 2.0", optional: true},
      {:nimble_ownership, "~> 1.0"},
      {:styler, "~> 1.0", optional: true, only: [:dev, :test]},
      {:sweet_xml, "~> 0.7"},
      {:tracing, "~> 0.2.0"}
    ]
  end

  defp package do
    [
      name: "http_ex",
      files: ~w(lib mix.exs CHANGELOG.md LICENSE.md README*),
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/http_ex/changelog.html",
        "GitHub" => "https://github.com/wuunder/http_ex",
        "Docs" => "https://hexdocs.pm/http_ex"
      }
    ]
  end

  defp docs do
    [
      main: "HTTPEx",
      extras: ["README.md", "CHANGELOG.md"]
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
