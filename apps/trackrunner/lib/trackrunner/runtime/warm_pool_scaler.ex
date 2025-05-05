defmodule Trackrunner.Runtime.WarmPoolScaler do
  @moduledoc """
  Periodically inspects agent warm pool and decides whether to scale up or down.

  Relies on:
    - WarmPool ETS data for current connected agents.
    - Per-category or per-agent scaling policies (see `Trackrunner.Config.PoolScalingPolicy`).
    - Future metrics like usage rate, idle time, response latency.

  This module is intended to run as a GenServer or as part of a supervisor tree loop.
  """

  alias Trackrunner.Channel.WarmPool
  alias Trackrunner.Config.PoolScalingPolicy

  @type category :: String.t()

  # TODO: Define this data structure or move it to config
  @default_policy %PoolScalingPolicy{
    warm_low_watermark: 0.3,
    warm_high_watermark: 0.9,
    min_size: 1,
    max_size: 10
  }

  @doc """
  Called periodically. Inspects warm pool stats and decides which
  categories or agents need scaling actions.
  """
  def tick do
    # TODO:
    # 1. Enumerate current warm pool agents by category (from WarmPool).
    # 2. Fetch current "desired" size (from config or external scheduler).
    # 3. Call PoolScalingPolicy.reconcile/3
    # 4. Issue scale-up/down requests (via WorkflowRuntime? FleetSupervisor?)
    # 5. Log scaling actions

    :noop
  end

  # TODO (future):
  # - Integrate with telemetry/metrics to inform better scaling
  # - Handle burst prediction (spike detection)
  # - Separate per-category vs per-agent policies
  # - Possibly delay scale down for stability (hysteresis buffer)

end
