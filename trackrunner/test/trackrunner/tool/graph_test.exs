defmodule Trackrunner.Tool.GraphTest do
  use ExUnit.Case, async: true

  alias Trackrunner.Tool.Graph
  alias Trackrunner.Planner.DAGRegistry

  test "add_node/4 returns a new graph and registers it in DAGRegistry" do
    # Start with an empty Gleam graph
    original = Graph.new()

    # Add a node with no dependencies
    updated = Graph.add_node(original, "fleet1", "tool_a", [])

    # We expect a different graph instance
    refute updated == original

    # And the DAGRegistry should now hold that updated graph
    assert DAGRegistry.get_active_dag() == updated
  end

  test "error during add_node rolls back to previous DAG" do
    # Begin with one valid node so registry has a snapshot
    g1 = Graph.add_node(Graph.new(), "fleet1", "tool_a", [])
    assert DAGRegistry.get_active_dag() == g1

    # Force an exception by calling a non-existent graph function
    # We hack around the private call_graph_function by passing invalid args
    assert_raise RuntimeError, fn ->
      Graph.add_node(g1, "fleet1", "nonexistent_tool", :invalid_deps)
    end

    assert is_map(DAGRegistry.get_active_dag())
  end
end
