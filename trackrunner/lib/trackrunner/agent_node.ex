defmodule Trackrunner.AgentNode do
  @moduledoc """
  Represents a live instance (node) of an agent in the BeamTracks system.
  Holds tool metadata and responds to tool discovery queries.
  """

  use GenServer

  alias __MODULE__

  # --- Public API ---

  def start_link(
        {uid,
         %{
           ip: ip,
           public_tools: public_tools,
           private_tools: private_tools
         }}
      ) do
    initial_state = %{
      uid: uid,
      ip: ip,
      public_tools: public_tools,
      private_tools: private_tools,
      last_seen: DateTime.utc_now()
    }

    GenServer.start_link(__MODULE__, initial_state, name: via(uid))
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
end
