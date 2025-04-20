defmodule Trackrunner.Config.Defaults do
  @moduledoc """
  Default configuration values for BeamTracks:

  - Defines pool scaling policies for local, dev, and prod environments.
  - Used by Trackrunner.Config.Configurations.load/0 to merge user overrides with defaults.
  """

  alias Trackrunner.Config.{PoolScalingPolicy, ScalingConfig, Configurations}

  @defaults %Configurations{
    env: Mix.env(),
    scaling: %ScalingConfig{
      pool_policy: %PoolScalingPolicy{
        warm_low_watermark: 0.5,
        warm_high_watermark: 1.5,
        min_size: 1,
        max_size: 3
      }
    }
  }

  @defaults_dev %Configurations{
    env: :dev,
    scaling: %ScalingConfig{
      pool_policy: %PoolScalingPolicy{
        warm_low_watermark: 0.6,
        warm_high_watermark: 1.4,
        min_size: 2,
        max_size: 5
      }
    }
  }

  @defaults_prod %Configurations{
    env: :prod,
    scaling: %ScalingConfig{
      pool_policy: %PoolScalingPolicy{
        warm_low_watermark: 0.7,
        warm_high_watermark: 1.3,
        min_size: 5,
        max_size: 20
      }
    }
  }

  @doc """
  Fetch default configuration for the current environment.
  """
  @spec for_env() :: Configurations.t()
  def for_env do
    case Mix.env() do
      :dev -> @defaults_dev
      :prod -> @defaults_prod
      _ -> @defaults
    end
  end
end
