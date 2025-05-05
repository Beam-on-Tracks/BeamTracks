defmodule Trackrunner.Runtime.MockTool do
  @moduledoc false

  @doc """
  Fake tool runner for tests. It echoes back the input slightly modified.
  """
  @spec run(map()) :: {:ok, map()} | {:error, atom()}
  def run(%{"tool_id" => _tool_id, "inputs" => inputs}) do
    case inputs do
      %{"text" => "Boom"} ->
        {:error, :simulated_tool_failure}

      %{"text" => text} ->
        {:ok, %{"echoed" => true, "text" => text}}

      _ ->
        {:error, :invalid_inputs}
    end
  end

  def run(%{"inputs" => %{"text" => "Boom"}}) do
    {:error, :simulated_tool_failure}
  end

  def run(%{"tool_id" => _id, "inputs" => input}) do
    {:ok, %{"text" => input["text"], "echoed" => true}}
  end

  def run(_), do: {:error, :invalid_payload}
end
