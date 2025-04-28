defmodule Trackrunner.Runtime.MockTool do
  @moduledoc false

  @doc """
  Fake tool runner for tests. It echoes back the input slightly modified.
  """
  @spec run(map()) :: {:ok, map()} | {:error, atom()}
  def run(%{"tool_id" => _tool_id, "inputs" => inputs}) do
    # Simulate tool behavior
    {:ok, Map.put(inputs, "echoed", true)}
  end

  def run(_), do: {:error, :invalid_payload}
end
