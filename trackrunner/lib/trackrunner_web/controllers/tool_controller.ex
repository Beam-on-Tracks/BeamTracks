defmodule TrackrunnerWeb.ToolController do
  use TrackrunnerWeb, :controller

  def get_public(conn, %{"agent_id" => agent_id, "name" => name}) do
    case Trackrunner.Registry.lookup_tool(agent_id, name) do
      {:ok, url} -> json(conn, %{tool_url: url})
      :not_found -> send_resp(conn, 404, "Tool not found")
    end
  end
end
