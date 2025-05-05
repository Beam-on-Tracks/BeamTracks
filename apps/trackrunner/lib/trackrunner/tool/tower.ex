defmodule Trackrunner.Tool.Tower do
  @moduledoc "Eventually manages retries, fallback agents, and metrics"

  def maybe_retry(_tool_id, _reason), do: :ok
  def record_success(_agent_id), do: :ok
  def record_failure(_agent_id, _reason), do: :ok
end
