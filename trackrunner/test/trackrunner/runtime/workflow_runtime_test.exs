defmodule Trackrunner.WorkflowRuntimeTest do
  use ExUnit.Case, async: true

  alias Trackrunner.WorkflowRuntime
  alias Trackrunner.RelayContext
  alias Trackrunner.TestSupport

  setup do
    TestSupport.ensure_registry_started(Trackrunner.Agent.FleetRegistry)
    TestSupport.ensure_registry_started(:agent_node_registry)

    TestSupport.ensure_process_started(
      Trackrunner.FleetSupervisor,
      {DynamicSupervisor, strategy: :one_for_one, name: Trackrunner.FleetSupervisor}
    )

    TestSupport.ensure_process_started(Trackrunner.Tool.Registry, Trackrunner.Tool.Registry)
    TestSupport.ensure_process_started(Trackrunner.WorkflowRuntime, Trackrunner.WorkflowRuntime)

    :ok
  end

  test "dispatches tool_node after agent becomes available" do
    tool_id = "test:echo"

    context = %RelayContext{
      origin: :test,
      workflow_id: "wf1",
      notify_list: [{:pid, self()}]
    }

    WorkflowRuntime.handle_tool_node(
      %{id: tool_id, input: "queued call", output: ""},
      context
    )

    # Allow time for it to queue
    Process.sleep(100)

    # Start agent fleet and register tool
    {:ok, _} = Trackrunner.Agent.Fleet.ensure_started("agent_1")
    Trackrunner.Tool.Registry.register("agent_1", tool_id)

    {:ok, _} =
      Trackrunner.Agent.Fleet.add_node("agent_1", %{
        agent_id: "agent_1",
        ip: "127.0.0.1",
        public_tools: %{tool_id => "available"},
        private_tools: %{},
        tool_dependencies: %{}
      })

    # Wait for tick cycle to retry and dispatch
    assert_receive {:executed_tool, ^tool_id, "queued call"}, 1500
  end
end
