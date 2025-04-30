defmodule Trackrunner.Planner.ExecutorTest do
  use ExUnit.Case, async: false

  alias Trackrunner.Planner.Executor
  alias Trackrunner.Planner.DAGRegistry

  import TestSupport

  setup do
    IO.puts("🔍 DIRECT LOG: Starting ExecutorTest setup")

    # Start with a clean slate - delete any existing workflow_cache entries
    if Process.whereis(:workflow_cache) do
      IO.puts("🔍 DIRECT LOG: Clearing existing workflow_cache before test")

      ["static_workflow", "cached_workflow", "failing_workflow", "nonexistent_workflow"]
      |> Enum.each(fn key ->
        # Only try to delete if the workflow_cache process exists
        try do
          Cachex.del(:workflow_cache, key)
          IO.puts("🔍 DIRECT LOG: Deleted #{key} from workflow_cache")
        catch
          kind, error ->
            IO.puts("🔍 DIRECT LOG: Error deleting #{key}: #{inspect(kind)} - #{inspect(error)}")
        end
      end)
    end

    # Now ensure services are started in the correct order
    {:ok, _} = ensure_workflow_cache()
    {:ok, _} = ensure_dag_registry()
    ensure_mock_tool_runtime()

    # Only register on_exit callback if the workflow_cache exists
    if Process.whereis(:workflow_cache) do
      on_exit(fn ->
        IO.puts("🔍 DIRECT LOG: ExecutorTest cleanup in on_exit")
        # Only try to delete if the workflow_cache still exists
        if Process.whereis(:workflow_cache) do
          IO.puts("🔍 DIRECT LOG: Clearing workflow_cache in on_exit")

          ["static_workflow", "cached_workflow", "failing_workflow", "nonexistent_workflow"]
          |> Enum.each(fn key ->
            try do
              Cachex.del(:workflow_cache, key)
              IO.puts("🔍 DIRECT LOG: Successfully deleted #{key} in on_exit")
            catch
              kind, error ->
                IO.puts(
                  "🔍 DIRECT LOG: Error in on_exit deleting #{key}: #{inspect(kind)} - #{inspect(error)}"
                )
            end
          end)
        else
          IO.puts("🔍 DIRECT LOG: workflow_cache process no longer exists in on_exit")
        end
      end)
    end

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
        if :ets.info(:workflow_cache) != :undefined do
          ["static_workflow", "cached_workflow", "failing_workflow", "nonexistent_workflow"]
          |> Enum.each(&Cachex.del(:workflow_cache, &1))
        end
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
