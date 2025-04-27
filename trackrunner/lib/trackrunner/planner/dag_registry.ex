defmodule Trackrunner.Planner.DAGRegistry do
  @moduledoc """
  Holds the active WorkflowDAG and supports rollback and snapshot.
  """

  use Agent

  @doc "Start with empty DAG state"
  def start_link(_opts) do
    Agent.start_link(fn -> %{current: nil, previous: nil} end, name: __MODULE__)
  end

  @doc "Register a new active DAG (atomically saves the old one for rollback)"
  def register_active_dag(dag) do
    Agent.update(__MODULE__, fn state ->
      %{current: dag, previous: state.current}
    end)
  end

  @doc "Retrieve the currently active DAG"
  def get_active_dag do
    Agent.get(__MODULE__, & &1.current)
  end

  @doc "Revert to the previously active DAG"
  def revert_to_previous do
    Agent.update(__MODULE__, fn state ->
      %{current: state.previous, previous: state.previous}
    end)
  end

  @doc """
  Return a snapshot of both current and previous DAGs.
  Future: could persist this or tag it with timestamps.
  """
  def snapshot do
    Agent.get(__MODULE__, & &1)
  end
end
