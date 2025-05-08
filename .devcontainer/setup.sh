#!/bin/bash
# .devcontainer/setup.sh

echo "Setting up BeamTracks development environment..."

# Generate SECRET_KEY_BASE if not already set
if [ -z "$SECRET_KEY_BASE" ]; then
  echo "Generating SECRET_KEY_BASE..."
  export SECRET_KEY_BASE=$(mix phx.gen.secret)
  echo "export SECRET_KEY_BASE=$SECRET_KEY_BASE" >> ~/.bashrc
fi

# Clone your Neovim config if needed
if [ ! -d "$HOME/.config/nvim" ]; then
  echo "Setting up Neovim configuration..."
  mkdir -p $HOME/.config/nvim
  # Uncomment and modify the line below to clone your Neovim config
  # git clone https://github.com/yourusername/nvim-config.git $HOME/.config/nvim
fi

# BeamTracks SDK
cd /workspaces/apps/beamtracks-sdk || exit
poetry install --no-interaction --no-ansi

# Trackrunner (Elixir)
cd /workspaces/apps/trackrunner
mix deps.get

# Pulsekeeper (Elixir/Gleam)
cd /workspaces/apps/pulsekeeper
mix deps.get
gleam get

# CLI (Elixir)
cd /workspaces/apps/beamtracks_cli
mix deps.get

echo "✅ Setup complete!"
