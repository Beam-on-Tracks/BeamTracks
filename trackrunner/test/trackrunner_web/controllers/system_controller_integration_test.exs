defmodule TrackrunnerWeb.SystemControllerIntegrationTest do
  use TrackrunnerWeb.ConnCase, async: false
  alias Trackrunner.Planner.{DAGRegistry, Executor}
  alias TrackrunnerWeb.Router.Helpers, as: Routes
  import TestSupport
  import Logger

  setup do
    Logger.debug("🔍 DIRECT LOG: Starting SystemControllerIntegrationTest setup")

    # Ensure both services are properly initialized
    {:ok, cache_pid} = ensure_workflow_cache()
    {:ok, dag_pid} = ensure_dag_registry()

    # Important: Monitor these processes to detect if they die
    cache_ref = Process.monitor(cache_pid)
    dag_ref = Process.monitor(dag_pid)

    # Store these for later
    context = %{
      cache_pid: cache_pid,
      dag_pid: dag_pid,
      cache_ref: cache_ref,
      dag_ref: dag_ref
    }

    # Register an on_exit that will verify processes are alive
    on_exit(fn ->
      Logger.debug("🔍 DIRECT LOG: SystemControllerIntegrationTest cleanup in on_exit")

      # Process any pending flush messages
      receive do
        {:DOWN, ^cache_ref, :process, _, reason} ->
          Logger.debug("🔍 DIRECT LOG: Cache process died during test: #{inspect(reason)}")
      after
        0 -> :ok
      end

      receive do
        {:DOWN, ^dag_ref, :process, _, reason} ->
          Logger.debug("🔍 DIRECT LOG: DAG process died during test: #{inspect(reason)}")
      after
        0 -> :ok
      end
    end)

    # Make sure to use the fully qualified module name for DAGRegistry
    # Add this line below to prevent the error in DAGRegistry.register_active_dag
    {:ok, Map.put(context, :conn, Phoenix.ConnTest.build_conn())}
  end

  test "POST /api/plan/execute caches and executes static workflow", %{
    conn: conn,
    dag_pid: dag_pid,
    cache_pid: cache_pid
  } do
    Logger.debug(
      "🔍 DIRECT LOG: Starting test with DAG pid: #{inspect(dag_pid)}, cache pid: #{inspect(cache_pid)}"
    )

    # Verify processes are still alive before starting test
    if !Process.alive?(dag_pid) do
      Logger.debug("🔍 DIRECT LOG: DAG process died before test! Restarting")
      {:ok, new_pid} = ensure_dag_registry()
      dag_pid = new_pid
    end

    if !Process.alive?(cache_pid) do
      Logger.debug("🔍 DIRECT LOG: Cache process died before test! Restarting")
      {:ok, new_pid} = ensure_workflow_cache()
      cache_pid = new_pid
    end

    # Use the fully qualified module name
    workflow_id = "system_chain"

    Logger.debug("🔍 DIRECT LOG: Registering workflow #{workflow_id}")
    # Use fully qualified module name
    Trackrunner.Planner.DAGRegistry.register_active_dag(%{
      paths: [
        %{
          name: workflow_id,
          path: [
            {"fleet1", "echo"},
            {"fleet2", "echo"},
            {"fleet3", "echo"}
          ],
          source_input: "text",
          target_output: "text"
        }
      ]
    })

    # First run via the HTTP API
    params = %{"workflowId" => workflow_id, "source_input" => %{"text" => "Hello"}}

    conn = post(conn, "/api/plan/execute", params)
    %{"target_output" => output1} = json_response(conn, 200)
    assert output1 == %{"echoed" => true, "text" => "Hello"}

    # Verify it’s cached in Cachex
    {:ok, cached} = Cachex.get(:workflow_cache, workflow_id)

    assert cached["path"] == [
             {"fleet1", "echo"},
             {"fleet2", "echo"},
             {"fleet3", "echo"}
           ]

    # Second run — should hit cache path again
    conn2 = post(conn, "/api/plan/execute", params)
    %{"target_output" => output2} = json_response(conn2, 200)
    assert output2 == output1
  end
end
