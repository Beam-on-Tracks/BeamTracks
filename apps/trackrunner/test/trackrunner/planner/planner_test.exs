defmodule Trackrunner.PlannerTest do
  use ExUnit.Case, async: true

  alias Trackrunner.Planner

  import TestSupport

  setup do
    ensure_dag_registry()
    ensure_mock_planner()
    ensure_mock_tool_runtime()
    :ok
  end

  test "suggest/1 returns error with bad input" do
    assert {:error, :invalid_request, _} = Planner.suggest(%{})
  end

  test "execute/2 returns error when workflow ID is unknown" do
    # You could set up Pulsekeeper to have no workflows yet
    assert match?({:error, _}, Planner.execute("nonexistent-id", %{}))
  end
end
