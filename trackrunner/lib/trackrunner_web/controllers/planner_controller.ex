defmodule TrackrunnerWeb.PlannerController do
  use TrackrunnerWeb, :controller

  alias Trackrunner.Planner

  # POST /api/plan/suggest
  def suggest(conn, params) do
    case Planner.suggest(params) do
      {:ok, suggestions} ->
        json(conn, suggestions)

      {:error, reason} ->
        conn
        |> put_status(502)
        |> json(%{"error" => "Planning error", "reason" => inspect(reason)})
    end
  end

  # POST /api/plan/execute
  def execute(conn, %{"workflowId" => id, "source_input" => src_input}) do
    case Planner.execute(id, src_input) do
      {:ok, result} ->
        json(conn, %{"target_output" => result})

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{"error" => "Unknown workflowId", "code" => 404})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{"error" => "Execution failed", "reason" => inspect(reason)})
    end
  end
end
