defmodule Pulsekeeper.Server do
  use GenServer

  require Logger

  @type tool_id :: {String.t(), String.t()}

  @type state :: %{
          # Gleam WorkflowDAG struct
          workflow_dag: any(),
          # Only tracking completed nodes
          registered_tools: MapSet.t(tool_id)
        }

  # --- Public API ---

  def start_link([]) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register_dag(graph) do
    GenServer.call(__MODULE__, {:register_dag, graph})
  end

  def mark_node_complete(node_id) do
    GenServer.call(__MODULE__, {:mark_complete, node_id})
  end

  def get_next_nodes(current_id) do
    GenServer.call(__MODULE__, {:next_nodes, current_id})
  end

  def get_registered_tools() do
    GenServer.call(__MODULE__, :registered_tools)
  end

  def sync_graph(tool_nodes) do
    GenServer.call(__MODULE__, {:sync_graph, tool_nodes})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_) do
    {:ok, %{workflow_dag: nil, registered_tools: MapSet.new()}}
  end

  @impl true
  def handle_call({:register_dag, graph}, _from, _state) do
    case Trackrunner.Tool.Graph.create_workflow_dag(graph) do
      {:ok, dag} ->
        {:reply, :ok, %{workflow_dag: dag, registered_tools: MapSet.new()}}

      {:error, reason} ->
        {:reply, {:error, reason}, %{workflow_dag: nil, registered_tools: MapSet.new()}}
    end
  end

  def handle_call({:mark_complete, node_id}, _from, state) do
    {:reply, :ok, %{state | registered_tools: MapSet.put(state.registered_tools, node_id)}}
  end

  def handle_call({:next_nodes, current_id}, _from, %{workflow_dag: dag} = state) do
    next = Trackrunner.Tool.Graph.next_nodes(dag, current_id)
    {:reply, next, state}
  end

  def handle_call(:registered_tools, _from, state) do
    {:reply, state.registered_tools, state}
  end

  def handle_call({:sync_graph, tool_nodes}, _from, state) do
    case Trackrunner.Tool.Graph.create_workflow_dag(tool_nodes) do
      {:ok, new_dag} ->
        {:reply, :ok, %{state | workflow_dag: new_dag, registered_tools: MapSet.new()}}

      {:error, reason} ->
        Logger.warn("❌ DAG sync failed: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  def get_last_seen(agent_id, uid) do
    GenServer.call(__MODULE__, {:get, {agent_id, uid}})
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key, nil), state}
  end
end
