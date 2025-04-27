defmodule Trackrunner.Tool.Utils do
  def discover_executable_tools do
    # tools published by online agents
    AgentChannelManager.lookup_candidates("tool")
    |> Enum.flat_map(fn {_fleet_id, contracts} -> contracts end)
    |> Enum.flat_map(& &1.publishes)
    |> Enum.uniq()
  end
end
