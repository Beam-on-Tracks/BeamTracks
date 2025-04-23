defmodule TrackrunnerWeb.UserSocket do
  use Phoenix.Socket

  alias Trackrunner.{Beacon, BeaconSupervisor}
  alias Trackrunner.Channel.AgentChannelManager

  ## Channel routes
  channel "cat:*", TrackrunnerWeb.GenericChannel
  # self-routing to handle `join/3`
  channel "beacon:*", __MODULE__

  # Clients join on "beacon:<category>:<uid>"
  def join("beacon:" <> rest, _payload, socket) do
    [category, uid] = String.split(rest, ":")

    {:ok, beacon_pid} =
      DynamicSupervisor.start_child(
        BeaconSupervisor,
        {Beacon, {category, uid, socket}}
      )

    socket =
      socket
      |> assign(:beacon_pid, beacon_pid)
      |> assign(:category, category)
      |> assign(:uid, uid)

    {:ok, socket}
  end

  def handle_in("subscribe", payload, socket) do
    Beacon.subscribe(socket.assigns.beacon_pid, payload["subscriptions"], payload["publishes"])
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    AgentChannelManager.mark_disconnected(socket.assigns.agent_id)
    :ok
  end

  # Required callbacks
  def connect(_params, socket, _connect_info), do: {:ok, socket}
  def id(_socket), do: nil
end
