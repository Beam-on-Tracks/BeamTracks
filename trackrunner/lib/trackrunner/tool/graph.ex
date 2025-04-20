defmodule Trackrunner.Tool.Graph do
  @moduledoc """
  Elixir interface to the type-safe tool_graph module in Gleam
  """

  # Debug helper to see what's available
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

  # Public API - using the dynamic function calls
  def new, do: call_graph_function(:new, [])

  def add_node(graph, agent_id, tool_name, deps \\ []) do
    node = {:tool_node, {:tool_id, agent_id, tool_name}, deps}
    call_graph_function(:add_node, [graph, node])
  end

  def all_nodes(graph), do: call_graph_function(:all_nodes, [graph])

  # Additional functions used in server.ex
  def create_workflow_dag(graph), do: call_graph_function(:create_workflow_dag, [graph])

  def next_nodes(dag, current_id), do: call_graph_function(:next_nodes, [dag, current_id])
end
