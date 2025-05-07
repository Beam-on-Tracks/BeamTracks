# Dev Container for BeamTracks Monorepo
# Includes Python, Dagger CLI, Elixir, and Gleam
FROM mcr.microsoft.com/vscode/devcontainers/python:0-3.10
# Switch to root for installs
USER root
# Install Erlang/Elixir and essentials
RUN apt-get update && \
    apt-get install -y \
      curl wget gnupg apt-transport-https unzip \
      erlang elixir && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
# Install Gleam via direct release tarball
ARG GLEAM_VERSION="1.9.1"
RUN curl -L \
    https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    -o gleam.tar.gz && \
  tar -xzf gleam.tar.gz && \
  mv gleam /usr/local/bin/gleam && \
  rm gleam.tar.gz
# Install Dagger CLI
RUN curl -L https://dl.dagger.io/dagger/install.sh | sh
ENV PATH=/home/vscode/.dagger/bin:$PATH
# Install Poetry for Python dependency management
RUN pip install poetry
# Create workspace directory
WORKDIR /workspace
# Expose Phoenix dev server port
EXPOSE 4000
# Default to non-root user
USER vscode
