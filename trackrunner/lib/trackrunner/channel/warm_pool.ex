defmodule Trackrunner.Channel.WarmPool do
  @moduledoc """
  Manages the warm pool of connected agents.
  Tracks agent_id → socket_pid mapping.
  """

  use GenServer
  require Logger

  ## Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Mark an agent as connected, storing its socket PID."
  def mark_connected(agent_id, socket_pid) do
    GenServer.cast(__MODULE__, {:mark_connected, agent_id, socket_pid})
  end

  @doc "Remove an agent from the warm pool."
  def mark_disconnected(agent_id) do
    GenServer.cast(__MODULE__, {:mark_disconnected, agent_id})
  end

  @doc "Fetch the current socket PID for a given agent, if any."
  def lookup_socket(agent_id) do
    GenServer.call(__MODULE__, {:lookup, agent_id})
  end

  @doc "Returns full state, mainly for debugging."
  def debug_state do
    GenServer.call(__MODULE__, :debug_state)
  end

  ## Server Callbacks

  @impl true
  def init(_init_arg), do: {:ok, %{}}

  @impl true
  def handle_cast({:mark_connected, agent_id, pid}, state) do
    Logger.info("📡 Warm pool: #{agent_id} connected")
    {:noreply, Map.put(state, agent_id, pid)}
  end

  @impl true
  def handle_cast({:mark_disconnected, agent_id}, state) do
    Logger.info("❌ Warm pool: #{agent_id} disconnected")
    {:noreply, Map.delete(state, agent_id)}
  end

  @impl true
  def handle_call({:lookup, agent_id}, _from, state) do
    {:reply, Map.get(state, agent_id), state}
  end

  @impl true
  def handle_call(:debug_state, _from, state) do
    {:reply, state, state}
  end
end
