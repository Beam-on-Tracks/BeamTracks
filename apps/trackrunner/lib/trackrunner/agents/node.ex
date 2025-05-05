defmodule Trackrunner.AgentNode do
  @moduledoc """
  Represents a live instance of an agent.  
  Handles tool discovery, validation, and execution.
  """

  use GenServer

  alias Trackrunner.{WorkflowRuntime, RelayContext}
  alias Trackrunner.Tool.{Contract, Validator}

  @type tool_id :: String.t()
  @type uid :: integer()

  @type state :: %{
          uid: uid(),
          agent_id: String.t(),
          public_tools: %{tool_id() => Contract.t()},
          private_tools: %{tool_id() => Contract.t()},
          last_seen: DateTime.t()
        }

  ## Public API

  @spec start_link({uid(), %{agent_id: String.t(), public_tools: map(), private_tools: map()}}) ::
          GenServer.on_start()
  def start_link({uid, %{agent_id: agent_id, public_tools: pub, private_tools: priv}}) do
    [first_tool | _] = Map.keys(pub)
    name = {:via, Registry, {:agent_node_registry, {agent_id, first_tool}}}

    initial_state = %{
      uid: uid,
      agent_id: agent_id,
      public_tools: pub,
      private_tools: priv,
      last_seen: DateTime.utc_now()
    }

    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  @spec lookup_public_tool(pid() | atom(), tool_id()) ::
          {:ok, String.t()} | {:error, :not_found}
  def lookup_public_tool(node, name), do: GenServer.call(node, {:lookup_public, name})

  @spec lookup_private_tool(pid() | atom(), tool_id()) ::
          {:ok, String.t()} | {:error, :not_found}
  def lookup_private_tool(node, name), do: GenServer.call(node, {:lookup_private, name})

  @spec update_last_seen(pid() | atom()) :: :ok
  def update_last_seen(node), do: GenServer.cast(node, :update_last_seen)

  ## GenServer Callbacks

  @impl true
  def init(state) do
    # Announce availability for each public tool
    for tool_id <- Map.keys(state.public_tools) do
      WorkflowRuntime.notify_node_ready(state.agent_id, tool_id)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:lookup_public, name}, _from, state) do
    case Map.get(state.public_tools, name) do
      %Contract{target: url} ->
        {:reply, {:ok, url}, state}

      url when is_binary(url) ->
        {:reply, {:ok, url}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:lookup_private, name}, _from, state) do
    case Map.get(state.private_tools, name) do
      url when is_binary(url) ->
        {:reply, {:ok, url}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_cast(:update_last_seen, state) do
    {:noreply, %{state | last_seen: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast({:execute_tool, tool_node, %RelayContext{} = ctx}, state) do
    IO.puts("🛠️ AgentNode executing #{tool_node.id}")

    contract =
      Map.get(state.public_tools, tool_node.id) ||
        Map.get(state.private_tools, tool_node.id)

    case contract do
      %Contract{} = c ->
        case Validator.validate_input(c, tool_node.input) do
          :ok ->
            do_execute_tool(c, tool_node, ctx)

          {:error, reason} ->
            RelayContext.broadcast(ctx, {:tool_error, tool_node.id, %{invalid_input: reason}})
        end

      url when is_binary(url) ->
        # raw URL targets: echo the input back
        RelayContext.broadcast(ctx, {:executed_tool, tool_node.id, tool_node.input})

      _ ->
        RelayContext.broadcast(ctx, {:tool_error, tool_node.id, "Tool not found"})
    end

    {:noreply, state}
  end

  ## Private helpers

  defp do_execute_tool(%Contract{mode: {:http, verb}, target: url}, tool_node, ctx) do
    Task.start(fn ->
      headers = [{"Content-Type", "application/json"}]
      body = Jason.encode!(tool_node.input)

      case HTTPoison.request(to_string(verb), url, body, headers, []) do
        {:ok, %HTTPoison.Response{status_code: 200, body: resp}} ->
          RelayContext.broadcast(ctx, {:executed_tool, tool_node.id, resp})

        {:ok, %HTTPoison.Response{status_code: code, body: resp}} ->
          RelayContext.broadcast(ctx, {:tool_error, tool_node.id, %{status: code, body: resp}})

        {:error, err} ->
          RelayContext.broadcast(ctx, {:tool_error, tool_node.id, %{error: inspect(err)}})
      end
    end)
  end

  defp do_execute_tool(%Contract{mode: {:mock, _}}, tool_node, ctx) do
    RelayContext.broadcast(ctx, {:executed_tool, tool_node.id, %{"mock" => "response"}})
  end

  defp do_execute_tool(_, tool_node, ctx) do
    RelayContext.broadcast(ctx, {:tool_error, tool_node.id, "Unsupported tool mode"})
  end
end
