# lib/trackrunner/planner/executor.ex
defmodule Trackrunner.Planner.Executor do
  @moduledoc """
  Executor walks a workflow path step-by-step, using `tool_runtime` to invoke each tool.
  Retries each tool up to 4 times with exponential backoff (base 100ms).
  Provides both `run/1` and `execute/2` APIs:
    - `run/1` uses `nil` as the initial input.
    - `execute/2` accepts an explicit initial input.
  Returns `{:ok, final_output}` or `{:error, {:node_failed, node_name, reason}}`.
  """
  alias Trackrunner.Channel.WarmPool
  alias Trackrunner.Planner.DAGRegistry
  @tool_runtime Application.compile_env(:trackrunner, :tool_runtime, Trackrunner.Runtime.Tool)
  require Logger
  @max_attempts 4
  @base_backoff 100
  @dynamic_ttl :timer.minutes(30)

  @doc "Run workflow by ID with no initial input (uses node args or dynamic inputs)."
  @spec run(String.t()) :: {:ok, any()} | {:error, term()}
  def run(workflow_id) when is_binary(workflow_id) do
    execute(workflow_id, nil)
  end

  @doc "Run workflow by ID with a given initial input."
  @spec execute(String.t(), any()) :: {:ok, any()} | {:error, term()}
  def execute(workflow_id, input) when is_binary(workflow_id) do
    case DAGRegistry.get_active_dag() do
      nil ->
        {:error, :no_workflow_dag}

      dag ->
        steps_result =
          case Cachex.get(:workflow_cache, workflow_id) do
            {:ok, %{"path" => tool_steps}} ->
              {:ok, tool_steps}

            # For testing, we want to proceed even if there's a cache error
            {:error, :no_cache} ->
              # For this specific error, try to continue with DAG lookup instead of failing
              lookup_workflow(workflow_id, dag)

            # Handle dynamic workflows
            {:ok, nil} ->
              lookup_workflow(workflow_id, dag)

            # Other Cachex errors
            {:error, reason} ->
              {:error, {:cache_error, reason}}

            _ ->
              lookup_workflow(workflow_id, dag)
          end

        case steps_result do
          {:ok, tool_steps} -> run_steps(tool_steps, input)
          # Already a proper error tuple
          {:error, _} = error -> error
          # Catch any unexpected bare atoms
          :error -> {:error, :unknown_workflow_error}
          # Catch any other unexpected value
          other -> {:error, {:unexpected_result, other}}
        end
    end
  end

  defp lookup_workflow(workflow_id, %{paths: paths}) do
    # find the right static entry
    case Enum.find(paths, &(&1.name == workflow_id)) do
      nil ->
        {:error, :workflow_not_found}

      %{path: path_list, source_input: source, target_output: _} ->
        # turn each {agent, tool} tuple into a step‐map,
        # and wire in the static source_input as the first node's args["input"]
        steps =
          path_list
          |> Enum.map(fn {agent, tool} ->
            %{agent: agent, tool: tool, name: to_string(tool), args: %{"input" => nil}}
          end)
          |> case do
            [first | rest] ->
              [%{first | args: %{"input" => source}} | rest]

            other ->
              other
          end

        {:ok, steps}
    end
  end

  defp lookup_workflow(_workflow_id, %{nodes: nodes}) do
    # Normalize ANY node shape into the same step‐map
    steps =
      Enum.map(nodes, fn node ->
        {agent, tool} =
          case node do
            %{tool_id: tool_id} -> tool_id
            %{agent: agent, name: name} -> {agent, name}
            # If there's a specific format where agent is under a different key
            %{agent: agent} -> {agent, Map.get(node, :tool, "default_tool")}
          end

        # to_string/1 handles both atoms and strings
        name = Map.get(node, :name, to_string(tool))
        args = Map.get(node, :args, %{})
        %{agent: agent, tool: tool, name: name, args: args}
      end)

    {:ok, steps}
  end

  # catch-all if neither shape matched
  defp lookup_workflow(_workflow_id, _), do: {:error, :workflow_not_found}

  # Execute steps sequentially
  defp run_steps([], last_output), do: {:ok, last_output}

  @spec run_steps([%{agent: any, tool: any, name: String.t(), args: map}], any) ::
          {:ok, [%{node: String.t(), result: any}]} | {:error, term}
  defp run_steps(steps, initial_input) when is_list(steps) and is_map(hd(steps)) do
    # Add try/catch
    try do
      result =
        steps
        |> Enum.reduce_while({[], initial_input}, fn %{
                                                       agent: agent,
                                                       tool: tool,
                                                       name: name,
                                                       args: args
                                                     },
                                                     {acc, last} ->
          input =
            case Map.get(args, "input") do
              nil -> last
              val -> val
            end

          case execute_tool(agent, tool, input, @max_attempts, @base_backoff) do
            {:ok, out} ->
              {:cont, {[%{node: name, result: out} | acc], out}}

            {:error, reason, _node_name} ->
              {:halt, {:error, {:node_failed, name, reason}}}
          end
        end)

      # Handle result separately with comprehensive pattern matching
      case result do
        {list, _} when is_list(list) -> {:ok, Enum.reverse(list)}
        {:error, _} = error -> error
        :error -> {:error, :unknown_error}
        error -> {:error, error}
      end
    catch
      # Catch any exceptions and convert to error tuples
      kind, value -> {:error, {kind, value}}
    end
  end

  # Handle tuple format with three elements
  defp run_steps([{agent_id, tool_name, args_map} | rest], last_output) do
    # pick either the node's own input or the previous output
    input =
      case Map.get(args_map, "input") do
        nil -> last_output
        val -> val
      end

    case execute_tool(agent_id, tool_name, input, @max_attempts, @base_backoff) do
      {:ok, result} -> run_steps(rest, result)
      {:error, reason, node_name} -> {:error, {:node_failed, node_name, reason}}
    end
  end

  # Add a new clause to handle tuple format with two elements
  defp run_steps([{agent_id, tool_name} | rest], input) when is_map(input) do
    case execute_tool(agent_id, tool_name, input, @max_attempts, @base_backoff) do
      {:ok, result} -> run_steps(rest, result)
      {:error, reason, node_name} -> {:error, {:node_failed, node_name, reason}}
    end
  end

  # Execute a single tool with retries and exponential backoff
  defp execute_tool(agent_id, tool_name, input, attempts, backoff) when attempts > 1 do
    # Lookup agent endpoint (module or PID)
    agent = WarmPool.lookup_socket(agent_id)

    case invoke_agent(agent, agent_id, tool_name, input) do
      {:ok, out} ->
        {:ok, out}

      {:error, reason} ->
        Logger.warn(
          "Tool #{agent_id}/#{tool_name} failed. Retrying in #{backoff}ms. Attempts left: #{attempts - 1}} Reason: #{inspect(reason)}"
        )

        :timer.sleep(backoff)
        execute_tool(agent_id, tool_name, input, attempts - 1, backoff * 2)
    end
  end

  defp execute_tool(agent_id, tool_name, input, 1, _backoff) do
    agent = WarmPool.lookup_socket(agent_id)

    case invoke_agent(agent, agent_id, tool_name, input) do
      {:ok, out} ->
        {:ok, out}

      {:error, reason} ->
        {:error, reason, tool_name}
    end
  end

  # 1) Handle nil (no WarmPool entry) by delegating straight to tool_runtime - THIS MUST COME FIRST
  defp invoke_agent(nil, agent_id, tool_name, input) do
    call = %{"tool_id" => "#{agent_id}/#{tool_name}", "inputs" => input}

    case @tool_runtime.run(call) do
      {:ok, _} = ok -> ok
      {:error, _} = error -> error
      :error -> {:error, :unknown_tool_error}
      other -> {:error, {:unexpected_result, other}}
    end
  end

  # 2) When WarmPool gives a PID (real socket-based agent), use tool_runtime  
  defp invoke_agent(pid, agent_id, tool_name, input) when is_pid(pid) do
    call = %{"tool_id" => "#{agent_id}/#{tool_name}", "inputs" => input}

    case @tool_runtime.run(call) do
      {:ok, _} = ok -> ok
      {:error, _} = error -> error
      :error -> {:error, :unknown_tool_error}
      other -> {:error, {:unexpected_result, other}}
    end
  end

  # 3) When WarmPool gives an atom module (test-registered agents), call it directly
  defp invoke_agent(module, _agent_id, _tool_name, input) when is_atom(module) do
    case module.call(%{"input" => input}) do
      {:ok, out} -> {:ok, out}
      {:error, reason} -> {:error, reason}
      :error -> {:error, :unknown_module_error}
      other -> {:error, {:unexpected_result, other}}
    end
  end
end
