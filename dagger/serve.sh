#!/bin/sh
dagger run <<'DAGGER'
  # Serve Trackrunner
  elixir := container {
    from: "hexpm/elixir:1.16.2-erlang-26.2.2-alpine-3.19.1",
    workdir: "/app",
    mount: {
      source: "./trackrunner",
      target: "/app"
    },
    env: {
      MIX_ENV: "dev"
    },
    exec: ["mix", "phx.server"],
    expose: [4000]
  }

  # Serve Pulsekeeper
  gleam := container {
    from: "ghcr.io/gleam-lang/gleam:v1.0.0",
    workdir: "/app",
    mount: {
      source: "./pulsekeeper",
      target: "/app"
    },
    exec: ["gleam", "run"],
    expose: [4040]
  }

  when dagger.io/util#parallel([elixir, gleam]) {
    print("🌐 Both services are now live: Trackrunner on 4000, Pulsekeeper on 4040.")
  }
DAGGER
