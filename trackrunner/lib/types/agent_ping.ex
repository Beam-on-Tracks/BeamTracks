defmodule Trackrunner.Types.AgentPing do
  @moduledoc """
  Describes the expected shape of an agent node ping request.

  This is used for registration via `/api/ping`, which helps the Trackrunner system
  discover, register, and assign unique IDs to incoming agent nodes.
  """

  @type tool_map :: %{optional(String.t()) => String.t()}

  @type t :: %{
          required(:agent_id) => String.t(),
          required(:ip_hint) => String.t(),
          optional(:public_tools) => tool_map(),
          optional(:private_tools) => tool_map(),
          optional(:tool_dependencies) => tool_dependency_map()
        }
end
