defmodule Trackrunner.Planner.Suggester do
  @moduledoc """
  Given a goal (and optional count `n`), returns up to `n` candidate DAGs.
  """

  alias Trackrunner.Planner.DAGRegistry

  @default_n 3

  @spec suggest(map()) :: {:ok, list(map())} | {:error, atom(), map()}
  def suggest(%{"goal" => goal} = params) do
    n = Map.get(params, "n", @default_n)
    planner = Application.get_env(:trackrunner, :planner_llm, Trackrunner.Planner.GPT4)

    static_paths =
      case DAGRegistry.get_active_dag() do
        %{paths: paths} when is_list(paths) -> paths
        _ -> []
      end

    llm_input = %{"goal" => goal, "static_paths" => static_paths}

    with {:ok, dag_map} <- planner.plan(llm_input, []) do
      suggestions =
        1..n
        |> Enum.map(fn _ ->
          id = UUID.uuid4()

          %{
            "workflowId" => id,
            "confidence" => 1.0,
            "description" => "Plan for #{goal}",
            "workflow" => extract_tools(dag_map),
            "expiration" => default_expiration(),
            "source_input_schema" => Map.get(dag_map, "source_input_schema", %{}),
            "target_output_schema" => Map.get(dag_map, "target_output_schema", %{})
          }
        end)

      # TODO: cache suggestions under each `id`
      {:ok, suggestions}
    else
      {:error, %{"error" => _} = err_map} ->
        {:error, :unsupported_goal, err_map}

      {:error, reason} ->
        {:error, :planning_failed, %{reason: inspect(reason)}}
    end
  end

  def suggest(_), do: {:error, :invalid_request, %{}}

  defp extract_tools(%{"nodes" => nodes}) when is_list(nodes) do
    Enum.map(nodes, & &1["tool"])
  end

  defp extract_tools(_), do: []

  defp default_expiration do
    DateTime.utc_now()
    |> DateTime.add(3600, :second)
    |> DateTime.to_iso8601()
  end
end
