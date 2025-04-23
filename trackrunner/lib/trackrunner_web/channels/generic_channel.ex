defmodule TrackrunnerWeb.GenericChannel do
  @moduledoc """
  A catch-all channel for real-time “cat:*” topics.
  """

  use Phoenix.Channel

  # Accept any "cat:<subtopic>" join
  def join("cat:" <> _subtopic, _payload, socket) do
    {:ok, socket}
  end
end
