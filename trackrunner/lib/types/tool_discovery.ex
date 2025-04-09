defmodule Trackrunner.Types.ToolDiscovery do
  @moduledoc """
  Describes request and response types for `/tool/public/:agent_id/:name`.
  Used to find the URL for a public tool exposed by an agent node.
  """

  @type request :: %{
          required(:agent_id) => String.t(),
          required(:name) => String.t()
        }

  @type success_response :: %{
          required(:tool_url) => String.t()
        }

  @type error_response :: %{
          required(:error) => String.t()
        }
end
