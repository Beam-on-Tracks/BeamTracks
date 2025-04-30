defmodule TrackrunnerWeb.PlannerControllerIntegrationTest do
  use TrackrunnerWeb.ConnCase, async: false
  use Phoenix.ConnTest
  alias TrackrunnerWeb.Router.Helpers, as: Routes
  import TestSupport

  setup do
    IO.puts("🔍 DIRECT LOG: Starting SystemControllerIntegrationTest setup")

    # Ensure services are properly initialized
    ensure_workflow_cache()
    ensure_dag_registry()

    :ok
  end

  @tag :real_openai

  @tag skip: !Application.get_env(:trackrunner, :planner_real_calls, false)
  test "POST /api/plan/suggest ranks the 3-step static workflow highest", %{conn: conn} do
    System.get_env("OPENAI_API_KEY") ||
      raise("Please set OPENAI_API_KEY to run real-OpenAI tests")

    # Register multiple dummy paths
    DAGRegistry.register_active_dag(%{
      paths: [
        %{
          name: "cheap_path",
          path: [{"fleetX", "echo"}],
          source_input: "text",
          target_output: "summary"
        },
        %{
          name: "medium_path",
          path: [{"fleetA", "echo"}, {"fleetB", "transform"}],
          source_input: "text",
          target_output: "result"
        },
        %{
          name: "ideal_path",
          path: [
            {"fleet1", "step_a"},
            {"fleet2", "step_b"},
            {"fleet3", "step_c"}
          ],
          source_input: "initial_input",
          target_output: "final_output"
        }
      ]
    })

    # Force real planner
    Application.put_env(:trackrunner, :planner_real_calls, true)

    # Hit the suggest endpoint
    params = %{"goal" => "run a three-step pipeline from A to C", "n" => 3}
    conn = post(conn, Routes.planner_path(conn, :suggest), params)
    assert json_response(conn, 200) =~ "["
    suggestions = json_response(conn, 200)

    # Ensure we got exactly 3 suggestions
    assert length(suggestions) == 3

    [first | _] = suggestions
    # The first description should reference our "three-step" hint
    assert first["description"] =~ "three-step"
    assert Enum.any?(first["workflow"], &(&1 == "fleet1/step_a"))
  end
end
