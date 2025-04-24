defmodule Trackrunner.Runtime.Tool do
  @moduledoc """
  Dispatches tool calls to registered agents based on declared capability.

  Tool calls are routed over WebSocket for now using AgentChannelManager.
  """
  alias Trackrunner.Tool.Registry
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
  @doc """
  Run a tool by its `tool_id` and `inputs`. Picks a live agent and dispatches via WebSocket.
  """
  @spec run(map()) :: :ok | {:error, atom()}
  def run(%{"tool_id" => tool_id, "inputs" => inputs}) do
    with agent_ids when agent_ids != [] <- Registry.lookup(tool_id),
         candidates when candidates != [] <- live_publishers(agent_ids, tool_id) do
      # TODO: Add scoring, load-balancing, retries
      [{fleet_id, contract, pid} | _] = candidates

      payload = %{
        topic: "tool:#{tool_id}",
        message: inputs
      }

      AgentChannelManager.push_to_listener({fleet_id, contract, pid}, payload)
    else
      [] -> {:error, :no_live_agents}
      _ -> {:error, :invalid_request}
    end
  end

  def run(_), do: {:error, :invalid_payload}

  defp live_publishers(agent_ids, tool_id) do
    AgentChannelManager.lookup_candidates("tool")
    |> Enum.flat_map(fn {fleet_id, contracts} ->
      contracts
      |> Enum.filter(fn %WebsocketContract{agent_id: id, publishes: pubs} ->
        id in agent_ids and tool_id in pubs
      end)
      |> Enum.map(fn contract ->
        case AgentChannelManager.mark_connected(contract.agent_id, self()) do
          :ok -> {fleet_id, contract, self()}
          _ -> nil
        end
      end)
    end)
    |> Enum.reject(&is_nil/1)
  end
end
