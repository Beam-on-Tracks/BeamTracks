defmodule Trackrunner.Beacon do
  @moduledoc "GenServer responsible for managing PubSub subscriptions and pushing events over a socket."
  use GenServer
  alias Phoenix.PubSub

  # Client API
  @doc "Start a Beacon process for the given socket under the Supervisor."
  @spec start_link({String.t(), String.t(), Phoenix.Socket.t()}) :: GenServer.on_start()
  def start_link({category, uid, socket}) do
    GenServer.start_link(__MODULE__, {category, uid, socket})
  end

  @doc "Subscribe this Beacon to topics and events."
  @spec subscribe(pid(), [String.t()], [String.t()]) :: :ok
  def subscribe(beacon_pid, subscriptions, publishes) do
    GenServer.cast(beacon_pid, {:subscribe, subscriptions, publishes})
  end

  # Server callbacks
  @impl true
  def init({category, uid, socket}) do
    state = %{
      category: category,
      uid: uid,
      socket: socket,
      subscriptions: [],
      publishes: []
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:subscribe, subs, pubs}, state) do
    # Subscribe to PubSub topics for this category and events
    Enum.each(subs, fn event ->
      topic = "channel:#{state.category}:" <> event
      PubSub.subscribe(Trackrunner.PubSub, topic)
    end)

    {:noreply, %{state | subscriptions: subs, publishes: pubs}}
  end

  @impl true
  def handle_info({topic, msg}, %{socket: socket, subscriptions: subs} = state) do
    # Extract event name from topic suffix
    "channel:#{state.category}:" <> event = topic

    if event in state.subscriptions do
      Phoenix.Channel.push(socket, event, msg)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_other, state) do
    {:noreply, state}
  end
end
