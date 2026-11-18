defmodule LightningE2E.MixProject do
  use Mix.Project

  # The Playwright browser suite, ported from assets/test/e2e to playwright_ex.
  # A project of its own: it drives a running Lightning (`bin/e2e start`), like
  # the JS suite, so it needs neither Lightning's code nor its test database.
  def project do
    [
      app: :lightning_e2e,
      version: "0.0.0",
      elixir: "~> 1.18",
      elixirc_paths: ["lib"],
      test_paths: ["specs"],
      test_load_filters: [&String.ends_with?(&1, "_spec.exs")],
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger, :inets]]

  defp deps do
    [
      {:playwright,
       github: "ftes/playwright_ex",
       ref: "3e9b47591e9fb72ea2fc1648f485af034c6c111b"},
      {:jason, "~> 1.4"}
    ]
  end
end
