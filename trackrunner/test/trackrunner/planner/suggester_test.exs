defmodule Trackrunner.Planner.SuggesterTest do
  use ExUnit.Case, async: true

  alias Trackrunner.Planner.Suggester
  alias Trackrunner.Planner.DAGRegistry
  import TestSupport

  setup do
    ensure_dag_registry()
    ensure_mock_planner()
    :ok
  end

  test "returns dummy suggestions when DAG exists" do
    DAGRegistry.register_active_dag(%{
      paths: [%{name: "path1", path: [{"a", "echo"}], source_input: "in", target_output: "out"}]
    })

    {:ok, suggestions} = Suggester.suggest(%{"goal" => "anything"})
    assert length(suggestions) >= 1
    assert hd(suggestions)["workflow"] == ["echo"]
  end

  test "returns error when no DAG exists" do
    # Empty registry → unsupported
    # planner_real_calls=false → dummy planner errors out with planning_failed/:no_static_workflows
    assert {:error, :planning_failed, %{reason: ":no_static_workflows"}} =
             Suggester.suggest(%{"goal" => "anything"})
  end

  test "returns error on invalid input" do
    assert {:error, :invalid_request, _} = Suggester.suggest(%{})
  end
end
