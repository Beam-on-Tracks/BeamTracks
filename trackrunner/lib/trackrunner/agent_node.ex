defmodule Trackrunner.AgentNode do
  @moduledoc """
  Represents a live instance (node) of an agent in the BeamTracks system.
  Holds tool metadata and responds to tool discovery queries.
  """

  use GenServer

  alias Trackrunner.RelayContext
  alias Trackrunner.ToolContract
  # --- Public API ---

  def start_link({uid, data, caller}) do
    name = {:via, Registry, {:agent_node_registry, {data.agent_id, tool_id}}}
    GenServer.start_link(__MODULE__, {uid, data, caller}, name: name)
  end

  def init({_uid, data, caller}) do
    # Send notification back to parent (AgentFleet or caller)
    send(caller, {:agent_node_ready, self()})
    {:ok, data}
  end

  def via(uid),
    do: {:via, Registry, {:agent_node_registry, uid}}

  def lookup_public_tool(node_pid_or_name, tool_name) do
    GenServer.call(node_pid_or_name, {:lookup_public, tool_name})
  end

  def lookup_private_tool(pid, tool_name) do
    GenServer.call(pid, {:lookup_private, tool_name})
  end

  def update_last_seen(node_pid_or_name) do
    GenServer.cast(node_pid_or_name, :update_last_seen)
  end

  defp do_execute_tool(%ToolContract{mode: {:http, verb}, target: url}, tool_node, context) do
    Task.start(fn ->
      headers = [{"Content-Type", "application/json"}]
      body = Jason.encode!(tool_node.input)

      case HTTPoison.request(to_string(verb), url, body, headers, []) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          RelayContext.broadcast(context, {:executed_tool, tool_node.id, Jason.decode!(body)})

        {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
          RelayContext.broadcast(
            context,
            {:tool_error, tool_node.id, %{status: code, body: body}}
          )

        {:error, err} ->
          RelayContext.broadcast(context, {:tool_error, tool_node.id, %{error: inspect(err)}})
      end
    end)
  end

  defp do_execute_tool(%ToolContract{mode: {:mock, _}}, tool_node, context) do
    RelayContext.broadcast(context, {:executed_tool, tool_node.id, %{"mock" => "response"}})
  end

  defp do_execute_tool(_, tool_node, context) do
    RelayContext.broadcast(context, {:tool_error, tool_node.id, "Unsupported tool mode"})
  end

  # --- GenServer Callbacks ---

  def init(state), do: {:ok, state}

  def handle_call({:lookup_public, name}, _from, state) do
    case Map.get(state.public_tools, name) do
      nil -> {:reply, :not_found, state}
      %ToolContract{target: url} -> {:reply, {:ok, url}, state}
    end
  end

  def handle_cast(:update_last_seen, state) do
    {:noreply, %{state | last_seen: DateTime.utc_now()}}
  end

  def handle_call({:lookup_private, name}, _from, state) do
    case Map.get(state.private_tools, name) do
      nil -> {:reply, :not_found, state}
      %ToolContract{target: url} -> {:reply, {:ok, url}, state}
    end
  end

  def update_last_seen(pid) do
    GenServer.cast(pid, :update_last_seen)
  end

  def handle_cast(:update_last_seen, state) do
    {:noreply, %{state | last_seen: DateTime.utc_now()}}
  end

  def handle_cast({:execute_tool, tool_node, %RelayContext{} = context}, state) do
    IO.puts("🛠️ AgentNode received #{tool_node.id} for execution")

    contract =
      Map.get(state.public_tools, tool_node.id) ||
        Map.get(state.private_tools, tool_node.id)

    case contract do
      %ToolContract{} ->
        case ToolValidator.validate_input(contract, tool_node.input) do
          :ok ->
            do_execute_tool(contract, tool_node, context)

          {:error, reason} ->
            IO.puts("❌ Input validation failed: #{inspect(reason)}")

            RelayContext.broadcast(
              context,
              {:tool_error, tool_node.id, %{error: "invalid_input", details: reason}}
            )
        end

      _ ->
        RelayContext.broadcast(context, {:tool_error, tool_node.id, "Tool not found"})
    end

    {:noreply, state}
  end
end
