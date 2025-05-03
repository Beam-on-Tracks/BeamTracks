defmodule Trackrunner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    add_gleam_path()

    children = [
      TrackrunnerWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:trackrunner, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Trackrunner.PubSub},
      {Finch, name: Trackrunner.Finch},
      TrackrunnerWeb.Endpoint,

      # BeamTracks core
      {Registry, keys: :unique, name: Trackrunner.Agent.FleetRegistry},
      {Registry, keys: :unique, name: :agent_node_registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Trackrunner.FleetSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: BeaconSupervisor},
      {Trackrunner.WorkflowRuntime, []},
      {Trackrunner.Tool.Registry, []},
      Trackrunner.FleetScoreCache,
      Trackrunner.Channel.AgentChannelManager,
      Trackrunner.Channel.WarmPool,
      Trackrunner.Planner.DAGRegistry
    ]

    opts = [strategy: :one_for_one, name: Trackrunner.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TrackrunnerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Helper to add the Gleam path correctly
  defp add_gleam_path do
    parent_dir = Path.dirname(File.cwd!())

    # Add both the pulsekeeper path and the gleam_stdlib path
    pulsekeeper_path = Path.join(parent_dir, "pulsekeeper/build/dev/erlang/pulsekeeper/ebin")
    stdlib_path = Path.join(parent_dir, "pulsekeeper/build/dev/erlang/gleam_stdlib/ebin")

    # Add both paths
    :code.add_pathz(String.to_charlist(pulsekeeper_path))
    :code.add_pathz(String.to_charlist(stdlib_path))

    IO.puts("Added Gleam paths: #{pulsekeeper_path} and #{stdlib_path}")
  end
end
