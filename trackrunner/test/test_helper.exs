{:ok, _} = Cachex.start_link(name: :workflow_cache)
ExUnit.start()

# ensure our application and its children (WarmPool, AgentChannelManager, etc.) are running
{:ok, _} = Application.ensure_all_started(:trackrunner)

Code.require_file("support/test_support.ex", __DIR__)
