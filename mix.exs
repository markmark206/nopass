defmodule Nopass.MixProject do
  use Mix.Project

  def project do
    [
      app: :nopass,
      version: "0.1.0",
      elixir: "~> 1.14",
      name: "Nopass",
      description:
        "Nopass simplifies managing magic codes (aka 'one-time passwords') and login tokens for passwordless experiences.",
      package: [
        name: "nopass",
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/markmark206/nopass"}
      ],
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/markmark206/nopass",
      test_coverage: [
        summary: [
          threshold: 100
        ],
        ignore_modules: [Nopass.Repo]
      ],
      docs: [
        main: "Nopass",
        extras: ["README.md", "LICENSE"]
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
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.10"},
      {:nanoid, "~> 2.1"},
      {:postgrex, ">= 0.0.0"}
    ]
  end
end
