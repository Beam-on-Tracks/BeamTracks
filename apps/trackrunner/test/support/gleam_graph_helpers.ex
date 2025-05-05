defmodule GleamGraphHelpers do
  @moduledoc """
  Helper functions to encode Elixir-native graph definitions into Gleam-compatible ToolGraph data.
  """

  @type tool_id_raw :: {:tool_id, String.t(), String.t()}
  @type tool_node_raw :: {:tool_node, tool_id_raw, [tool_id_raw], String.t(), String.t()}
  @type raw_graph :: %{{String.t(), String.t()} => tool_node_raw}

  def to_tool_id({:tool_id, agent, name}), do: {:ToolId, agent, name}

  def to_tool_node({:tool_node, id, deps, input, output}) do
    {:ToolNode, to_tool_id(id), Enum.map(deps, &to_tool_id/1), input, output}
  end

  def encode_graph(raw) do
    raw
    |> Enum.map(fn {{agent, name}, node} ->
      {to_tool_id({:tool_id, agent, name}), to_tool_node(node)}
    end)
    # Ensure ordering for gb_trees
    |> Enum.sort_by(fn {{:ToolId, a, b}, _} -> {a, b} end)
    |> :gb_trees.from_orddict()
  end
end
