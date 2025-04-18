defmodule TrackrunnerWeb.BeaconSocket do
  use Phoenix.Socket

  ## Channels
  # BeaconChannel will handle topics like "beacon:mouthpiece:1234"
  channel "beacon:*", TrackrunnerWeb.BeaconChannel

  ## Transports
  transport(:websocket, Phoenix.Transports.WebSocket)

  # You can validate tokens here in connect/3 if you add JWT later
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  # Returning `nil` means sockets are anonymous (no global ID)
  def id(_socket), do: nil
end
