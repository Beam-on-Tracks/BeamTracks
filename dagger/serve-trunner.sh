#!/bin/sh
dagger run <<'DAGGER'
  container {
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
DAGGER
