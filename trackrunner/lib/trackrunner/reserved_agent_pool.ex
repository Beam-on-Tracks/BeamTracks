defmodule Trackrunner.ReservedAgentPool do
  @moduledoc """
  Static pool manager for WebSocket agent slots per identity.

  Maintains a fixed-size list of reserved agent UIDs for each identity.
  Stubbed for v0.1; dynamic scaling & eviction will be added later.
  """
  use GenServer

  @default_size 3

  # Public API

  @doc "Start the pool manager."
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Reserve `count` agents for the given category and identity.\
  Returns list of `{identity, uid}` pairs."
  @spec reserve_agents(String.t(), String.t(), non_neg_integer()) :: [{String.t(), integer()}]
  def reserve_agents(category, identity, count \\ @default_size) do
    GenServer.call(__MODULE__, {:reserve, category, identity, count})
  end

  @doc "Release previously reserved agent UIDs."
  @spec release_agents([{String.t(), integer()}]) :: :ok
  def release_agents(entries) when is_list(entries) do
    GenServer.cast(__MODULE__, {:release, entries})
  end

  # GenServer callbacks

  @impl true
  def init(_init_arg) do
    # state shape: %{ {category, identity} => [uid1, uid2, ...] }
    {:ok, %{}}
  end

  @impl true
  def handle_call({:reserve, category, identity, count}, _from, state) do
    key = {category, identity}
    existing = Map.get(state, key, [])

    # fetch all candidates
    candidates =
      Trackrunner.AgentChannelManager.lookup_listeners(category, "*")
      |> Enum.filter(fn {_fleet, %Trackrunner.WebsocketContract{identity: id}} ->
        id == identity
      end)
      |> Enum.map(fn {_, c} -> c.uid end)
      |> Enum.uniq()

    # pick up to count UIDs not already reserved
    available = candidates -- existing
    to_take = Enum.take(available, max(0, count - length(existing)))
    reserved = existing ++ to_take

    new_state = Map.put(state, key, reserved)
    {:reply, Enum.map(reserved, &{identity, &1}), new_state}
  end

  @impl true
  def handle_cast({:release, entries}, state) do
    new_state =
      Enum.reduce(entries, state, fn {identity, uid}, acc ->
        {category, _} =
          Enum.find(acc, fn {{_cat, id}, uids} -> id == identity and uid in uids end) |> elem(0)

        key = {category, identity}
        updated = Map.get(acc, key, []) |> List.delete(uid)
        Map.put(acc, key, updated)
      end)

    {:noreply, new_state}
  end
end
