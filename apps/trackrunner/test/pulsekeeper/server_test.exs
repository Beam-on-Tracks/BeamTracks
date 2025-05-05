defmodule Pulsekeeper.ServerTest do
  use ExUnit.Case

  alias Pulsekeeper.Server
  alias Pulsekeeper.TestGraphs

  import GleamGraphHelpers

  defp to_tool_node(agent, name, deps \\ []) do
    {:tool_node, {:tool_id, agent, name}, deps, "in", "out"}
  end

  setup do
    {:ok, _} = start_supervised(Pulsekeeper.Server)

    {:ok, graph: TestGraphs.valid()}
  end

  test "registers a DAG and tracks tool completion", %{graph: graph} do
    assert :ok = Server.register_dag(graph)
  end

  test "handles invalid graph gracefully" do
    assert {:error, _} = Server.register_dag(TestGraphs.broken())
  end
end
