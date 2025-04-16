defmodule Trackrunner.ToolContract do
  @moduledoc """
  Describes how a tool should be executed.

  ToolContracts are passed around to define what kind of tool is being invoked
  (HTTP service, local function, shell command, mock), where to send the input,
  and what we expect in terms of output behavior.
  """
  @enforce_keys [:name, :mode, :target, :inputs, :outputs]

  @type execution_mode :: :http | :function | :script | :flame | :mock

  defstruct [
    # "tool:echo"
    :name,
    # :http | :function | :script | etc.
    :mode,
    # e.g., URL, function reference, script path
    :target,
    # optional list of expected inputs
    :inputs,
    # optional output format or transformation hint
    :outputs,
    # optional output for http verb
    :verb
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          mode: execution_mode,
          target: any(),
          inputs: list(String.t()) | nil,
          outputs: list(String.t()) | nil
        }
end
