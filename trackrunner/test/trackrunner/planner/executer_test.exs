defmodule Trackrunner.Planner.ExecutorTest do
  use ExUnit.Case, async: false
  require Logger

  alias Trackrunner.Planner.Executor
  alias Trackrunner.Planner.DAGRegistry

  import TestSupport

  # Add explicit service initialization in each test's setup
  setup do
    Logger.debug("Starting ExecutorTest setup")

    # Explicitly ensure services are started before each test
    {:ok, _} = ensure_workflow_cache()
    {:ok, _} = ensure_dag_registry()
    ensure_mock_tool_runtime()

    :ok
  end

  describe "when a static workflow is registered" do
    test "executes workflow from Cachex if present" do
      with_clean_state(%{}, fn ->
        # Register a DAG for the test
        DAGRegistry.register_active_dag(%{
          paths: [
            %{
              name: "cached_workflow",
              path: [{"fleet1", "echo"}],
              source_input: "text",
              target_output: "summary"
            }
          ]
        })

        workflow_id = "cached_workflow"
        input = %{"text" => "Hello"}

        # Put workflow in cache directly
        Cachex.put!(:workflow_cache, workflow_id, %{
          "path" => [{"fleet1", "echo"}],
          "source_input" => "text",
          "target_output" => "summary"
        })

        # Execute and verify
        assert {:ok, result} = Executor.execute(workflow_id, input)
        assert result == %{"echoed" => true, "text" => "Hello"}
      end)
    end

    test "returns error when workflow not found" do
      with_clean_state(%{}, fn ->
        # Register an empty DAG
        DAGRegistry.register_active_dag(%{paths: []})

        input = %{"text" => "Missing"}
        assert {:error, :workflow_not_found} = Executor.execute("nonexistent_workflow", input)
      end)
    end

    test "returns error if tool runtime fails" do
      with_clean_state(%{}, fn ->
        # Register a failing workflow
        workflow_id = "failing_workflow"

        DAGRegistry.register_active_dag(%{
          paths: [
            %{
              name: workflow_id,
              path: [{"fleet1", "fail_tool"}],
              source_input: "text",
              target_output: "summary"
            }
          ]
        })

        input = %{"text" => "Boom"}

        assert {:error, {:node_failed, "fail_tool", :invalid_inputs}} =
                 Executor.execute(workflow_id, input)
      end)
    end
  end
end
