import gleam/dict
import gleam/list
import gleam/string
import gleam/int
import gleam/string_tree as st

pub type ToolId {
  ToolId(String, String) // agent_id, tool_name
}

pub type ToolNode {
  ToolNode(
    id: ToolId,
    dependencies: List(ToolId),
    input: String,
    output: String
  )
}

pub type ToolGraph = dict.Dict(ToolId, ToolNode)

pub type StaticWorkflow {
  StaticWorkflow(
    name: String,
    path: List(ToolId)
  )
}

pub type WorkflowDAG {
  WorkflowDAG(
    graph: ToolGraph,
    paths: List(StaticWorkflow)
  )
}

pub fn new() -> ToolGraph {
  dict.new()
}

pub fn add_node(graph: ToolGraph, node: ToolNode) -> ToolGraph {
  let ToolNode(id, _, _, _) = node
  dict.insert(graph, id, node)
}

pub fn get_node(graph: ToolGraph, id: ToolId) -> Result(ToolNode, Nil) {
  dict.get(graph, id)
}

pub fn all_nodes(graph: ToolGraph) -> List(ToolNode) {
  dict.values(graph)
}

pub fn create_workflow_dag(graph: ToolGraph) -> Result(WorkflowDAG, String) {
  case topo_sort(graph) {
    Ok(sorted) -> {
      let paths = group_paths(graph, sorted)
      Ok(WorkflowDAG(graph, paths))
    }
    Error(e) -> Error(e)
  }
}

pub fn topo_sort(graph: ToolGraph) -> Result(List(ToolId), String) {
  visit_nodes(graph, dict.keys(graph), dict.new(), [])
}

fn visit_nodes(
  graph: ToolGraph,
  to_visit: List(ToolId),
  visited: dict.Dict(ToolId, Bool),
  result: List(ToolId)
) -> Result(List(ToolId), String) {
  case to_visit {
    [] -> Ok(result)
    [node_id, ..rest] ->
      case dict.get(visited, node_id) {
        Ok(True) -> visit_nodes(graph, rest, visited, result)
        Ok(False) -> Error("Cycle detected at node")
        Error(_) -> {
          let visited = dict.insert(visited, node_id, False)
          case dict.get(graph, node_id) {
            Ok(ToolNode(_, deps, _, _)) ->
              case visit_dependencies(graph, deps, visited, result) {
                Error(e) -> Error(e)
                Ok(#(visited2, result2)) -> {
                  let visited3 = dict.insert(visited2, node_id, True)
                  visit_nodes(graph, rest, visited3, [node_id, ..result2])
                }
              }
            Error(_) -> {
              let visited = dict.insert(visited, node_id, True)
              visit_nodes(graph, rest, visited, result)
            }
          }
        }
      }
  }
}

fn visit_dependencies(
  graph: ToolGraph,
  deps: List(ToolId),
  visited: dict.Dict(ToolId, Bool),
  result: List(ToolId)
) -> Result(#(dict.Dict(ToolId, Bool), List(ToolId)), String) {
  case deps {
    [] -> Ok(#(visited, result))
    [dep, ..rest] ->
      case dict.get(visited, dep) {
        Ok(True) -> visit_dependencies(graph, rest, visited, result)
        Ok(False) -> Error("Cycle detected at dependency")
        Error(_) -> {
          let visited = dict.insert(visited, dep, False)
          case dict.get(graph, dep) {
            Ok(ToolNode(_, subdeps, _, _)) ->
              case visit_dependencies(graph, subdeps, visited, result) {
                Error(e) -> Error(e)
                Ok(#(visited2, result2)) -> {
                  let visited3 = dict.insert(visited2, dep, True)
                  visit_dependencies(graph, rest, visited3, [dep, ..result2])
                }
              }
            Error(_) -> {
              let visited = dict.insert(visited, dep, True)
              visit_dependencies(graph, rest, visited, result)
            }
          }
        }
      }
  }
}

pub fn group_paths(graph: ToolGraph, sorted: List(ToolId)) -> List(StaticWorkflow) {
  let extend_path = fn(acc, id) {
    case dict.get(graph, id) {
      Ok(ToolNode(_, deps, _, _)) ->
        case deps {
          [] -> [StaticWorkflow("path_" <> int.to_string(list.length(acc)), [id]), ..acc]
          _ -> list.append(
            deps |> list.map(fn(d) {
              StaticWorkflow("path_" <> int.to_string(list.length(acc)), [id, d])
            }),
            acc
          )
        }
      _ -> acc
    }
  }

  list.fold(sorted, [], extend_path)
}

pub fn next_nodes(plan: WorkflowDAG, current: ToolId) -> List(ToolId) {
  let WorkflowDAG(graph, _) = plan

  case dict.get(graph, current) {
    Ok(ToolNode(_, deps, _, _)) -> deps
    Error(_) -> []
  }
}

pub fn static_workflow_to_json(workflow: StaticWorkflow) -> st.StringTree {
  let StaticWorkflow(name, path) = workflow
  json_object([
    json_field("name", json_string_value(name)),
    json_field("path", json_array(path |> list.map(tool_id_to_json)))
  ])
}

pub fn workflow_dag_to_json(plan: WorkflowDAG) -> st.StringTree {
  let WorkflowDAG(graph, paths) = plan

  json_object([
    json_field("graph",
      json_array(
        graph
        |> dict.to_list
        |> list.map(fn(pair) {
          let #(_, node) = pair
          tool_node_to_json(node)
        })
      )
    ),
    json_field("paths",
      json_array(
        paths
        |> list.map(static_workflow_to_json)
      )
    )
  ])
}

// JSON helpers from earlier remain unchanged

fn escape_string(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

fn json_string_value(s: String) -> st.StringTree {
  st.from_string("\"" <> escape_string(s) <> "\"")
}

fn json_field(key: String, value: st.StringTree) -> st.StringTree {
  st.concat([
    st.from_string("\"" <> key <> "\":"),
    value
  ])
}

fn json_object(fields: List(st.StringTree)) -> st.StringTree {
  case fields {
    [] -> st.from_string("{}")
    [first] -> st.concat([
      st.from_string("{"),
      first,
      st.from_string("}")
    ])
    [first, ..rest] -> {
      let with_commas =
        rest
        |> list.map(fn(field) {
          st.concat([st.from_string(","), field])
        })

      st.concat([
        st.from_string("{"),
        st.concat([first, ..with_commas]),
        st.from_string("}")
      ])
    }
  }
}

fn json_array(items: List(st.StringTree)) -> st.StringTree {
  case items {
    [] -> st.from_string("[]")
    [first] -> st.concat([
      st.from_string("["),
      first,
      st.from_string("]")
    ])
    [first, ..rest] -> {
      let with_commas =
        rest
        |> list.map(fn(item) {
          st.concat([st.from_string(","), item])
        })

      st.concat([
        st.from_string("["),
        st.concat([first, ..with_commas]),
        st.from_string("]")
      ])
    }
  }
}

pub fn tool_id_to_json(id: ToolId) -> st.StringTree {
  let ToolId(agent, tool) = id

  json_object([
    json_field("agent_id", json_string_value(agent)),
    json_field("tool_name", json_string_value(tool))
  ])
}

pub fn tool_node_to_json(node: ToolNode) -> st.StringTree {
  let ToolNode(id, deps, input, output) = node

  json_object([
    json_field("id", tool_id_to_json(id)),
    json_field("dependencies",
      json_array(deps |> list.map(tool_id_to_json))
    ),
    json_field("input", json_string_value(input)),
    json_field("output", json_string_value(output))
  ])
}

pub fn workflow_dag_to_string(plan: WorkflowDAG) -> String {
  workflow_dag_to_json(plan)
  |> st.to_string
}

