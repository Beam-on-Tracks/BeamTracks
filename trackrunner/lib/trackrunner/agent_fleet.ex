defmodule Trackrunner.AgentFleet do
  @moduledoc """
  Supervises a group of AgentNodes under a single agent_id.
  Responsible for assigning unique UIDs and spinning up new nodes.
  """

  use DynamicSupervisor

  alias Trackrunner.AgentNode
  alias Trackrunner.AgentFleetRegistry

  require Logger

  def start_link(agent_id) do
    name = via(agent_id)
    DynamicSupervisor.start_link(__MODULE__, %{agent_id: agent_id, next_uid: 1}, name: name)
  end

  def via(agent_id),
    do: {:via, Registry, {AgentFleetRegistry, agent_id}}

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_started(agent_id) do
    case Registry.lookup(AgentFleetRegistry, agent_id) do
      [{_pid, _}] ->
        {:ok, :already_started}

      [] ->
        start_link(agent_id)
    end
  end

  @spec add_node(String.t(), %{
          ip: String.t(),
          public_tools: map(),
          private_tools: map(),
          tool_dependencies: map()
        }) :: {:ok, %{uid: integer()}} | {:error, any()}
  def add_node(agent_id, data) do
    uid = System.unique_integer([:positive])
    caller = self()

    with [{fleet_pid, _}] <- Registry.lookup(AgentFleetRegistry, agent_id),
         child_spec = {AgentNode, {uid, Map.put(data, :agent_id, agent_id), caller}},
         {:ok, _child} <- DynamicSupervisor.start_child(fleet_pid, child_spec),
         {:ok, _pid} <- wait_until_registered({agent_id, uid}) do
      Logger.debug("📦 Node registered for #{agent_id} with tools: #{Map.keys(data.public_tools)}")
      {:ok, %{uid: uid}}
    else
      error ->
        IO.warn("❌ add_node failed: #{inspect(error)}")
        {:error, :fleet_not_found}
    end
  end

  defp wait_until_registered(key, tries \\ 10) do
    # TODO for production Process.monitor or some other mechanism
    receive do
      {:agent_node_ready, _pid} ->
        Registry.lookup(:agent_node_registry, key)
        |> case do
          [{pid, _}] -> {:ok, pid}
          _ -> :error
        end
    after
      100 ->
        if tries > 0, do: wait_until_registered(key, tries - 1), else: {:error, :timeout}
    end
  end

  def find_tool(agent_id, tool_name) do
    case Registry.lookup(AgentFleetRegistry, agent_id) do
      [{fleet_pid, _}] ->
        fleet_pid
        |> DynamicSupervisor.which_children()
        |> Enum.map(fn {_, pid, _, _} -> pid end)
        |> Enum.find_value(fn pid ->
          case AgentNode.lookup_public_tool(pid, tool_name) do
            {:ok, url} -> url
            _ -> nil
          end
        end)
        |> case do
          nil -> :not_found
          url -> {:ok, url}
        end

      _ ->
        :not_found
    end
  end
end
