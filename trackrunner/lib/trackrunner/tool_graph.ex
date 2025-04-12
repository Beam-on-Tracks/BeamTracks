# trackrunner/lib/trackrunner/tool_graph.ex
defmodule Trackrunner.ToolGraph do
  def new, do: :tool_graph.new()

  def add_node(graph, agent_id, tool_name, deps \\ []) do
    node = {:tool_node, {:tool_id, agent_id, tool_name}, deps}
    :tool_graph.add_node(graph, node)
  end

  def all_nodes(graph), do: :tool_graph.all_nodes(graph)
end
