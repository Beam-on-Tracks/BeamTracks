defmodule Trackrunner.Planner.EthicsGuardian do
  @moduledoc """
  EthicsGuardian enforces ethical constraints on goals before DAG generation.
  This is a placeholder module designed to evolve with community input.

  It currently uses a minimal set of hard-coded rules.
  Future versions may support:
  - Configurable ethics profiles
  - LLM-based evaluation of ethical risk
  - Audit logging and reporting hooks
  """

  @spec check(map()) :: :ok | {:error, map()}
  def check(%{"goal" => goal}) when is_binary(goal) do
    goal_down = String.downcase(goal)

    cond do
      goal_down =~ ~r/kill|harm|bomb|torture|assassinate/ ->
        {:error, %{error: "Unethical violation", code: 666}}

      goal_down =~ ~r/child.*exploit|abuse|traffick/ ->
        {:error, %{error: "Unethical violation", code: 666}}

      goal_down =~ ~r/steal|hack|phish|credit card/ ->
        {:error, %{error: "Unethical violation", code: 666}}

      true ->
        :ok
    end
  end

  def check(_), do: :ok
end
