#!/bin/sh
dagger run <<'DAGGER'
  # Build Trackrunner (Elixir)
  container {
    from: "hexpm/elixir:1.16.2-erlang-26.2.2-alpine-3.19.1",
    workdir: "/app",
    mount: {
      source: "./trackrunner",
      target: "/app"
    },
    exec: ["mix", "deps.get"]
  }

  # Build Pulsekeeper (Gleam)
  container {
    from: "ghcr.io/gleam-lang/gleam:v1.0.0",
    workdir: "/app",
    mount: {
      source: "./pulsekeeper",
      target: "/app"
    },
    exec: ["gleam", "build"]
  }

  print("✅ Both Trackrunner and Pulsekeeper built successfully.")
DAGGER
