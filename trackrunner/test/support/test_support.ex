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
    IO.puts("🔍 DIRECT LOG: Ensuring registry #{inspect(name)} is started")

    case Process.whereis(name) do
      nil ->
        IO.puts("🔍 DIRECT LOG: Registry #{inspect(name)} not found, starting it")
        spec = {Registry, Keyword.put(opts, :name, name)}
        result = start_child_safely(spec)
        IO.puts("🔍 DIRECT LOG: Registry #{inspect(name)} start result: #{inspect(result)}")
        result

      pid ->
        IO.puts(
          "🔍 DIRECT LOG: Registry #{inspect(name)} already running with PID: #{inspect(pid)}"
        )

        :ok
    end
  end

  @doc """
  Ensures a supervisor or process with a named identifier is started.
  This works for GenServers or DynamicSupervisors as well.
  """
  def ensure_process_started(name, start_spec) do
    IO.puts("🔍 DIRECT LOG: Ensuring process #{inspect(name)} is started")

    case Process.whereis(name) do
      nil ->
        IO.puts("🔍 DIRECT LOG: Process #{inspect(name)} not found, starting it")
        result = start_child_safely(start_spec)
        IO.puts("🔍 DIRECT LOG: Process #{inspect(name)} start result: #{inspect(result)}")
        result

      pid ->
        IO.puts(
          "🔍 DIRECT LOG: Process #{inspect(name)} already running with PID: #{inspect(pid)}"
        )

        :ok
    end
  end

  defp start_child_safely(spec) do
    IO.puts("🔍 DIRECT LOG: Starting child safely with spec: #{inspect(spec)}")
    test_supervisor_pid = Process.whereis(Test.Supervisor)
    IO.puts("🔍 DIRECT LOG: Test.Supervisor PID: #{inspect(test_supervisor_pid)}")

    if test_supervisor_pid == nil do
      IO.puts("🔍 DIRECT LOG: Test.Supervisor not found! This may cause test failures")
      {:error, :supervisor_not_found}
    else
      case Supervisor.start_child(Test.Supervisor, spec) do
        {:ok, pid} ->
          IO.puts("🔍 DIRECT LOG: Successfully started child with PID: #{inspect(pid)}")
          :ok

        {:error, {:already_started, pid}} ->
          IO.puts("🔍 DIRECT LOG: Child already started with PID: #{inspect(pid)}")
          :ok

        {:error, reason} = err ->
          IO.puts("🔍 DIRECT LOG: Failed to start child: #{inspect(reason)}")
          err
      end
    end
  end

  @doc """
  Ensures DAGRegistry is started safely. This is idempotent and will return
  the existing registry if it's already running.
  """
  def ensure_dag_registry do
    IO.puts("🔍 DIRECT LOG: Ensuring DAGRegistry is started")

    registry_pid = Process.whereis(Trackrunner.Planner.DAGRegistry)

    IO.puts("🔍 DIRECT LOG: DAGRegistry exists: #{inspect(registry_pid != nil)}")

    result =
      case registry_pid do
        nil ->
          IO.puts("🔍 DIRECT LOG: Starting new DAGRegistry")
          start_result = Trackrunner.Planner.DAGRegistry.start_link([])
          IO.puts("🔍 DIRECT LOG: DAGRegistry start result: #{inspect(start_result)}")
          start_result

        pid ->
          IO.puts("🔍 DIRECT LOG: Found existing DAGRegistry with PID: #{inspect(pid)}")
          {:ok, pid}
      end

    # Log the ETS tables for debugging
    all_tables = :ets.all() |> Enum.map(&:ets.info(&1, :name))
    IO.puts("🔍 DIRECT LOG: Current ETS tables: #{inspect(all_tables)}")

    result
  end

  @doc """
  Ensures the workflow_cache Cachex is started. This is idempotent 
  and will return the existing cache if it's already running.
  """
  def ensure_workflow_cache do
    IO.puts("🔍 DIRECT LOG: Ensuring workflow_cache is started")

    cache_pid = Process.whereis(:workflow_cache)
    table_exists = :ets.info(:workflow_cache) != :undefined

    IO.puts(
      "🔍 DIRECT LOG: Cache process exists: #{inspect(cache_pid != nil)}, ETS table exists: #{inspect(table_exists)}"
    )

    result =
      case cache_pid do
        nil ->
          IO.puts("🔍 DIRECT LOG: Starting new workflow_cache")
          start_result = Cachex.start_link(name: :workflow_cache)

          # Verify the process was created
          new_pid = Process.whereis(:workflow_cache)
          IO.puts("🔍 DIRECT LOG: New workflow_cache process exists: #{inspect(new_pid != nil)}")

          IO.puts("🔍 DIRECT LOG: workflow_cache start result: #{inspect(start_result)}")
          start_result

        pid ->
          IO.puts("🔍 DIRECT LOG: Found existing workflow_cache with PID: #{inspect(pid)}")
          {:ok, pid}
      end

    # Verify ETS table was created
    new_table_exists = :ets.info(:workflow_cache) != :undefined
    IO.puts("🔍 DIRECT LOG: workflow_cache ETS table exists after setup: #{new_table_exists}")

    # Log the ETS tables for debugging
    all_tables = :ets.all() |> Enum.map(&:ets.info(&1, :name))
    IO.puts("🔍 DIRECT LOG: All ETS tables after setup: #{inspect(all_tables)}")

    result
  end

  @doc """
  Stub out the OpenAI client to use our MockChat
  """
  def ensure_mock_planner do
    IO.puts("🔍 DIRECT LOG: Setting up mock planner")
    Application.put_env(:trackrunner, :planner_real_calls, false)
    Application.put_env(:trackrunner, :openai_chat_module, Trackrunner.Planner.MockChat)
    IO.puts("🔍 DIRECT LOG: Mock planner configured")
    :ok
  end

  @doc """
  Stub out tool runtime so Executor never pushes real WebSocket messages
  """
  def ensure_mock_tool_runtime do
    IO.puts("🔍 DIRECT LOG: Setting up mock tool runtime")
    Application.put_env(:trackrunner, :tool_runtime, Trackrunner.Runtime.MockTool)
    IO.puts("🔍 DIRECT LOG: Mock tool runtime configured")
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
      IO.puts("🔍 DIRECT LOG: Waiting for process #{inspect(name_or_pid)} to terminate")
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          IO.puts("🔍 DIRECT LOG: Process #{inspect(name_or_pid)} terminated")
          :ok
      after
        timeout ->
          IO.puts("🔍 DIRECT LOG: Process #{inspect(name_or_pid)} did not terminate in time")
          Process.demonitor(ref, [:flush])
          :timeout
      end
    else
      IO.puts("🔍 DIRECT LOG: Process #{inspect(name_or_pid)} is already terminated")
      :ok
    end
  end
end
