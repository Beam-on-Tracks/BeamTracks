defmodule Trackrunner.WorkflowRuntime do
  @moduledoc """
  Dispatches ToolNodes to eligible agents using ToolRegistry.
  """

  use GenServer

  alias Trackrunner.ToolRegistry

  ## API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{waiting: %{}}, name: __MODULE__)
  end

  @doc """
  Called when a ToolNode is ready to be executed.
  """
  def handle_tool_node(tool_node, meta) do
    GenServer.cast(__MODULE__, {:tool_node, tool_node, meta})
  end

  ## Server Callbacks

  def init(state), do: {:ok, state}

  def handle_cast({:tool_node, %{id: tool_id} = node, meta}, state) do
    case ToolRegistry.lookup(tool_id) do
      [] ->
        IO.puts("No agents available for tool #{tool_id}, adding to wait queue.")
        new_waiting = Map.update(state.waiting, tool_id, [node], &[node | &1])
        {:noreply, %{state | waiting: new_waiting}}

      agent_ids ->
        selected = select_agent(agent_ids, meta)
        dispatch(selected, node, meta)
        {:noreply, state}
    end
  end

  ## Internal helpers

  defp select_agent(agent_ids, _meta) do
    # TODO: add sticky / scoring
    Enum.random(agent_ids)
  end

  defp dispatch(agent_id, %{id: tool_id} = tool_node, meta) do
    case Registry.lookup(:agent_node_registry, {agent_id, tool_id}) do
      [{pid, _}] ->
        IO.puts("✅ Dispatching #{tool_id} to #{agent_id}")
        GenServer.cast(pid, {:execute_tool, tool_node, meta})
        :ok

      [] ->
        IO.warn("❌ No AgentNode running for #{agent_id}/#{tool_id}")
        :error
    end
  end
end
