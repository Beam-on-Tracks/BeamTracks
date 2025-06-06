defmodule Beamtracks.CLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamtracks_cli,
      version: "0.1.0",
      escript: [main_module: Beamtracks.CLI, name: "beamtracks"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:optimus, "~> 0.5.0"},
      {:phoenix_client, "~> 0.3"},
      {:jason, "~> 1.4"}
    ]
  end
end
