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
  def add_node(agent_id, data) do
    uid = System.unique_integer([:positive])

    enriched_data = Map.put(data, :agent_id, agent_id)
    child_spec = {AgentNode, {uid, enriched_data}}

    # 1. Always start the node (or ignore if already started)
    case DynamicSupervisor.start_child(Trackrunner.FleetSupervisor, child_spec) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.debug("AgentNode already started for #{agent_id}")

      {:error, reason} ->
        IO.warn("❌ start_child failed: #{inspect(reason)}")
        {:error, :fleet_not_found}
    end

    # 2. If there are no public tools, skip the registry wait and succeed immediately
    case Map.keys(data.public_tools) do
      [] ->
        Logger.warn(
          "Agent #{agent_id} pinged without public tools—node started without registration"
        )

        {:ok, %{uid: uid}}

      [tool_id | _] ->
        registry_key = {agent_id, tool_id}

        # 3. Otherwise wait for it to register
        case wait_until_registered(registry_key, 10) do
          {:ok, _pid} ->
            {:ok, %{uid: uid}}

          {:error, :timeout} ->
            IO.warn("❌ add_node registration timeout for #{inspect(registry_key)}")
            {:error, :fleet_not_found}
        end
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
