defmodule Trackrunner.Planner.MockChat do
  @moduledoc """
  Fake chat client for testing without real OpenAI calls.
  """

  def create(_payload) do
    {:ok, %{"choices" => [%{"message" => %{"content" => ~s|{
      "nodes": [
        { "id": "test_node", "tool": "echo", "inputs": { "text": "This is fake." } }
      ],
      "edges": []
    }|}}]}}
  end
end
