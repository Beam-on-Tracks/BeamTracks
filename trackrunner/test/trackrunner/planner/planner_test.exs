defmodule Trackrunner.PlannerTest do
  use ExUnit.Case, async: true

  alias Trackrunner.Planner

  setup do
    Trackrunner.Planner.DAGRegistry.start_link([])

    :ok
  end

  test "suggest/1 returns error with bad input" do
    assert {:error, :invalid_request, _} = Planner.suggest(%{})
  end

  @tag :skip
  test "execute/2 returns error when workflow ID is unknown" do
    # You could set up Pulsekeeper to have no workflows yet
    result = Planner.execute("nonexistent-id", %{})
    assert match?({:error, _}, result)
  end
end
