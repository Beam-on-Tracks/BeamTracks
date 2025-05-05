defmodule Trackrunner.Tool.Registry do
  @moduledoc """
  Registers which agents can handle which tools.
  """

  use GenServer

  ## Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Register an agent to a specific tool_id.
  """
  def register(agent_id, tool_id) do
    GenServer.cast(__MODULE__, {:register, agent_id, tool_id})
  end

  @doc """
  Get all agent_ids who can handle a given tool_id.
  """
  def lookup(tool_id) do
    GenServer.call(__MODULE__, {:lookup, tool_id})
  end

  ## Server Callbacks

  def init(state), do: {:ok, state}

  def handle_cast({:register, agent_id, tool_id}, state) do
    agents = Map.get(state, tool_id, [])
    updated = Map.put(state, tool_id, Enum.uniq([agent_id | agents]))
    {:noreply, updated}
  end

  def handle_call({:lookup, tool_id}, _from, state) do
    {:reply, Map.get(state, tool_id, []), state}
  end
end
