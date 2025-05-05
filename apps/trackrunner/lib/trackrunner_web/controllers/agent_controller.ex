defmodule TrackrunnerWeb.AgentController do
  use TrackrunnerWeb, :controller

  @moduledoc """
  TODO: Implement Agent Research API so agents can potentially modify
  workflows

  Should return the list of tools (and their input/output schemas)
  exposed by the given agent.
  """

  def show(conn, %{"agent_id" => agent_id}) do
    # TODO: lookup via Trackrunner.Tool.Registry or Agent API
    # stub
    tools = []

    json(conn, %{
      agent_id: agent_id,
      tools: tools
    })
  end
end
