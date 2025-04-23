defmodule Trackrunner.Channel.EventDispatcher do
  @moduledoc """
  The EventDispatcher sits between your beacon/WebSocket layer (incoming events)
  and the AgentChannelManager. It exists to:

    1. **Decouple** raw beacon handling from channel fan‑out logic  
    2. **Transform** or enrich events before they hit the socket layer  
    3. **Centralize** observability, error handling, and future routing needs  

  Why keep it around?
  - **Single Responsibility:** your beacon just ingests; your manager just pushes.
  - **Room to Grow:** add metrics, retries, alternate back‑ends (Kafka, SQS), feature‑flags—all without touching beacon or manager.
  - **Observability:** one place to log, trace, and monitor “events that went out.”
  """

  alias Trackrunner.Channel.AgentChannelManager
  require Logger

  @doc """
  Accepts a raw beacon event and fans it out to all subscribers.

  ## Steps
    1. (Optional) transform or enrich the raw payload  
    2. Wrap it into a channel‑ready map  
    3. Delegate to `AgentChannelManager.dispatch/3` for lookup, push, and cleanup  

  ## TODO
    - [ ] **Telemetry:** instrument dispatch latency & fan‑out count  
    - [ ] **Schema validation:** ensure payload matches expected shape  
    - [ ] **Feature flags:** enable/disable events dynamically  
    - [ ] **Retry/circuit‑breaker:** on transient downstream failures  
    - [ ] **Alternate sinks:** emit to Kafka/SQS for audit or replay  
  """
  @spec dispatch(String.t(), String.t(), map()) :: :ok
  def dispatch(category, event, raw_payload) do
    # 1. Transform or enrich
    payload = transform(raw_payload)

    # 2. Build the channel message
    channel_msg = %{
      topic: "event:#{event}",
      message: payload
    }

    # 3. Fan out & clean up dead sockets
    AgentChannelManager.dispatch(category, event, channel_msg)
  end

  # Private helpers

  @doc false
  defp transform(payload) do
    # TODO: add timestamps/correlation IDs
    # TODO: apply JSON schema or custom validation
    payload
  end
end

