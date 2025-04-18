# lib/trackrunner_web/controllers/beacon_controller.ex

defmodule TrackrunnerWeb.BeaconController do
  @moduledoc """
  HTTP API for emitting real‐time events into BeamTracks via Beacon.

  v1.0 TODOs:
  - Integrate FleetScoreCache in WorkflowRuntime.dispatch_event for candidate prioritization
  - Add JWT authentication on this endpoint
  - Implement crash‐reschedule logic in Beacon and WorkflowRuntime
  - Harden subscription ACLs based on token claims
  """
  use TrackrunnerWeb, :controller

  alias Trackrunner.{WorkflowRuntime, FleetScoreCache}

  @doc "Publish an event to a BeamTracks category."
  def publish(conn, %{"category" => category, "event" => event, "payload" => payload}) do
    # v1.0: fetch scores for candidate selection
    # scores = FleetScoreCache.get(WorkflowRuntime.candidate_uids(category, event))
    # TODO: select best candidates using scores

    case WorkflowRuntime.dispatch_event(category, event, payload) do
      {:ok, chosen} ->
        json(conn, %{status: "ok", selected: chosen})

      {:error, :no_candidates} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "no candidates for #{category}:#{event}"})
    end
  end
end
