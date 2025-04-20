defmodule Trackrunner.FleetScoreCache do
  @moduledoc """
  Tracks request counts and (eventually) latency scores per agent.
  Used by WorkflowRuntime to pick the best candidate agent.
  """

  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc """
  Increments request count for the given agent_id.
  """
  def bump(agent_id) do
    GenServer.cast(__MODULE__, {:bump, agent_id})
  end

  @doc """
  Returns list of agent_ids with their scores (load) as {id, score} tuples.
  """
  def get(agent_ids) do
    GenServer.call(__MODULE__, {:get, agent_ids})
  end

  def init(state), do: {:ok, state}

  def handle_cast({:bump, agent_id}, state) do
    updated =
      Map.update(state, agent_id, %{requests: 1}, fn entry ->
        %{entry | requests: entry.requests + 1}
      end)

    {:noreply, updated}
  end

  def handle_call({:get, ids}, _from, state) do
    result =
      ids
      |> Enum.map(fn id ->
        {id, Map.get(state, id, %{requests: 0}).requests}
      end)

    {:reply, result, state}
  end
end
