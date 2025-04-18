defmodule Trackrunner.WorkflowRuntime do
  @moduledoc """
  Dispatches ToolNodes to eligible agents using ToolRegistry.

  Handles three types of messages:
    - :tool_node: triggers execution of a tool on an available agent
    - :workflow_step: (TODO) triggers execution of a full workflow
    - :websocket_request: (TODO) handles websocket interactions
  """

  use GenServer

  alias Trackrunner.ToolRegistry
  alias Trackrunner.RelayContext

  ## Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Called when a ToolNode is ready to be executed.
  """
  def handle_tool_node(tool_node, relay_context) do
    GenServer.cast(__MODULE__, {:tool_node, tool_node, relay_context})
  end

  ## Callbacks

  def init(_opts) do
    :timer.send_interval(1000, :tick)
    {:ok, %{queue: %{}}}
  end

  def handle_cast({:tool_node, %{id: tool_id} = node, relay_context}, state) do
    case ToolRegistry.lookup(tool_id) do
      [] ->
        IO.puts("⏳ No agents available for #{tool_id}, queuing")

        updated_queue =
          Map.update(
            state.queue,
            tool_id,
            [{node, relay_context, 0}],
            &[{node, relay_context, 0} | &1]
          )

        {:noreply, %{state | queue: updated_queue}}

      agent_ids ->
        selected = select_agent(agent_ids, relay_context)
        RelayContext.dispatch(selected, tool_id, node, relay_context, 0)
        {:noreply, state}
    end
  end

  def handle_cast({:workflow_step, _step_data, _relay_context}, state) do
    IO.puts("⚙️ Received workflow_step (not implemented)")
    {:noreply, state}
  end

  def handle_cast({:websocket_request, _payload}, state) do
    IO.puts("🌐 Received websocket_request (not implemented)")
    {:noreply, state}
  end

  def handle_info(:tick, %{queue: queue} = state) do
    new_queue =
      Enum.reduce(queue, %{}, fn {tool_id, tasks}, acc ->
        case process_retry_queue(tool_id, tasks) do
          [] -> acc
          kept -> Map.put(acc, tool_id, kept)
        end
      end)

    {:noreply, %{state | queue: new_queue}}
  end

  ## Helpers

  defp select_agent(agent_ids, _relay_context) do
    Enum.random(agent_ids)
  end

  defp process_retry_queue(tool_id, tasks) do
    Enum.reduce(tasks, [], fn task_tuple, kept ->
      case try_dispatch_or_retry(tool_id, task_tuple) do
        :ok -> kept
        {:keep, updated} -> [updated | kept]
      end
    end)
    |> Enum.reverse()
  end

  defp try_dispatch_or_retry(tool_id, {tool_node, context, attempts}) do
    agent_ids = ToolRegistry.lookup(tool_id)

    case agent_ids do
      [] ->
        {:keep, {tool_node, context, attempts + 1}}

      agent_ids ->
        selected = select_agent(agent_ids, context)

        case RelayContext.dispatch(selected, tool_id, tool_node, context, attempts) do
          :ok ->
            :ok

          {:retry, new_attempts} ->
            if new_attempts > 5 do
              RelayContext.broadcast(context, {:dispatch_failed, tool_node})
              :ok
            else
              {:keep, {tool_node, context, new_attempts}}
            end
        end
    end
  end

  def dispatch_event(cat, evt, payload) do
    Beacon.publish(cat, evt, payload)
    # …plus your FleetScoreCache logic later
    {:ok, :dispatched}
  end
end
