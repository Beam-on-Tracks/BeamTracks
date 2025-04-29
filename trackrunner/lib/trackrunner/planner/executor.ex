defmodule Trackrunner.Planner.Executor do
  @moduledoc "Executor walks a static workflow path step-by-step."

  alias Trackrunner.Planner.DAGRegistry
  @tool_runtime Application.compile_env(:trackrunner, :tool_runtime, Trackrunner.Runtime.Tool)
  require Logger

  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def execute(workflow_id, input) do
    dag = DAGRegistry.get_active_dag()
    Logger.debug("[DEBUG] DAG inside Executor: #{inspect(dag)}")

    if is_nil(dag) do
      {:error, :no_workflow_dag}
    else
      case Cachex.get(:workflow_cache, workflow_id) do
        {:ok, nil} ->
          lookup_static_workflow(workflow_id, dag)
          |> case do
            {:ok, tool_steps} -> run_steps(tool_steps, input)
            {:error, reason} -> {:error, reason}
          end

        {:ok, cached_workflow} when is_map(cached_workflow) ->
          run_steps(cached_workflow["path"], input)

        {:error, _reason} ->
          {:error, :cache_lookup_failed}
      end
    end
  end

  defp lookup_static_workflow(workflow_id, %{paths: paths}) do
    case Enum.find(paths, fn %{name: name} -> name == workflow_id end) do
      nil ->
        {:error, :workflow_not_found}

      %{path: tool_steps} = workflow ->
        # This is the key change - store a map with path instead of the whole workflow
        cached_entry = %{
          "path" => tool_steps,
          "source_input" => workflow[:source_input],
          "target_output" => workflow[:target_output]
        }

        Cachex.put(:workflow_cache, workflow_id, cached_entry)
        {:ok, tool_steps}
    end
  end

  defp run_steps([], last_output), do: {:ok, last_output}

  defp run_steps([{agent_id, tool_name} | rest], input) do
    tool_call = %{
      "tool_id" => "#{agent_id}/#{tool_name}",
      "inputs" => input
    }

    case @tool_runtime.run(tool_call) do
      {:ok, output} ->
        run_steps(rest, output)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
