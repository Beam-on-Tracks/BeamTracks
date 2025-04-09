defmodule Trackrunner.Conventions do
  @public_tool "/tool/public/:agent_id/:name"
  def public_tool_path(agent_id, name), do: "/tool/public/#{agent_id}/#{name}"
  @private_tool "/tool/private/:agent_id/:name"
  def private_tool_path(agent_id, name), do: "/tool/private/#{agent_id}/#{name}"
end
