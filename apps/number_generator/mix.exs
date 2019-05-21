defmodule NumberGenerator.MixProject do
  use Mix.Project

  def project do
    [
      app: :number_generator,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8.1",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {NumberGenerator.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:confex_config_provider, "~> 0.1.0"},
      {:blake2, "~> 1.0"},
      {:libcluster, "~> 3.0", git: "https://github.com/AlexKovalevych/libcluster.git", branch: "kube_namespaces"},
      {:core, in_umbrella: true}
    ]
  end

  defp aliases do
    [
      "ecto.setup": []
    ]
  end
end
