# Load all files in test/support
# Load all support files (.ex and .exs) under test/support
support_files =
  Path.wildcard(Path.join(__DIR__, "support/**/*.ex")) ++
    Path.wildcard(Path.join(__DIR__, "support/**/*.exs"))

IO.inspect(support_files, label: "→ Loading support files")
Enum.each(support_files, &Code.require_file(&1))

ExUnit.start()

# ensure our application and its children (WarmPool, AgentChannelManager, etc.) are running
{:ok, _} = Application.ensure_all_started(:trackrunner)
