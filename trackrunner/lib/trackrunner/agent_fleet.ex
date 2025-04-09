defmodule Trackrunner.AgentFleet do
  @moduledoc """
  Supervises a group of AgentNodes under a single agent_id.
  Responsible for assigning unique UIDs and spinning up new nodes.
  """

  use DynamicSupervisor

  alias Trackrunner.AgentNode
  alias Trackrunner.AgentFleetRegistry

  def start_link(agent_id) do
    name = via(agent_id)
    DynamicSupervisor.start_link(__MODULE__, %{agent_id: agent_id, next_uid: 1}, name: name)
  end

  def via(agent_id),
    do: {:via, Registry, {AgentFleetRegistry, agent_id}}

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def add_node(agent_id, %{ip: _, public_tools: _, private_tools: _} = data) do
    with [{fleet_pid, _}] <- Registry.lookup(AgentFleetRegistry, agent_id),
         uid <- System.unique_integer([:positive]),
         child_spec = {AgentNode, {uid, data}} do
      DynamicSupervisor.start_child(fleet_pid, child_spec)
      {:ok, %{uid: uid}}
    else
      _ -> {:error, :fleet_not_found}
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
