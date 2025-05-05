// src/pulsekeeper.gleam
import gleam/io
import tool_graph

pub fn main() {
  let _graph = tool_graph.new()
  io.println("Graph initialized")
}
