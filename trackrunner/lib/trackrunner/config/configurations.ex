defmodule Trackrunner.Config.Configurations do
  @moduledoc """
  Loads BeamTracks configuration by merging compiled defaults
  (defined in `Trackrunner.Config.Defaults`) with any overrides in
  `config/config.exs`.
  """

  alias Trackrunner.Config.{ScalingConfig, Defaults}

  @type t :: %__MODULE__{
          env: atom(),
          scaling: ScalingConfig.t()
        }

  defstruct [:env, :scaling]

  @spec load() :: t()
  def load do
    # 1) Fetch defaults for current Mix.env
    defaults = Defaults.for_env()

    # 2) Fetch any overrides from config/config.exs
    overrides = Application.get_env(:trackrunner, __MODULE__, %{})

    # 3) Build final config struct
    %__MODULE__{
      env: defaults.env,
      scaling: merge_scaling(defaults.scaling, Map.get(overrides, :scaling, %{}))
    }
  end

  # Merge a default ScalingConfig with user-provided keyword overrides
  defp merge_scaling(%ScalingConfig{pool_policy: default_pool} = scaling, pool_overrides) do
    merged_pool =
      default_pool
      |> Map.from_struct()
      |> Map.merge(pool_overrides)
      |> struct(default_pool.__struct__)

    %ScalingConfig{scaling | pool_policy: merged_pool}
  end
end
