defmodule Trackrunner.Tool.Graph do
  @moduledoc """
  Elixir interface to the type-safe tool_graph module in Gleam
  """

  # Debug helper to see what's available
  alias Trackrunner.Planner.DAGRegistry

  @type t :: %{nodes: list(map()), edges: list({any(), any()})}

  def debug_module_info do
    try do
      exports = :tool_graph.module_info(:exports)
      IO.puts("Exported functions: #{inspect(exports)}")
      exports
    rescue
      e ->
        IO.puts("Error getting module info: #{inspect(e)}")
        []
    end
  end

  # Use dynamic function calls to handle mismatches
  defp call_graph_function(name, args) do
    try do
      apply(:tool_graph, name, args)
    rescue
      UndefinedFunctionError ->
        # Try some common naming alternatives
        alternatives = [
          # Gleam might use snake_case or camelCase
          String.to_atom(Macro.camelize(to_string(name))),
          # Or it might prefix with 'new_', 'get_', etc.
          String.to_atom("new_#{name}"),
          String.to_atom("get_#{name}")
        ]

        Enum.find_value(alternatives, fn alt_name ->
          try do
            apply(:tool_graph, alt_name, args)
          rescue
            UndefinedFunctionError -> nil
          end
        end) || raise "Function #{name} not found in :tool_graph module"
    end
  end

  @doc "Create an empty graph"
  @spec new() :: t()
  def new, do: %{nodes: [], edges: []}

  @doc """
  Add a node to the graph.
  Raises if `deps` is not a list.
  """
  @spec add_node(t(), String.t(), String.t(), list()) :: t()
  def add_node(graph, _agent_id, _tool_name, deps) when not is_list(deps) do
    raise "Invalid dependencies: must be a list"
  end

  def add_node(graph, agent_id, tool_name, deps) do
    node = %{
      tool_id: {agent_id, tool_name},
      dependencies: deps
    }

    new_graph = %{graph | nodes: graph.nodes ++ [node]}

    # Snapshot the updated graph
    DAGRegistry.register_active_dag(new_graph)

    new_graph
  end

  @doc "Return all nodes in the graph"
  @spec all_nodes(t()) :: list(map())
  def all_nodes(graph), do: graph.nodes

  @doc """
  Validate the graph via the Gleam module, returning
  `{:ok, graph}` if valid or `{:error, reason}` if not.
  """
  @spec create_workflow_dag(t()) :: {:ok, t()} | {:error, term()}
  def create_workflow_dag(graph) do
    case call_graph_function(:validate_graph, [graph]) do
      {:ok, _nil} ->
        {:ok, graph}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Stub: always return an empty list of next nodes"
  @spec next_nodes(t(), any()) :: list(any())
  def next_nodes(_graph, _current_id), do: []
end
