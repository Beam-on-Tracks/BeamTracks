defmodule Trackrunner.Planner.Executor do
  @moduledoc "Executor walks a static workflow path step-by-step."

  alias Trackrunner.Planner.DAGRegistry
  @tool_runtime Application.compile_env(:trackrunner, :tool_runtime, Trackrunner.Runtime.Tool)
  require Logger

  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def execute(workflow_id, input) do
    dag = DAGRegistry.get_active_dag()
    Logger.debug("[DEBUG] DAG inside Executor: #{inspect(dag)}")

    case dag do
      %{paths: paths} when is_list(paths) ->
        case Enum.find(paths, fn %{name: name} -> name == workflow_id end) do
          nil ->
            {:error, :workflow_not_found}

          %{path: tool_steps} ->
            run_steps(tool_steps, input)
        end

      _ ->
        {:error, :no_workflow_dag}
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
