defmodule BeamtracksCli do
  @moduledoc false
  use Application

  def start(_type, _args) do
    BeamtracksCli.Application.start(:normal, [])
  end
end
