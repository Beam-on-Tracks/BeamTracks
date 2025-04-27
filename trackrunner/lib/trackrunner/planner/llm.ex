defmodule Trackrunner.Planner.LLM do
  @moduledoc """
  Behaviour for a workflow‐planning LLM.
  """

  @callback plan(
              input :: map(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
end

