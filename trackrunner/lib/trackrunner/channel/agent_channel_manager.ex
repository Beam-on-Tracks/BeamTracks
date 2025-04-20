defmodule Trackrunner.AgentChannelManager do
  @moduledoc """
  Maintains a mapping of categories → fleet_id → list of WebsocketContract entries.

  State shape:
    %{
      category1 => %{
        fleet_a => [%WebsocketContract{uid: 1, identity: "...", subscriptions: [...], publishes: [...]}, …],
        fleet_b => [ … ]
      },
      category2 => %{
        …
      }
    }

  v1.0 TODO:
  - implemnet warm pool scaling 
  """

  use GenServer
  alias Trackrunner.WebsocketContract

  require Logger

  # Public API

  @doc """
  Starts the manager under the supervisor.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Register a list of WebsocketContract structs for a given fleet_id and node uid.
  """
  @spec register_channels(String.t(), integer(), [WebsocketContract.t()]) :: :ok
  def register_channels(fleet_id, uid, contracts)
      when is_binary(fleet_id) and is_integer(uid) and is_list(contracts) do
    GenServer.call(__MODULE__, {:register, fleet_id, uid, contracts})
  end

  @doc """
  Unregister all channel entries for the given node uid.
  """
  @spec unregister_node(integer()) :: :ok
  def unregister_node(uid) when is_integer(uid) do
    GenServer.call(__MODULE__, {:unregister, uid})
  end

  @doc """
  Returns a map of fleet_id => list of WebsocketContract structs
  for the given category (regardless of event).
  """
  @spec lookup_candidates(String.t()) :: %{optional(String.t()) => [WebsocketContract.t()]}
  def lookup_candidates(category) when is_binary(category) do
    GenServer.call(__MODULE__, {:lookup_category, category})
  end

  @doc """
  Returns a flat list of {fleet_id, WebsocketContract} tuples
  for agents subscribed to `event` in `category`.
  """
  @spec lookup_listeners(String.t(), String.t()) :: [{String.t(), WebsocketContract.t()}]
  def lookup_listeners(category, event) when is_binary(category) and is_binary(event) do
    GenServer.call(__MODULE__, {:lookup_listeners, category, event})
  end

  def mark_connected(agent_id, socket_pid) do
    GenServer.cast(__MODULE__, {:mark_connected, agent_id, socket_pid})
  end

  def mark_disconnected(agent_id) do
    GenServer.cast(__MODULE__, {:mark_disconnected, agent_id})
  end

  # Called directly, no call/cast
  def lookup_subscribers(category, event) do
    :ets.lookup(:agent_channels, {category, event})
  end

  # GenServer callbacks

  @impl true
  def init(_init_arg) do
    # Empty map: no categories registered yet
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, fleet_id, uid, contracts}, _from, state) do
    new_state =
      Enum.reduce(contracts, state, fn %WebsocketContract{category: cat} = c, acc ->
        # initialize category/fleet if missing
        fleet_map = Map.get(acc, cat, %{})
        entries = Map.get(fleet_map, fleet_id, [])

        # annotate contract with uid
        entry = %{c | uid: uid}

        updated_fleet_map = Map.put(fleet_map, fleet_id, [entry | entries])
        Map.put(acc, cat, updated_fleet_map)
      end)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister, uid}, _from, state) do
    # remove any entries whose uid matches, across all categories & fleets
    new_state =
      for {cat, fleet_map} <- state, into: %{} do
        filtered_fleet_map =
          for {fleet_id, entries} <- fleet_map, into: %{} do
            filtered_entries = Enum.reject(entries, fn e -> e.uid == uid end)
            {fleet_id, filtered_entries}
          end

        {cat, filtered_fleet_map}
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:lookup_category, category}, _from, state) do
    {:reply, Map.get(state, category, %{}), state}
  end

  @impl true
  def handle_call({:lookup_listeners, category, event}, _from, state) do
    listeners =
      state
      |> Map.get(category, %{})
      |> Enum.flat_map(fn {fleet_id, entries} ->
        entries
        |> Enum.filter(fn e -> event in e.subscriptions end)
        |> Enum.map(fn e -> {fleet_id, e} end)
      end)

    {:reply, listeners, state}
  end

  # Inside handle_cast
  def handle_cast({:mark_connected, agent_id, pid}, state) do
    updated =
      Map.update(state, agent_id, %{contracts: [], socket_pid: pid}, fn entry ->
        %{entry | socket_pid: pid}
      end)

    Logger.info("📡 #{agent_id} joined the warm pool")
    {:noreply, updated}
  end

  def handle_cast({:mark_disconnected, agent_id}, state) do
    updated = Map.delete(state, agent_id)
    Logger.info("❌ #{agent_id} left the warm pool")
    {:noreply, updated}
  end
end
