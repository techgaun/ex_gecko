defmodule ExGecko.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_gecko,
     version: "0.0.3",
     elixir: "~> 1.2",
     elixirc_paths: ["lib"],
     description: "Elixir SDK to communicate with Geckoboard's API",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     package: package,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test, "coveralls.semaphore": :test],
     docs: [logo: "logo/brighterlink_logo.png",
            extras: ["README.md"]]
   ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :httpoison, :porcelain, :tzdata]]
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
      {:httpoison, "~> 0.8.0 or ~> 0.9.0"},
      {:poison, "~> 1.5.2"},
      {:porcelain, "~> 2.0"},
      {:excoveralls, "~> 0.5.4", only: :test},
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev},
      {:dogma, "~> 0.1", only: [:dev, :test]},
      {:mock, "~> 0.1.1", only: :test},
      {:timex, "~> 2.1.4"},
      {:tzdata, "~> 0.5.8"}
    ]
  end

  defp package do
    [
      maintainers: [
        "Samar Acharya",
        "Bruce Wang"
      ],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Brightergy/ex_gecko"},
      files: ~w(config datasets lib logo mix.exs README.md)
    ]
  end
end
