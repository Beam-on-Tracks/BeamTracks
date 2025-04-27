defmodule Trackrunner.Runtime.Tool do
  @moduledoc """
  Dispatches tool calls to registered agents based on declared capability.

  Tool calls are routed over WebSocket for now using AgentChannelManager.
  """

  alias Trackrunner.Channel.AgentChannelManager
  alias Trackrunner.Channel.WebsocketContract

  @doc """
  Dispatches a tool call to one of the agents that publishes this tool.

  ## Example

      ToolRuntime.run(%{
        "tool_id" => "summarize",
        "inputs" => %{ "text" => "Hello world" }
      })

  """
  @spec run(map()) :: :ok | {:error, term()}
  def run(%{"tool_id" => tool_id, "inputs" => inputs}) do
    # Look up all agents that publish this tool
    candidates =
      AgentChannelManager.lookup_candidates("tool")
      |> Enum.flat_map(fn {fleet_id, contracts} ->
        Enum.filter(contracts, fn %WebsocketContract{publishes: tools} ->
          tool_id in tools
        end)
        |> Enum.map(fn contract -> {fleet_id, contract} end)
      end)

    case candidates do
      [] ->
        {:error, :no_agents_for_tool}

      [{fleet_id, contract} | _rest] ->
        # TODO: use FleetScoreCache in the future to select optimal
        payload = %{
          topic: "tool:#{tool_id}",
          message: inputs
        }

        AgentChannelManager.push_to_listener({fleet_id, contract, self()}, payload)
    end
  end

  def run(_), do: {:error, :invalid_payload}
end

