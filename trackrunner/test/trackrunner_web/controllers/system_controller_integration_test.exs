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

  @tag :skip
  test "TODO: implement end-to-end suggester and executor flow" do
    # Implement HTTP-based integration tests covering:
    #   1. Suggestion generation and caching via /api/plan/suggest
    #   2. Execution of suggested and static workflows via /api/plan/execute
    #   3. Changing the DAG (DAGRegistry.register_active_dag) and verifying
    #      that previously cached static workflows are no longer callable.
    :ok
  end
end
