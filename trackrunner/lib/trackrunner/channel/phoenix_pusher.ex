defmodule Trackrunner.Channel.PhoenixPusher do
  @behaviour Trackrunner.Channel.Pusher

  @impl true
  def push(pid, topic, msg) do
    # the real deal
    Phoenix.Channel.Server.push(pid, topic, msg)
    :ok
  rescue
    err -> {:error, err}
  end
end
