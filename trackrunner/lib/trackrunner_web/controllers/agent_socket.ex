defmodule TrackrunnerWeb.AgentSocket do
  use TrackrunnerWeb, :channel

  alias Trackrunner.{Beacon, BeaconSupervisor}

  # Clients join on "beacon:<category>:<uid>"
  def join("beacon:" <> rest, _payload, socket) do
    [category, uid] = String.split(rest, ":")

    # 1) Start a Beacon under a supervisor
    #    you’ll need to add BeaconSupervisor to your application tree
    {:ok, beacon_pid} =
      DynamicSupervisor.start_child(
        BeaconSupervisor,
        {Beacon, {category, uid, socket}}
      )

    # 2) Stash the beacon pid (and metadata) in socket.assigns
    socket =
      socket
      |> assign(:beacon_pid, beacon_pid)
      |> assign(:category, category)
      |> assign(:uid, uid)

    {:ok, socket}
  end

  # handle subscribe messages, let Beacon GenServer deal with them
  def handle_in("subscribe", payload, socket) do
    Beacon.subscribe(socket.assigns.beacon_pid, payload["subscriptions"], payload["publishes"])
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    AgentChannelManager.mark_disconnected(socket.assigns.agent_id)
    :ok
  end
end
