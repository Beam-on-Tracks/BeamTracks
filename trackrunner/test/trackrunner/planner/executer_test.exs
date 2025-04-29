defmodule Trackrunner.Planner.ExecutorTest do
  use ExUnit.Case, async: false

  alias Trackrunner.Planner.Executor
  alias Trackrunner.Planner.DAGRegistry

  # Helper functions directly in the test module
  defp ensure_dag_registry do
    case Process.whereis(Trackrunner.Planner.DAGRegistry) do
      nil ->
        Trackrunner.Planner.DAGRegistry.start_link([])

      _pid ->
        # Registry already exists, just return success
        {:ok, Process.whereis(Trackrunner.Planner.DAGRegistry)}
    end
  end

  defp ensure_workflow_cache do
    case Process.whereis(:workflow_cache) do
      nil ->
        Cachex.start_link(name: :workflow_cache)

      _pid ->
        # Cache already exists, just return success
        {:ok, Process.whereis(:workflow_cache)}
    end
  end

  setup do
    # Safely ensure both services are available
    {:ok, _} = ensure_workflow_cache()
    {:ok, _} = ensure_dag_registry()
    :ok
  end

  describe "when a static workflow is registered" do
    setup do
      DAGRegistry.register_active_dag(%{
        paths: [
          %{
            name: "static_workflow",
            path: [{"fleet1", "echo"}],
            source_input: "text",
            target_output: "summary"
          }
        ]
      })

      # 🧹 Auto-clear Cachex after each test
      on_exit(fn ->
        workflows = [
          "static_workflow",
          "cached_workflow",
          "failing_workflow",
          "nonexistent_workflow"
        ]

        Enum.each(workflows, fn id -> Cachex.del(:workflow_cache, id) end)
      end)

      :ok
    end

    test "executes workflow from Cachex if present" do
      workflow_id = "cached_workflow"
      input = %{"text" => "Hello"}

      Cachex.put!(:workflow_cache, workflow_id, %{
        "path" => [{"fleet1", "echo"}],
        "source_input" => "text",
        "target_output" => "summary"
      })

      assert {:ok, result} = Executor.execute(workflow_id, input)
      assert result == %{"echoed" => true, "text" => "Hello"}
    end

    test "executes workflow from static DAG and caches it" do
      workflow_id = "static_workflow"

      # Re-register the DAG because setup() empties it
      DAGRegistry.register_active_dag(%{
        paths: [
          %{
            name: workflow_id,
            path: [{"fleet1", "echo"}],
            source_input: "text",
            target_output: "summary"
          }
        ]
      })

      input = %{"text" => "Hello static!"}

      # Execute the workflow
      assert {:ok, result} = Executor.execute(workflow_id, input)

      # Result should match
      assert result == %{"echoed" => true, "text" => "Hello static!"}

      # Now it should be cached!
      assert {:ok, cached} = Cachex.get(:workflow_cache, workflow_id)
      assert cached["path"] == [{"fleet1", "echo"}]
    end

    test "returns error when workflow not found" do
      input = %{"text" => "Missing"}

      assert {:error, :workflow_not_found} = Executor.execute("nonexistent_workflow", input)
    end

    test "returns error if tool runtime fails" do
      # Inject a workflow where the MockTool will simulate an error
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

      assert {:error, :simulated_tool_failure} = Executor.execute(workflow_id, input)
    end
  end
end
