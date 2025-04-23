defmodule Trackrunner.Channel.TestPusher do
  @behaviour Trackrunner.Channel.Pusher

  # we’ll override this in tests
  def push(pid, topic, msg) do
    send(self(), {:got, pid, topic, msg})
    :ok
  end
end
