defmodule Trackrunner.Registry do
  @moduledoc """
  Central manager of agent fleets. Responsible for creating new fleets,
  routing ping requests, and facilitating tool lookups.
  """

  alias Trackrunner.Agent.Fleet
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
    AgentFleet.ensure_started(agent_id)

    with {:ok, %{uid: uid}} <- AgentFleet.add_node(agent_id, node_data) do
      # Register channels AFTER node is up
      Trackrunner.AgentChannelManager.register_channels(
        agent_id,
        uid,
        node_data.agent_channels,
        node_data.ip
      )

      {:ok, %{uid: uid}}
    else
      err -> err
    end
  end

  @doc "Lookup a tool URL for a given agent"
  @spec lookup_tool(String.t(), String.t()) :: {:ok, String.t()} | :not_found
  def lookup_tool(agent_id, tool_name) do
    case Fleet.find_tool(agent_id, tool_name) do
      {:ok, url} -> {:ok, url}
      _ -> :not_found
    end
  end
end
