defmodule Trackrunner.Channel.AgentChannelManager do
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
  - Pull warm pool data from WarmPool when doing event dispatch
  - Add warm pool scaling logic (new module? use ETS for metrics? maybe `Trackrunner.Runtime.Scaler`)
  """

  use GenServer
  alias Trackrunner.Channel.WarmPool
  alias Trackrunner.Channel.WebsocketContract
  require Logger

  # Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec register_channels(String.t(), integer(), [WebsocketContract.t()]) :: :ok
  def register_channels(fleet_id, uid, contracts)
      when is_binary(fleet_id) and is_integer(uid) and is_list(contracts) do
    GenServer.call(__MODULE__, {:register, fleet_id, uid, contracts})
  end

  @spec unregister_node(integer()) :: :ok
  def unregister_node(uid) do
    GenServer.call(__MODULE__, {:unregister, uid})
  end

  @spec lookup_candidates(String.t()) :: %{optional(String.t()) => [WebsocketContract.t()]}
  def lookup_candidates(category) do
    GenServer.call(__MODULE__, {:lookup_category, category})
  end

  @spec lookup_listeners(String.t(), String.t()) :: [{String.t(), WebsocketContract.t()}]
  def lookup_listeners(category, event) do
    GenServer.call(__MODULE__, {:lookup_listeners, category, event})
  end

  def mark_connected(agent_id, socket_pid) do
    WarmPool.mark_connected(agent_id, socket_pid)
  end

  def mark_disconnected(agent_id) do
    WarmPool.mark_disconnected(agent_id)
  end

  # Called directly, no call/cast
  def lookup_subscribers(category, event) do
    :ets.lookup(:agent_channels, {category, event})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # channels: %{ category => %{fleet_id => [contracts]} }
    # warm_pool: %{ fleet_id => %{socket_pid: pid, …} }
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, fleet_id, uid, contracts}, _from, state) do
    new_state =
      Enum.reduce(contracts, state, fn %WebsocketContract{category: category} = contract, acc ->
        # 1) grab (or init) the map of fleets for this category
        fleet_map = Map.get(acc, category, %{})

        # 2) grab (or init) the list of entries for this fleet
        entries = Map.get(fleet_map, fleet_id, [])

        # 3) annotate with uid & the fleet it belongs to
        entry = %WebsocketContract{contract | uid: uid, agent_id: fleet_id}

        # 4) stick it back under this fleet in this category
        updated_fleet_map = Map.put(fleet_map, fleet_id, [entry | entries])
        Map.put(acc, category, updated_fleet_map)
      end)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister, uid}, _from, state) do
    new_state =
      for {cat, fleet_map} <- state, into: %{} do
        filtered =
          for {fleet_id, entries} <- fleet_map, into: %{} do
            {fleet_id, Enum.reject(entries, fn e -> e.uid == uid end)}
          end

        {cat, filtered}
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:lookup_category, category}, _from, state) do
    {:reply, Map.get(state, category, %{}), state}
  end

  @impl true
  def handle_call({:lookup_listeners, category, event}, _from, channels) do
    listeners =
      Map.get(channels, category, %{})
      |> Enum.flat_map(fn {fleet_id, entries} ->
        case WarmPool.lookup_socket(fleet_id) do
          pid when is_pid(pid) ->
            entries
            |> Enum.filter(fn e -> event in e.subscriptions end)
            |> Enum.map(fn e -> {fleet_id, e, pid} end)

          _ ->
            []
        end
      end)

    {:reply, listeners, channels}
  end
end
