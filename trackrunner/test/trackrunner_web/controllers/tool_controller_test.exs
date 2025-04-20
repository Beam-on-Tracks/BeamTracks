defmodule TrackrunnerWeb.ToolControllerTest do
  use ExUnit.Case, async: true
  use TrackrunnerWeb.ConnCase

  alias Trackrunner.WorkflowRuntime

  

  setup do
    {:ok, _} = Trackrunner.Agent.Fleet.ensure_started("agent_1")
    {:ok, _} = Trackrunner.Agent.Fleet.ensure_started("agentzero")

    {:ok, _} =
      Trackrunner.Agent.Fleet.add_node("agentzero", %{
        agent_id: "agentzero",
        ip: "localhost:5001",
        public_tools: %{"voice" => "/voice"},
        private_tools: %{},
        tool_dependencies: %{}
      })

    start_supervised!(Pulsekeeper.Server)

    # on_exit(fn ->
    #   # Cleanup logic here
    #   IO.puts("🧼 Cleaning up agent_1")
    #   # You can optionally terminate it manually:
    #   case Registry.lookup(Trackrunner.Agent.FleetRegistry, "agent_1") do
    #     [{pid, _}] ->
    #       DynamicSupervisor.terminate_child(Trackrunner.FleetSupervisor, pid)
    # 
    #     _ ->
    #       :ok
    #   end
    # end)
    #
    :ok
  end

  test "can register tool and dispatch to agent node" do
    {:ok, _} = Trackrunner.Agent.Fleet.ensure_started("agent_1")
    tool_node_id = "test:echo"
    Trackrunner.Tool.Registry.register("agent_1", tool_node_id)

    {:ok, _} =
      Trackrunner.Agent.Fleet.add_node("agent_1", %{
        agent_id: "agent_1",
        ip: "127.0.0.1",
        public_tools: %{tool_node_id => "available"},
        private_tools: %{},
        tool_dependencies: %{}
      })

    context = %Trackrunner.RelayContext{
      origin: :test,
      workflow_id: "u1",
      notify_list: [{:pid, self()}]
    }

    WorkflowRuntime.handle_tool_node(%{id: "test:echo", input: "hello world"}, context)
    assert_receive {:executed_tool, ^tool_node_id, "hello world"}, 1000
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
