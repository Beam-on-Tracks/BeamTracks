#!/bin/sh
dagger run <<'DAGGER'
  container {
    from: "ghcr.io/gleam-lang/gleam:v1.0.0",
    workdir: "/app",
    mount: {
      source: "./pulsekeeper",
      target: "/app"
    },
    exec: ["gleam", "run"],
    expose: [4040]
  }
DAGGER
