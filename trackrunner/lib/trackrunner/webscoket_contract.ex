defmodule Trackrunner.WebsocketContract do
  @enforce_keys [:category, :identity, :subscriptions, :publishes]
  defstruct [:category, :identity, :subscriptions, :publishes]
end
