defmodule Trackrunner.Channel.WarmPool do
  @moduledoc """
  Manages the warm pool of connected agents.
  Tracks agent_id → socket_pid mapping.
  """

  # ← this line brings in child_spec/1
  use Agent
  @name __MODULE__

  ## Public API

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: @name)
  end

  @doc "Register an agent module for execution tests or in-memory dispatch."
  def register_agent(agent_id, module) when is_binary(agent_id) and is_atom(module) do
    Agent.update(@name, &Map.put(&1, agent_id, module))
  end

  @doc "Mark an agent as connected, storing its socket PID."
  def mark_connected(agent_id, socket_pid) do
    Agent.update(@name, &Map.put(&1, agent_id, socket_pid))
  end

  @doc "Remove an agent from the warm pool."
  def mark_disconnected(agent_id) do
    Agent.update(@name, &Map.delete(&1, agent_id))
  end

  @doc "Fetch the current socket PID for a given agent, if any."
  def lookup_socket(agent_id) do
    Agent.get(@name, &Map.get(&1, agent_id))
  end

  @doc "Returns full state, mainly for debugging."
  def debug_state do
    Agent.get(@name, & &1)
  end

  @doc "Clear out all registered agents (for tests or full reset)"
  def clear do
    Agent.update(@name, fn _ -> %{} end)
  end
end
