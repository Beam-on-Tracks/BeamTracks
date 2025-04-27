defmodule Trackrunner.Planner do
  @moduledoc """
  Orchestrates the two‐phase planning flow:
    • suggest/1 → returns N candidate workflows
    • execute/2 → runs a chosen workflow
  """

  alias Trackrunner.Planner.{Suggester, Executor}

  @doc """
  params must include "goal" (string) and optional "n" (integer).
  Returns `{:ok, [%Suggestion{}]}` or `{:error, reason}`.
  """
  @spec suggest(map()) :: {:ok, list(map())} | {:error, atom(), map()}
  def suggest(%{"goal" => _} = params) do
    Suggester.suggest(params)
  end

  def suggest(_), do: {:error, :invalid_request, %{}}

  @doc """
  Given a workflowId and source_input map, dispatches the execution.
  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def execute(workflow_id, source_input) do
    Executor.execute(workflow_id, source_input)
  end
end
