defmodule TrackrunnerWeb.PlannerControllerIntegrationTest do
  use TrackrunnerWeb.ConnCase, async: false
  alias TrackrunnerWeb.Router.Helpers, as: Routes
  import TestSupport
  import Logger
  # Check this environment variable only once
  @run_real_openai Application.compile_env(:trackrunner, :planner_real_calls, false)

  setup do
    IO.puts("🔍 DIRECT LOG: Starting SystemControllerIntegrationTest setup")
    # Ensure services are properly initialized
    ensure_workflow_cache()
    ensure_dag_registry()
    :ok
  end

  # Use ExUnit's built-in conditional test execution
  if @run_real_openai do
    @tag :real_openai
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

      # Hit the suggest endpoint - make sure this route exists in your router
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
  else
    @tag :real_openai
    test "POST /api/plan/suggest - skipped", _context do
      Logger.info("Skipping real_openai test because planner_real_calls is false")
      :ok
    end
  end
end
