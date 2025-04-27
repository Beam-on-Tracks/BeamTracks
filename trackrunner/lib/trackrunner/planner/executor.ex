defmodule Trackrunner.Planner.Executor do
  @moduledoc false

  def execute(_workflow_id, _source_input) do
    {:error, :not_found}
  end
end
