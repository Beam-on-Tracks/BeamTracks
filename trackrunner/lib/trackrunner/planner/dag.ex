defmodule Trackrunner.Planner.DAG do
  alias Trackrunner.Planner.DAGRegistry

  def register_static_workflow(spec) do
    DAGRegistry.register_active_dag(spec)
    {:ok, spec}
  end

  def clear_registry do
    DAGRegistry.clear_registry()
  end

  def get_active_dag do
    DAGRegistry.get_active_dag()
  end
end
