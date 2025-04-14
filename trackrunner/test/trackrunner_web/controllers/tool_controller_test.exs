defmodule TrackrunnerWeb.ToolControllerTest do
  use ExUnit.Case, async: true
  use TrackrunnerWeb.ConnCase

  setup do
    start_supervised!({Trackrunner.AgentFleet, "agentzero"})

    {:ok, _} =
      Trackrunner.AgentFleet.add_node("agentzero", %{
        ip: "localhost:5001",
        public_tools: %{"voice" => "/voice"},
        private_tools: %{},
        tool_dependencies: %{}
      })

    start_supervised!(Pulsekeeper.Server)

    :ok
  end

  describe "GET /tool/public/:agent_id/:name" do
    test "returns tool URL for existing tool", %{conn: conn} do
      tool_node = {:tool_node, {:tool_id, "agentzero", "voice"}, [], "in", "out"}

      :ok =
        Pulsekeeper.Server.register_dag(%{
          {"agentzero", "voice"} => tool_node
        })

      Pulsekeeper.Server.mark_node_complete({"agentzero", "voice"})

      response =
        get(conn, "/api/tool/public/agentzero/voice")
        |> json_response(200)

      assert response["tool_url"] == "http://localhost:5001/voice"
    end
  end
end
