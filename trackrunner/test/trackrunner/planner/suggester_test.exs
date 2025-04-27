defmodule Trackrunner.Planner.SuggesterTest do
  use ExUnit.Case, async: true

  alias Trackrunner.Planner.Suggester
  alias Trackrunner.Planner.DAGRegistry

  
setup do
  unless Process.whereis(Trackrunner.Planner.DAGRegistry) do
    {:ok, _} = Trackrunner.Planner.DAGRegistry.start_link([])
  end

  :ok
end
  
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

  test "returns error when no DAG exists" do
    input = %{"goal" => "Summarize news"}
    {:error, _reason, _map} = Suggester.suggest(input)
  end

  test "returns error on invalid input" do
    assert {:error, :invalid_request, _} = Suggester.suggest(%{})
  end
end
