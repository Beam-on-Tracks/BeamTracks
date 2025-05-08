#!/bin/sh

# Run all commands non-interactively
export DAGGER_NO_PROGRESS=1
export DAGGER_NO_INTERACTIVE=1
export DAGGER_NO_NAG=1
set -e        # exit immediately if any command exits non-zero

echo "Building Trackrunner..."
dagger call container \
  from "hexpm/elixir:1.16.2-erlang-26.2.2-alpine-3.19.1" \
  with-directory "/app" "$(pwd)/../apps/trackrunner" \
  with-workdir "/app" \
  with-exec "mix deps.get" \
  with-exec "mix compile"

echo "Building Pulsekeeper..."
dagger call container \
  from "ghcr.io/gleam-lang/gleam:v1.0.0" \
  with-directory "/app" "$(pwd)/../apps/pulsekeeper" \
  with-workdir "/app" \
  with-exec "gleam build"

echo "Building CLI..."
dagger call container \
  from "hexpm/elixir:1.16.2-erlang-26.2.2-alpine-3.19.1" \
  with-directory "/app" "$(pwd)/../apps/beamtracks_cli" \
  with-workdir "/app" \
  with-exec "mix deps.get" \
  with-exec "mix escript.build"

echo "✅ All apps built successfully."
