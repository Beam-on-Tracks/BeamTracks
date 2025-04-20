defmodule Trackrunner.Registry do
  @moduledoc """
  Central manager of agent fleets. Responsible for creating new fleets,
  routing ping requests, and facilitating tool lookups.
  """

  alias Trackrunner.AgentFleet
  require Logger

  @spec register_node(String.t(), %{
          ip: String.t(),
          public_tools: map(),
          private_tools: map(),
          tool_dependencies: map(),
          agent_channels: [Trackrunner.WebsocketContract.t()]
        }) ::
          {:ok, %{uid: integer()}} | {:error, any()}
  def register_node(agent_id, node_data) do
    case Registry.lookup(Trackrunner.AgentFleetRegistry, agent_id) do
      [] ->
        Logger.debug("AgentFleet not found for #{agent_id}. Attempting to start it.")

        DynamicSupervisor.start_child(
          Trackrunner.FleetSupervisor,
          {AgentFleet, agent_id}
        )

      _ ->
        Logger.debug("✅ AgentFleet already running for #{agent_id}")
    end

    AgentFleet.add_node(agent_id, node_data)
  end

  @doc "Lookup a tool URL for a given agent"
  @spec lookup_tool(String.t(), String.t()) :: {:ok, String.t()} | :not_found
  def lookup_tool(agent_id, tool_name) do
    case AgentFleet.find_tool(agent_id, tool_name) do
      {:ok, url} -> {:ok, url}
      _ -> :not_found
    end
  end
end
