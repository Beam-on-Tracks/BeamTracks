defmodule Trackrunner.Planner.DAGRegistry do
  use Agent

  alias Trackrunner.Planner.WorkflowCache
  @initial_state %{current: nil, previous: nil}

  def start_link(_opts) do
    Agent.start_link(fn -> @initial_state end, name: __MODULE__)
  end

  @doc "Register a new active DAG (atomically saving the old one)."
  def register_active_dag(dag) do
    # Ensure dag has a paths key, defaulting to empty list if missing
    paths = Map.get(dag, :paths, [])
    WorkflowCache.reset_static_workflows(paths)

    Agent.update(__MODULE__, fn state ->
      %{current: dag, previous: state.current}
    end)
  end

  @doc "Retrieve the currently active DAG."
  def get_active_dag do
    Agent.get(__MODULE__, & &1.current)
  end

  @doc "Revert to the previously active DAG."
  def revert_to_previous do
    Agent.update(__MODULE__, fn state ->
      %{current: state.previous, previous: state.previous}
    end)
  end

  @doc "Return a snapshot of both current and previous DAGs."
  def snapshot do
    Agent.get(__MODULE__, & &1)
  end

  @doc "Clear out all DAG state (reset to initial)."
  def clear_registry do
    Agent.update(__MODULE__, fn _ -> @initial_state end)
  end
end
