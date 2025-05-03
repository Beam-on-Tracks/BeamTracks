defmodule TestSupport do
  require Logger

  @moduledoc """
  Utility helpers for test setup and safe process supervision.
  """

  @doc """
  Ensures a registry with the given name is started, unless it's already running.
  Accepts optional options like `:keys`.
  """
  def ensure_registry_started(name, opts \\ [keys: :unique]) do
    Logger.debug("Ensuring registry #{inspect(name)} is started")

    case Process.whereis(name) do
      nil ->
        Logger.debug("Registry #{inspect(name)} not found, starting it")
        spec = {Registry, Keyword.put(opts, :name, name)}
        result = start_child_safely(spec)
        Logger.debug("Registry #{inspect(name)} start result: #{inspect(result)}")
        result

      pid ->
        Logger.debug("Registry #{inspect(name)} already running with PID: #{inspect(pid)}")
        :ok
    end
  end

  @doc """
  Ensures a supervisor or process with a named identifier is started.
  This works for GenServers or DynamicSupervisors as well.
  """
  def ensure_process_started(name, start_spec) do
    Logger.debug("Ensuring process #{inspect(name)} is started")

    case Process.whereis(name) do
      nil ->
        Logger.debug("Process #{inspect(name)} not found, starting it")
        result = start_child_safely(start_spec)
        Logger.debug("Process #{inspect(name)} start result: #{inspect(result)}")
        result

      pid ->
        Logger.debug("Process #{inspect(name)} already running with PID: #{inspect(pid)}")
        :ok
    end
  end

  defp start_child_safely(spec) do
    Logger.debug("Starting child safely with spec: #{inspect(spec)}")
    test_supervisor_pid = Process.whereis(Test.Supervisor)
    Logger.debug("Test.Supervisor PID: #{inspect(test_supervisor_pid)}")

    if test_supervisor_pid == nil do
      Logger.debug("Test.Supervisor not found! This may cause test failures")
      {:error, :supervisor_not_found}
    else
      case Supervisor.start_child(Test.Supervisor, spec) do
        {:ok, pid} ->
          Logger.debug("Successfully started child with PID: #{inspect(pid)}")
          :ok

        {:error, {:already_started, pid}} ->
          Logger.debug("Child already started with PID: #{inspect(pid)}")
          :ok

        {:error, reason} = err ->
          Logger.debug("Failed to start child: #{inspect(reason)}")
          err
      end
    end
  end

  @doc """
  Ensures DAGRegistry is started safely. This is idempotent and will return
  the existing registry if it's already running.
  """
  def ensure_dag_registry do
    Logger.debug("Ensuring DAGRegistry is started")

    registry_pid = Process.whereis(Trackrunner.Planner.DAGRegistry)

    Logger.debug("DAGRegistry exists: #{inspect(registry_pid != nil)}")

    result =
      case registry_pid do
        nil ->
          Logger.debug("Starting new DAGRegistry")
          start_result = Trackrunner.Planner.DAGRegistry.start_link([])
          Logger.debug("DAGRegistry start result: #{inspect(start_result)}")
          start_result

        pid ->
          Logger.debug("Found existing DAGRegistry with PID: #{inspect(pid)}")
          {:ok, pid}
      end

    # Log the ETS tables for debugging
    all_tables = :ets.all() |> Enum.map(&:ets.info(&1, :name))
    Logger.debug("Current ETS tables: #{inspect(all_tables)}")

    result
  end

  @doc """
  Ensures the workflow_cache Cachex is started. This is idempotent 
  and will return the existing cache if it's already running.
  """
  def ensure_workflow_cache do
    Logger.debug("Ensuring workflow_cache is started")

    cache_pid = Process.whereis(:workflow_cache)
    table_exists = :ets.info(:workflow_cache) != :undefined

    Logger.debug(
      "Cache process exists: #{inspect(cache_pid != nil)}, ETS table exists: #{inspect(table_exists)}"
    )

    result =
      case cache_pid do
        nil ->
          Logger.debug("Starting new workflow_cache")
          start_result = Cachex.start_link(name: :workflow_cache)

          # Verify the process was created
          new_pid = Process.whereis(:workflow_cache)
          Logger.debug("New workflow_cache process exists: #{inspect(new_pid != nil)}")

          Logger.debug("workflow_cache start result: #{inspect(start_result)}")
          start_result

        pid ->
          Logger.debug("Found existing workflow_cache with PID: #{inspect(pid)}")
          {:ok, pid}
      end

    # Also ensure dynamic workflow cache
    case Process.whereis(:dynamic_workflow) do
      nil ->
        Cachex.start_link(name: :dynamic_workflow, default_ttl: :timer.minutes(30))

      pid ->
        {:ok, pid}
    end

    # Verify ETS table was created
    new_table_exists = :ets.info(:workflow_cache) != :undefined
    Logger.debug("workflow_cache ETS table exists after setup: #{new_table_exists}")

    # Log the ETS tables for debugging
    all_tables = :ets.all() |> Enum.map(&:ets.info(&1, :name))
    Logger.debug("All ETS tables after setup: #{inspect(all_tables)}")

    result
  end

  @doc """
  Stub out the OpenAI client to use our MockChat
  """
  def ensure_mock_planner do
    Logger.debug("Setting up mock planner")
    Application.put_env(:trackrunner, :planner_real_calls, false)
    Application.put_env(:trackrunner, :openai_chat_module, Trackrunner.Planner.MockChat)
    Logger.debug("Mock planner configured")
    :ok
  end

  @doc """
  Stub out tool runtime so Executor never pushes real WebSocket messages
  """
  def ensure_mock_tool_runtime do
    Logger.debug("Setting up mock tool runtime")
    Application.put_env(:trackrunner, :tool_runtime, Trackrunner.Runtime.MockTool)
    Logger.debug("Mock tool runtime configured")
    :ok
  end

  @doc """
  Safely check if a process is alive and wait for it to terminate if needed.
  This is useful for ensuring test cleanup between tests.
  """
  def ensure_process_terminated(name_or_pid, timeout \\ 100) do
    pid =
      case name_or_pid do
        pid when is_pid(pid) -> pid
        name -> Process.whereis(name)
      end

    if pid && Process.alive?(pid) do
      Logger.debug("Waiting for process #{inspect(name_or_pid)} to terminate")
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          Logger.debug("Process #{inspect(name_or_pid)} terminated")
          :ok
      after
        timeout ->
          Logger.debug("Process #{inspect(name_or_pid)} did not terminate in time")
          Process.demonitor(ref, [:flush])
          :timeout
      end
    else
      Logger.debug("Process #{inspect(name_or_pid)} is already terminated")
      :ok
    end
  end

  @doc """
  Runs a test function with cleaned ETS tables and service state.
  Ensures proper setup and teardown even if the test fails.
  """
  def with_clean_state(context, fun) do
    # Start with clean state - make sure services are started
    {:ok, cache_pid} = ensure_workflow_cache()
    {:ok, dag_pid} = ensure_dag_registry()

    # Clear any existing cache entries
    if :ets.info(:workflow_cache) != :undefined do
      Cachex.clear(:workflow_cache)
    end

    # Setup mock tools if needed
    ensure_mock_tool_runtime()

    try do
      # Run the test function
      fun.()
    after
      # Always clean up even if the test fails
      if Process.alive?(cache_pid) && :ets.info(:workflow_cache) != :undefined do
        # Clear cache
        Cachex.clear(:workflow_cache)
        Logger.debug("Cache cleared in with_clean_state teardown")
      else
        Logger.debug("Cache process or table no longer exists in teardown")
      end
    end
  end
end
