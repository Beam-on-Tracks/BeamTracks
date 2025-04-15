defmodule Trackrunner.RelayContext do
  @moduledoc """
  Represents metadata passed along with tool execution.
  Used for routing messages, broadcasting completions, and coordinating workflows.
  """

  @type notify_target ::
          {:pid, pid()}
          | {:fleet, String.t()}
          | {:pubsub, term()}

  defstruct [
    # the ID of the originator (e.g., user, tool ID)
    :origin,
    # optional ID for DAG coordination
    :workflow_id,
    # list of {:pid, pid()} | {:fleet, id} | {:pubsub, topic}
    notify_list: []
  ]

  @type t :: %__MODULE__{
          origin: String.t() | atom(),
          workflow_id: String.t() | nil,
          notify_list: [notify_target()]
        }

  @doc """
  Add a new notification target to a RelayContext
  """
  @spec add_notify(t(), notify_target()) :: t()
  def add_notify(%__MODULE__{} = context, target) do
    %{context | notify_list: [target | context.notify_list]}
  end

  @doc """
  Broadcast a message to all notify targets in the RelayContext
  """
  @spec broadcast(t(), any()) :: :ok
  def broadcast(%__MODULE__{notify_list: targets}, message) do
    Enum.each(targets, fn
      {:pid, pid} when is_pid(pid) -> send(pid, message)
      {:fleet, id} -> Trackrunner.FleetScoreCache.record(id, :notified)
      {:pubsub, topic} -> Phoenix.PubSub.broadcast(:tool_events, topic, message)
      _ -> :noop
    end)

    :ok
  end

  @doc """
  Attempt to dispatch a tool execution to a given agent.
  Returns :ok on success, or {:retry, attempts + 1} on failure.
  """
  @spec dispatch(String.t(), String.t(), any(), t(), integer()) :: :ok | {:retry, integer()}
  def dispatch(agent_id, tool_id, tool_node, %__MODULE__{} = context, attempts) do
    case Registry.lookup(:agent_node_registry, {agent_id, tool_id}) do
      [{pid, _}] ->
        IO.puts("✅ Dispatching #{tool_id} to #{agent_id}")
        GenServer.cast(pid, {:execute_tool, tool_node, context})
        :ok

      [] ->
        IO.warn("❌ AgentNode not found for #{agent_id}/#{tool_id}")
        {:retry, attempts + 1}
    end
  end
end
