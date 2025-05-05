# lib/trackrunner/scaling_config.ex
defmodule Trackrunner.Config.ScalingConfig do
  @moduledoc """
  High-level scaling configuration wrapper.
  Holds nested policies, e.g. `pool_policy` for WebSocket warm pools.
  """
  alias Trackrunner.Config.PoolScalingPolicy

  defstruct [
    # policy for scaling WebSocket pools
    pool_policy: %PoolScalingPolicy{}
  ]

  @type t :: %__MODULE__{
          pool_policy: PoolScalingPolicy.t()
        }
end
