# lib/trackrunner/planner/gpt4.ex
defmodule Trackrunner.Planner.GPT4 do
  @moduledoc """
  Default planner using OpenAI's GPT-4.
  """
  @behaviour Trackrunner.Planner.LLM

  def plan(%{"goal" => goal} = input, _opts) when is_binary(goal) do
    with :ok <- maybe_check_ethics(input) do
      case Trackrunner.Planner.DAGRegistry.get_active_dag() do
        nil ->
          {:error, :no_static_workflows}

        %{paths: static_paths} ->
          workflows_description =
            static_paths
            |> Enum.map(fn %{name: name, path: tools} ->
              tools_str = tools |> Enum.map(fn {a, t} -> "#{a}/#{t}" end) |> Enum.join(" → ")
              "- #{name}: #{tools_str}"
            end)
            |> Enum.join("\n")

          prompt = """
          You are an AI workflow planner.

          **Static Workflows (you may choose to follow or adapt these):**
          #{workflows_description}

          **New Goal:** #{goal}

          Generate a valid JSON DAG that reuses or extends the above workflows.
          """

          if Application.get_env(:trackrunner, :planner_real_calls, false) do
            # Real OpenAI call
            chat_module = Application.get_env(:trackrunner, :openai_chat_module, OpenAI.Chat)

            case chat_module.create(%{
                   model: "gpt-4-1106-preview",
                   messages: [%{role: "user", content: prompt}],
                   temperature: 0.2
                 }) do
              {:ok, %{"choices" => [%{"message" => %{"content" => content}}]}} ->
                case Jason.decode(content) do
                  {:ok, dag} -> {:ok, dag}
                  error -> {:error, "Invalid JSON: #{inspect(error)}"}
                end

              error ->
                {:error, "LLM call failed: #{inspect(error)}"}
            end
          else
            # Dummy result for tests/dev
            {:ok,
             %{
               "nodes" => [
                 %{
                   "id" => "static_step1",
                   "tool" => "echo",
                   "inputs" => %{"text" => "Hello Test!"}
                 }
               ],
               "edges" => []
             }}
          end
      end
    end
  end

  defp maybe_check_ethics(input) do
    if :rand.uniform() < 0.0001 do
      Trackrunner.Planner.EthicsGuardian.check(input)
    else
      :ok
    end
  end

  # New private function
  defp maybe_check_ethics(input) do
    if :rand.uniform() < 0.0001 do
      Trackrunner.Planner.EthicsGuardian.check(input)
    else
      :ok
    end
  end
end
