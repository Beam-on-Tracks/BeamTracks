defmodule Trackrunner.Config.PoolScalingPolicy do
  @moduledoc """
  Given current warm capacity and a desired pool size, decide
  whether to scale up, scale down, or do nothing.
  """

  defstruct [
    # when warm/capacity dips below this fraction, scale up
    :warm_low_watermark,
    # when warm/capacity rises above this fraction, scale down
    :warm_high_watermark,
    # min and max absolute pool sizes
    :min_size,
    :max_size
  ]

  @type t :: %__MODULE__{
          warm_low_watermark: float(),
          warm_high_watermark: float(),
          min_size: non_neg_integer(),
          max_size: non_neg_integer()
        }

  @doc """
  Compare current warm count to desired, under this policy.

  Returns one of:
    - `{:scale_up, n}`   – we need `n` more slots  
    - `{:scale_down, n}` – we have `n` too many  
    - `:no_action`       – everything’s within the thresholds
  """
  @spec reconcile(t(), non_neg_integer(), non_neg_integer()) ::
          {:scale_up, non_neg_integer()} | {:scale_down, non_neg_integer()} | :no_action
  def reconcile(%__MODULE__{} = policy, warm, desired) do
    cond do
      warm < desired * policy.warm_low_watermark ->
        needed = min(policy.max_size, desired) - warm
        {:scale_up, needed}

      warm > desired * policy.warm_high_watermark ->
        excess = warm - max(policy.min_size, desired)
        {:scale_down, excess}

      true ->
        :no_action
    end
  end
end
