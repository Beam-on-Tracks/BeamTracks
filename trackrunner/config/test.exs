import Config

config :trackrunner, :pusher, Trackrunner.Channel.TestPusher

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :trackrunner, TrackrunnerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "test_secret_key_base",
  server: false

config :trackrunner, :openai_chat_module, Trackrunner.Planner.MockChat
config :trackrunner, :tool_runtime, Trackrunner.Runtime.MockTool
config :trackrunner, :planner_real_calls, false

config :logger, level: :warn

# In test we don't send emails
config :trackrunner, Trackrunner.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
