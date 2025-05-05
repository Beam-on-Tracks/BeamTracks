defmodule Trackrunner.WorkflowRuntime do
  @moduledoc """
  Dispatches ToolNodes to eligible agents using ToolRegistry.

  Handles three types of messages:
    - :enqueue_or_dispatch: triggers execution of a tool on an available agent
    - :agent_node_ready: replays queued tool calls when an agent node comes online
    - :workflow_step: (TODO) triggers execution of a full workflow
    - :websocket_request: (TODO) handles websocket interactions
  """

  use GenServer
  alias Trackrunner.{RelayContext, AgentChannelManager, FleetScoreCache}
  alias Trackrunner.Tool.Registry, as: ToolRegistry
  alias TrackrunnerWeb.Endpoint

  @queue_table :workflow_runtime_queue

  ## Public API

  @doc "Start the WorkflowRuntime under the supervision tree."
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Called by controllers or tests to initiate a tool call."
  @spec handle_tool_node(map(), RelayContext.t()) ::
          {:ok, :dispatched | :queued} | {:error, :no_candidates}
  def handle_tool_node(tool_node, context) do
    GenServer.call(__MODULE__, {:enqueue_or_dispatch, tool_node, context})
  end

  @doc "Called by AgentNode.init/1 to signal a new node is ready."
  @spec notify_node_ready(String.t(), String.t()) :: :ok
  def notify_node_ready(agent_id, tool_id) do
    GenServer.cast(__MODULE__, {:agent_node_ready, {agent_id, tool_id}})
  end

  @doc "Handles incoming workflow steps (TODO)."
  @spec handle_workflow_step(any(), RelayContext.t()) :: :ok
  def handle_workflow_step(step_data, context) do
    GenServer.cast(__MODULE__, {:workflow_step, step_data, context})
  end

  @doc "Handles incoming websocket requests (TODO)."
  @spec handle_websocket_request(any()) :: :ok
  def handle_websocket_request(payload) do
    GenServer.cast(__MODULE__, {:websocket_request, payload})
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Create a bag-style ETS table for queued calls
    :ets.new(@queue_table, [:named_table, :public, :bag])
    # Schedule periodic retry ticks
    :timer.send_interval(1_000, :tick)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:enqueue_or_dispatch, %{id: id} = tool_node, ctx}, _from, state) do
    case ToolRegistry.lookup(id) do
      [] ->
        # No agent registered yet → queue for later replay
        :ets.insert(@queue_table, {id, tool_node, ctx})
        {:reply, {:ok, :queued}, state}

      [agent_id | _rest] ->
        key = {agent_id, id}

        case Registry.lookup(:agent_node_registry, key) do
          [{pid, _}] ->
            # Immediate dispatch to the agent node
            GenServer.cast(pid, {:execute_tool, tool_node, ctx})
            {:reply, {:ok, :dispatched}, state}

          [] ->
            # Queue for replay once node is ready
            :ets.insert(@queue_table, {id, tool_node, ctx})
            {:reply, {:ok, :queued}, state}
        end

      :error ->
        # No agents ever registered for this tool_id
        {:reply, {:error, :no_candidates}, state}
    end
  end

  @impl true
  def handle_cast({:agent_node_ready, {agent_id, tool_id}}, state) do
    # Replay all queued calls for this tool_id
    for {^tool_id, tool_node, ctx} <- :ets.lookup(@queue_table, tool_id) do
      case Registry.lookup(:agent_node_registry, {agent_id, tool_id}) do
        [{pid, _}] ->
          # Send execute cast straight to that AgentNode
          GenServer.cast(pid, {:execute_tool, tool_node, ctx})

        [] ->
          # No node live yet—keep it queued
          :ok
      end

      :ets.delete_object(@queue_table, {tool_id, tool_node, ctx})
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:workflow_step, step_data, context}, state) do
    # TODO: implement full workflow orchestration
    IO.puts("⚙️ Received workflow_step: #{inspect(step_data)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:websocket_request, payload}, state) do
    # TODO: push updates over websockets
    IO.puts("🌐 Received websocket_request: #{inspect(payload)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    # TODO: retry or backoff logic for queued tasks
    {:noreply, state}
  end

  ## Stubbed helpers for future use

  @doc "Ask the infra to spin up `n` more agents of this identity"
  @spec scale_up(String.t(), String.t(), non_neg_integer()) :: :ok
  def scale_up(_category, _identity, _n), do: :ok

  @doc "Notify that we have too many idle agents"
  @spec scale_down(String.t(), String.t(), non_neg_integer()) :: :ok
  def scale_down(_category, _identity, _n), do: :ok

  @doc "Publish a real‑time event over websockets (HTTP/WebSocket layer stub)"
  def dispatch_event(cat, evt, payload) do
    Endpoint.broadcast!("beacon:#{cat}", evt, payload)
    {:ok, :dispatched}
  end
end
