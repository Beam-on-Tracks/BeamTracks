defmodule Beamtracks.CLI.Parser do
  @moduledoc "CLI definition using Optimus (keyword‑list style)"
  alias Optimus

  @spec build() :: Optimus.t()
  def build do
    Optimus.new!(
      name: "beamtracks",
      description: "CLI for BeamTracks",
      version: "0.1.0",
      author: "Rahmi Pruitt",
      subcommands: [
        watch: [
          name: "watch",
          about: "Watch live agent pings",
          subcommands: [
            agents: [
              name: "agents",
              about: "Stream agent heartbeats in real time"
            ]
          ]
        ],
        status: [
          name: "status",
          about: "Static status commands",
          subcommands: [
            agents: [
              name: "agents",
              about: "Show connected agents count"
            ],
            workflows: [
              name: "workflows",
              about: "List cached workflows"
            ]
          ]
        ]
      ]
    )
  end
end

