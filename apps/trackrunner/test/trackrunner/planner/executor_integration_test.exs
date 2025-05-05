# test/trackrunner/planner/executor_integration_test.exs
defmodule Trackrunner.Planner.ExecutorIntegrationTest do
  use ExUnit.Case, async: false

  alias Trackrunner.Planner.{DAG, Executor}
  alias Trackrunner.Channel.WarmPool
  import TestSupport

  setup do
    # Reset state
    :ok = WarmPool.clear()
    :ok = DAG.clear_registry()

    # Define three MockAgents that append distinct suffixes
    defmodule AppendAAgent do
      @behaviour Trackrunner.Agent.Behaviour
      @impl true
      def call(%{"input" => input}) when is_binary(input), do: {:ok, input <> "-A"}
    end

    defmodule AppendBAgent do
      @behaviour Trackrunner.Agent.Behaviour
      @impl true
      def call(%{"input" => input}) when is_binary(input), do: {:ok, input <> "-B"}
    end

    defmodule AppendCAgent do
      @behaviour Trackrunner.Agent.Behaviour
      @impl true
      def call(%{"input" => input}) when is_binary(input), do: {:ok, input <> "-C"}
    end

    # Register them under three keys
    :ok = WarmPool.register_agent("agent_a", AppendAAgent)
    :ok = WarmPool.register_agent("agent_b", AppendBAgent)
    :ok = WarmPool.register_agent("agent_c", AppendCAgent)

    # Chain them in a 3-node workflow
    spec = %{
      id: "chain_append_workflow",
      nodes: [
        %{name: "n1", agent: "agent_a", args: %{"input" => "start"}},
        %{name: "n2", agent: "agent_b", args: %{"input" => nil}},
        %{name: "n3", agent: "agent_c", args: %{"input" => nil}}
      ],
      edges: [
        {"n1", "n2"},
        {"n2", "n3"}
      ]
    }

    {:ok, workflow} = DAG.register_static_workflow(spec)
    %{workflow: workflow}
  end

  test "executes three-node workflow with each agent appending suffixes", %{workflow: workflow} do
    assert {:ok, results} = Executor.execute(workflow.id, nil)

    # We expect:
    #   n1 → "start-A"
    #   n2 → "start-A-B"
    #   n3 → "start-A-B-C"
    assert [
             %{node: "n1", result: "start-A"},
             %{node: "n2", result: "start-A-B"},
             %{node: "n3", result: "start-A-B-C"}
           ] = results
  end
end

