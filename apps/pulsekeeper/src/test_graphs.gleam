import tool_graph.{new, add_node, ToolId, ToolNode, type ToolGraph}

pub fn valid_graph() -> ToolGraph {
  new()
  |> add_node(ToolNode(ToolId("agent1", "a"), [], "in", "out"))
  |> add_node(ToolNode(ToolId("agent1", "b"), [ToolId("agent1", "a")], "in", "out"))
  |> add_node(ToolNode(ToolId("agent1", "c"), [ToolId("agent1", "b")], "in", "out"))
}

pub fn broken_graph() -> ToolGraph {
  new()
  |> add_node(ToolNode(ToolId("agentX", "z"), [ToolId("agentY", "missing")], "in", "out"))
}

