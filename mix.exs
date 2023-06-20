defmodule Nopass.MixProject do
  use Mix.Project

  def project do
    [
      app: :nopass,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      test_coverage: [
        summary: [
          threshold: 90
        ],
        ignore_modules: [Nopass.Repo]
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Nopass.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.10"},
      {:nanoid, "~> 2.0.5"},
      {:postgrex, ">= 0.0.0"}
    ]
  end
end
