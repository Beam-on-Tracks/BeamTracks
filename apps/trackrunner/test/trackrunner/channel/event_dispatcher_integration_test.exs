defmodule Trackrunner.Channel.EventDispatcherIntegrationTest do
  use ExUnit.Case, async: true
  import Phoenix.ChannelTest

  @endpoint TrackrunnerWeb.Endpoint

  alias Trackrunner.Channel.{EventDispatcher, AgentChannelManager, WebsocketContract, WarmPool}

  setup do
    Application.put_env(:trackrunner, :pusher, Trackrunner.Channel.PhoenixPusher)

    # note: use `socket/2` from ChannelTest
    {:ok, _join_reply, socket} =
      socket(@endpoint, %{})
      # join the GenericChannel on "cat:foo"
      |> subscribe_and_join(
        TrackrunnerWeb.GenericChannel,
        "cat:foo",
        %{}
      )

    %{socket: socket, pid: socket.channel_pid}
  end

  test "dispatch/3 fans out over a real Phoenix channel", %{pid: pid} do
    fleet = "fleet1"
    uid = 1

    contract = %WebsocketContract{
      uid: uid,
      # matches dispatch("cat", …)
      category: "cat",
      agent_id: fleet,
      subscriptions: ["foo"],
      publishes: [],
      # placeholders for completeness
      init_event: "startup",
      close_event: "shutdown"
    }

    :ok = AgentChannelManager.register_channels(fleet, uid, [contract])
    WarmPool.mark_connected(fleet, pid)

    EventDispatcher.dispatch("cat", "foo", %{foo: "bar"})

    assert_push "event:foo", %{foo: "bar"}
  end
end
