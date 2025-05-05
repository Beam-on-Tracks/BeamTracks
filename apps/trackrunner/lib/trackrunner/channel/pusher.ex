# lib/trackrunner/channel/pusher.ex
defmodule Trackrunner.Channel.Pusher do
  @callback push(pid(), topic :: String.t(), msg :: any()) :: :ok | {:error, term()}
end
