#!/usr/bin/env bash
# .devcontainer/setup.sh

# BeamTracks SDK
cd /workspace/apps/beamtracks-sdk || exit
poetry install --no-interaction --no-ansi

# Trackrunner (Elixir)
cd /workspace/apps/trackrunner
mix deps.get

# Pulsekeeper (Elixir/Gleam)
cd /workspace/apps/pulsekeeper
mix deps.get
gleam get

# CLI (Elixir)
cd /workspace/apps/beamtracks_cli
mix deps.get
