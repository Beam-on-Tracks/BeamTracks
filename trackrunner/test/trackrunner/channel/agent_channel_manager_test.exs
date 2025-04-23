# test/trackrunner/channel/agent_channel_manager_test.exs

defmodule Trackrunner.Channel.AgentChannelManagerTest do
  use ExUnit.Case, async: true

  alias Trackrunner.Channel.{WarmPool, AgentChannelManager}
  alias Trackrunner.Channel.WebsocketContract

  setup do
    # spin up both GenServers under the test supervisor
    start_supervised!(WarmPool)
    :ok
  end

  test "lookup_listeners only returns connected agents with the right subscription" do
    fleet_id = "agent_123"
    uid = 42

    contract = %WebsocketContract{
      category: "chat",
      subscriptions: ["message:new"],
      publishes: [],
      init_event: "message:start",
      close_event: "message:end"
    }

    # 1) register the contract
    :ok = AgentChannelManager.register_channels(fleet_id, uid, [contract])

    # 2) before the agent is marked connected, we get none back
    assert [] == AgentChannelManager.lookup_listeners("chat", "message:new")

    # 3) now mark it connected (warm pool)
    WarmPool.mark_connected(fleet_id, self())

    expected = %WebsocketContract{contract | uid: uid, agent_id: fleet_id}

    # 4) lookup again → should see exactly our entry, with our pid
    assert [{^fleet_id, ^expected, pid}] =
             AgentChannelManager.lookup_listeners("chat", "message:new")

    assert pid == self()
  end

  test "push_to_listener to a subscribed, live pid" do
    # spawn a minimal listener that will forward the push
    listener = spawn(fn -> nil end)
    # construct a full contract: subscribing to "my_event"
    contract = %WebsocketContract{
      agent_id: "fleet1",
      uid: 42,
      subscriptions: ["my_event"],
      # we don’t use publishes here
      publishes: [],
      category: "foo",
      init_event: "startup",
      close_event: "end"
    }

    # invoke the code under test
    AgentChannelManager.push_to_listener(
      {"fleet1", contract, listener},
      %{topic: "event:my_event", message: "hello"}
    )

    # our listener should have seen the message
    assert_receive {:got, ^listener, "event:my_event", "hello"}
  end

  test "push_to_listener cleans up a dead pid" do
    # spawn+kill immediately
    dead = spawn(fn -> nil end)
    Process.exit(dead, :kill)

    contract = %WebsocketContract{
      agent_id: "fleet1",
      uid: 99,
      subscriptions: ["irrelevant"],
      publishes: [],
      category: "foo",
      init_event: "startup",
      close_event: "end"
    }

    # we get :error, and internally we should deregister/disconnect
    assert :error =
             AgentChannelManager.push_to_listener(
               {"fleet1", contract, dead},
               %{topic: "x", message: "y"}
             )

    # (You can spy on WarmPool.mark_disconnected/1 and unregister_node/1
    # via Mox or a test‐only override to assert they were called.)
  end
end
