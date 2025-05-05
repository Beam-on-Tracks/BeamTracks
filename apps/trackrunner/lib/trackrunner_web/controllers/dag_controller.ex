defmodule TrackrunnerWeb.DAGController do
  use TrackrunnerWeb, :controller

  alias Trackrunner.Planner.DAGRegistry

  @doc """
  GET /api/dag
  Returns the current and previous DAG snapshot.
  """
  def show(conn, _params) do
    %{current: current, previous: previous} = DAGRegistry.snapshot()

    json(conn, %{
      current_dag: current || %{},
      previous_dag: previous || %{}
    })
  end
end
