# lib/trackrunner/planner/gpt4.ex
defmodule Trackrunner.Planner.GPT4 do
  @moduledoc """
  Default planner using OpenAI's GPT-4.
  """
  @behaviour Trackrunner.Planner.LLM

  def plan(%{"goal" => goal} = _input, _opts \\ []) do
    prompt = """
    You are an AI workflow planner. Based on the goal below, generate a valid JSON DAG.

    Goal: #{goal}

    Return a JSON like:
    {
      "nodes": [
        { "id": "step1", "tool": "fetch_url", "inputs": { "url": "..." } },
        { "id": "step2", "tool": "summarize", "inputs": { "text": "${step1.output}" } }
      ],
      "edges": [
        { "from": "step1", "to": "step2" }
      ]
    }
    """

    case OpenAI.Chat.create(%{
           model: "gpt-4-1106-preview",
           messages: [%{role: "user", content: prompt}],
           temperature: 0.2
         }) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}}]}} ->
        case Jason.decode(content) do
          {:ok, dag} -> {:ok, dag}
          err -> {:error, "Invalid JSON: #{inspect(err)}"}
        end

      err ->
        {:error, "LLM failed: #{inspect(err)}"}
    end
  end
end
