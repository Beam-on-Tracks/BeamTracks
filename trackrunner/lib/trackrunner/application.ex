defmodule Trackrunner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TrackrunnerWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:trackrunner, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Trackrunner.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Trackrunner.Finch},
      # Start a worker by calling: Trackrunner.Worker.start_link(arg)
      # {Trackrunner.Worker, arg},
      # Start to serve requests, typically the last entry
      TrackrunnerWeb.Endpoint,

      # BeamTracks core
      {Registry, keys: :unique, name: Trackrunner.AgentFleetRegistry},
      {Registry, keys: :unique, name: :agent_node_registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Trackrunner.FleetSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
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
end
