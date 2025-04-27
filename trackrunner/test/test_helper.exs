{:ok, _} = Trackrunner.Planner.DAGRegistry.start_link([])
ExUnit.start()

# ensure our application and its children (WarmPool, AgentChannelManager, etc.) are running
{:ok, _} = Application.ensure_all_started(:trackrunner)

Code.require_file("support/test_support.ex", __DIR__)
