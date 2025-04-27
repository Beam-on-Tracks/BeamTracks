defmodule Trackrunner.Planner.SuggesterTest do
  use ExUnit.Case, async: true

  alias Trackrunner.Planner.Suggester
  alias Trackrunner.Planner.DAGRegistry

  setup do
    DAGRegistry.register_active_dag(%{
      paths: [
        %{
          name: "workflow1",
          path: [{"fleet1", "tool_a"}],
          source_input: "text",
          target_output: "summary"
        }
      ]
    })

    :ok
  end

  @tag :skip
  test "returns suggestions when DAG exists" do
    # Fake DAG with static paths
    dag = %{paths: [%{name: "workflow1", path: [{"agent1", "tool1"}]}]}
    DAGRegistry.register_active_dag(dag)

    input = %{"goal" => "Summarize news"}
    {:ok, suggestions} = Suggester.suggest(input)

    assert length(suggestions) > 0
    suggestion = List.first(suggestions)
    assert suggestion["workflowId"]
    assert is_list(suggestion["workflow"])
    assert is_binary(suggestion["expiration"])
  end

  @tag :skip
  test "returns error when no DAG exists" do
    input = %{"goal" => "Summarize news"}
    {:error, _reason, _map} = Suggester.suggest(input)
  end

  test "returns error on invalid input" do
    assert {:error, :invalid_request, _} = Suggester.suggest(%{})
  end
end
