defmodule Trackrunner.Planner.ExecutorTest do
  use ExUnit.Case, async: false

  alias Trackrunner.Planner.Executor
  alias Trackrunner.Planner.DAGRegistry

  require Logger

  setup do
    unless Process.whereis(Trackrunner.Planner.DAGRegistry) do
      {:ok, _} = Trackrunner.Planner.DAGRegistry.start_link([])
    end

    Logger.debug(
      "[DEBUG] DAGRegistry is alive? #{inspect(Process.alive?(Process.whereis(Trackrunner.Planner.DAGRegistry)))}"
    )

    Trackrunner.Planner.DAGRegistry.register_active_dag(%{
      paths: [
        %{
          name: "simple_workflow",
          path: [{"fleet1", "echo"}],
          source_input: "text",
          target_output: "summary"
        }
      ]
    })

    :ok
  end

  test "execute/2 walks a simple workflow path" do
    input = %{"text" => "Hello, world!"}

    assert {:ok, result} = Executor.execute("simple_workflow", input)

    assert result["text"] == "Hello, world!"
    assert result["echoed"] == true
  end
end
