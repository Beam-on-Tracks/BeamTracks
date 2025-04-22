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
end
