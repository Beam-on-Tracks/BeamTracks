defmodule Beamtracks.CLI.PingTracker do
  @moduledoc """
  Tracks recent agent pings in an Agent.
  Filters out entries older than `@ttl_seconds` on each read.
  """

  use Agent

  @ttl_seconds 5

  # Public API

  @doc "Start the tracker with an empty map"
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc "Record a ping timestamp for an agent"
  def record_ping(agent_id) do
    now = DateTime.utc_now()

    Agent.update(__MODULE__, fn state ->
      Map.put(state, agent_id, now)
    end)
  end

  @doc """
  Get only the pings within the last @ttl_seconds.
  Automatically filters stale entries.
  """
  def get_active do
    now = DateTime.utc_now()

    Agent.get(__MODULE__, fn state ->
      state
      |> Enum.filter(fn {_id, ts} ->
        DateTime.diff(now, ts) < @ttl_seconds
      end)
      |> Map.new()
    end)
  end
end
