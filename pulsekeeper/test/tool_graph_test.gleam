import gleeunit/should
import tool_graph
import gleam/int
import gleam/string

pub fn test_add_and_get_node() {
  let graph = tool_graph.new()

  let node = tool_graph.ToolNode(
    tool_graph.ToolId("agent-1", "weather"),
    [],
    "DateRequest",
    "WeatherResponse"
  )

  let graph2 = tool_graph.add_node(graph, node)
  let result = tool_graph.get_node(graph2, tool_graph.ToolId("agent-1", "weather"))

  should.equal(Ok(node), result)
}

pub fn test_create_workflow_dag() {
  let node1 = tool_graph.ToolNode(
    tool_graph.ToolId("agent-1", "weather"),
    [],
    "DateRequest",
    "WeatherResponse"
  )

  let node2 = tool_graph.ToolNode(
    tool_graph.ToolId("agent-1", "summarizer"),
    [tool_graph.ToolId("agent-1", "weather")],
    "WeatherResponse",
    "Summary"
  )

  let graph = tool_graph.new()
  let graph = tool_graph.add_node(graph, node1)
  let graph = tool_graph.add_node(graph, node2)

  let result = tool_graph.create_workflow_dag(graph)

  case result {
    Ok(dag) -> {
      let json = tool_graph.workflow_dag_to_string(dag)
      should.equal(True, string.contains(json, "weather"))
      should.equal(True, string.contains(json, "summarizer"))
    }
    Error(_) -> should.equal(True, False) // Force failure if DAG fails
  }
}

pub fn test_detect_cycle_in_deep_graph() {
  let base_id = fn(i) {
    tool_graph.ToolId("agent-2", int.to_string(i))
  }

  let node0 = tool_graph.ToolNode(base_id(0), [], "", "")
  let node1 = tool_graph.ToolNode(base_id(1), [base_id(0)], "", "")
  let node2 = tool_graph.ToolNode(base_id(2), [base_id(1)], "", "")
  let node3 = tool_graph.ToolNode(base_id(3), [base_id(2)], "", "")
  let node4 = tool_graph.ToolNode(base_id(4), [base_id(3)], "", "")
  let node5 = tool_graph.ToolNode(base_id(5), [base_id(4)], "", "")
  let node6 = tool_graph.ToolNode(base_id(6), [base_id(5)], "", "")
  let node7 = tool_graph.ToolNode(base_id(7), [base_id(6)], "", "")
  let node8 = tool_graph.ToolNode(base_id(8), [base_id(7)], "", "")
  let node9 = tool_graph.ToolNode(base_id(9), [base_id(8)], "", "")
  let node10 = tool_graph.ToolNode(base_id(10), [base_id(9), base_id(2)], "", "") // Introduces a cycle

  let graph = tool_graph.new()
  let graph = tool_graph.add_node(graph, node0)
  let graph = tool_graph.add_node(graph, node1)
  let graph = tool_graph.add_node(graph, node2)
  let graph = tool_graph.add_node(graph, node3)
  let graph = tool_graph.add_node(graph, node4)
  let graph = tool_graph.add_node(graph, node5)
  let graph = tool_graph.add_node(graph, node6)
  let graph = tool_graph.add_node(graph, node7)
  let graph = tool_graph.add_node(graph, node8)
  let graph = tool_graph.add_node(graph, node9)
  let graph = tool_graph.add_node(graph, node10)

  let result = tool_graph.create_workflow_dag(graph)

  case result {
    Ok(_) -> should.equal(True, False) // We expect a cycle, test should fail if Ok
    Error(e) -> should.equal(True, string.contains(e, "Cycle detected"))
  }
}

pub fn test_create_workflow_dag_invalid() {
  let id1 = tool_graph.ToolId("agentX", "z")
  let id2 = tool_graph.ToolId("agentY", "missing")
  let node = tool_graph.ToolNode(id1, [id2], "in", "out")
  let graph = tool_graph.add_node(tool_graph.new(), node)

  case tool_graph.create_workflow_dag(graph) {
    Ok(_) ->
      should.equal(True, False) // This should NOT happen

    Error(_) ->
      should.equal(True, True) // This is expected
  }
}

