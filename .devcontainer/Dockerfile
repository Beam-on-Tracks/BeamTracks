# Dev Container for BeamTracks SDK with Python, Dagger CLI, Elixir, and Gleam
FROM mcr.microsoft.com/vscode/devcontainers/python:0-3.10

# Install dependencies for Erlang/Elixir and Gleam\RUN apt-get update && \
    apt-get install -y curl wget gnupg apt-transport-https unzip && \
    # Erlang and Elixir
    wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && \
    dpkg -i erlang-solutions_2.0_all.deb && \
    apt-get update && \
    apt-get install -y esl-erlang elixir && \
    # Gleam: fetch latest release and install
    GLEAM_VERSION=$(curl -s https://api.github.com/repos/gleam-lang/gleam/releases/latest | grep -Po '"tag_name": "\K.*(?=")') && \
    curl -sL https://github.com/gleam-lang/gleam/releases/download/${GLEAM_VERSION}/gleam_${GLEAM_VERSION#v}_amd64.deb -o gleam.deb && \
    dpkg -i gleam.deb && \
    rm gleam.deb && \
    # Clean up
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Dagger CLI
RUN curl -L https://dl.dagger.io/dagger/install.sh | sh

# Ensure Dagger CLI is on PATH
ENV PATH=/home/vscode/.dagger/bin:$PATH

# Install Poetry for Python dependency management
RUN pip install poetry

# Set working directory & install Python dependencies
WORKDIR /workspace
COPY pyproject.toml poetry.lock ./
RUN poetry install --no-interaction --no-ansi

# Expose Phoenix dev server port
EXPOSE 4000
