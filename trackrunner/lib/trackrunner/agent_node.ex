defmodule Trackrunner.AgentNode do
  @moduledoc """
  Represents a live instance (node) of an agent in the BeamTracks system.
  Holds tool metadata and responds to tool discovery queries.
  """

  use GenServer
  # --- Public API ---

  def start_link({uid, data, caller}) do
    # assumes 1 tool for now
    # assume 1 public tool for now
    [tool_id | _] = Map.keys(data.public_tools)

    name = {:via, Registry, {:agent_node_registry, {data.agent_id, tool_id}}}
    GenServer.start_link(__MODULE__, {uid, data, caller}, name: name)
  end

  def init({_uid, data, caller}) do
    # Send notification back to parent (AgentFleet or caller)
    send(caller, {:agent_node_ready, self()})
    {:ok, data}
  end

  def via(uid),
    do: {:via, Registry, {:agent_node_registry, uid}}

  def lookup_public_tool(node_pid_or_name, tool_name) do
    GenServer.call(node_pid_or_name, {:lookup_public, tool_name})
  end

  def update_last_seen(node_pid_or_name) do
    GenServer.cast(node_pid_or_name, :update_last_seen)
  end

  # --- GenServer Callbacks ---

  def init(state), do: {:ok, state}

  def handle_call({:lookup_public, name}, _from, state) do
    case Map.get(state.public_tools, name) do
      nil -> {:reply, :not_found, state}
      url -> {:reply, {:ok, url}, state}
    end
  end

  def handle_cast(:update_last_seen, state) do
    {:noreply, %{state | last_seen: DateTime.utc_now()}}
  end

  def handle_cast({:execute_tool, tool_node, meta}, state) do
    IO.puts("🛠️ AgentNode executing #{tool_node.id} with input: #{tool_node.input}")

    if Map.has_key?(meta, :notify) do
      send(meta.notify, {:executed_fake_tool, tool_node.input})
    end

    {:noreply, state}
  end
end
