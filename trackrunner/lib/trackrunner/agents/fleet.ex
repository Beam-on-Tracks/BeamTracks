defmodule Trackrunner.Agent.Fleet do
  @moduledoc """
  Supervises a group of AgentNodes under a single agent_id.
  Responsible for assigning unique UIDs and spinning up new nodes.
  """

  use DynamicSupervisor

  alias Trackrunner.AgentNode
  alias Trackrunner.Agent.FleetRegistry

  require Logger

  def start_link(agent_id) do
    name = via(agent_id)
    DynamicSupervisor.start_link(__MODULE__, %{agent_id: agent_id, next_uid: 1}, name: name)
  end

  def via(agent_id),
    do: {:via, Registry, {FleetRegistry, agent_id}}

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_started(agent_id) do
    case Registry.lookup(FleetRegistry, agent_id) do
      [{_pid, _}] ->
        {:ok, :already_started}

      [] ->
        start_link(agent_id)
    end
  end

  @doc """
  Add a node to the fleet: start an AgentNode for the first public tool,
  wait for it to register, and return {:ok, %{uid: uid}}.

  If a node for the same agent_id and tool_id is already started,
  it’s treated as success.
  """
  @spec add_node(
          agent_id :: String.t(),
          data :: %{
            ip: String.t(),
            public_tools: map(),
            private_tools: map(),
            tool_dependencies: map(),
            agent_channels: [Trackrunner.Channel.WebsocketContract.t()]
          }
        ) :: {:ok, %{uid: non_neg_integer()}} | {:error, any()}
  def add_node(agent_id, data) do
    uid = System.unique_integer([:positive])
    caller = self()

    # Pick the first public tool as the tool_id for registration key
    [tool_id | _] = Map.keys(data.public_tools)
    registry_key = {agent_id, tool_id}

    enriched_data = Map.put(data, :agent_id, agent_id)
    child_spec = {AgentNode, {uid, enriched_data}}

    # Try to start; ignore if already started
    case DynamicSupervisor.start_child(Trackrunner.FleetSupervisor, child_spec) do
      {:ok, _child_pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.debug("AgentNode already started for #{inspect(registry_key)}")
        :ok

      {:error, reason} ->
        IO.warn("❌ start_child failed: #{inspect(reason)}")
        {:error, :fleet_not_found}
    end

    # Wait for registry registration
    case wait_until_registered(registry_key, 10) do
      {:ok, _pid} ->
        Logger.debug("📦 Node registered for #{agent_id} (tool: #{tool_id}) uid=#{uid}")

        {:ok, %{uid: uid}}

      {:error, :timeout} ->
        IO.warn("❌ add_node registration timeout for #{inspect(registry_key)}")
        {:error, :fleet_not_found}
    end
  end

  @doc """
  Find a public tool URL in one of the agent's nodes.
  """
  @spec find_tool(String.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def find_tool(agent_id, tool_name) do
    registry_key = {agent_id, tool_name}

    case Registry.lookup(:agent_node_registry, registry_key) do
      [{pid, _}] -> AgentNode.lookup_public_tool(pid, tool_name)
      [] -> {:error, :not_found}
    end
  end

  # Internal: poll the node registry until the AgentNode appears
  defp wait_until_registered(_registry_key, 0), do: {:error, :timeout}

  defp wait_until_registered(registry_key, attempts) do
    case Registry.lookup(:agent_node_registry, registry_key) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        :timer.sleep(50)
        wait_until_registered(registry_key, attempts - 1)
    end
  end
end
