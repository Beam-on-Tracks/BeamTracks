defmodule Trackrunner.Planner.Executor do
  @moduledoc """
  Executes a given workflow by ID and input map.
  """

  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def execute(_workflow_id, _input) do
    {:ok, %{"result" => "simulated execution"}}
  end
end
