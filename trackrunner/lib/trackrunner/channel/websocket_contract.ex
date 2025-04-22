defmodule Trackrunner.Channel.WebsocketContract do
  @moduledoc """
  A WebSocket contract for a given agent node.
  """

  # Now we require agent_id along with the channel details
  @enforce_keys [:category, :subscriptions, :publishes, :init_event, :close_event]
  defstruct [
    :uid,
    :category,
    :agent_id,
    :subscriptions,
    :publishes,
    :init_event,
    :close_event
  ]
end
