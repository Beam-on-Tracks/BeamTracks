defmodule Trackrunner.Planner.WorkflowCache do
  @moduledoc """
  Unified view over two Cachex stores:
  - **Static** entries live forever in `:workflow_cache`.
  - **Dynamic** entries live in `:dynamic_workflow` with 30 min TTL.
  """
  @static :workflow_cache
  @dynamic :dynamic_workflow

  @doc """
  Lookup a workflow's steps:
    1. If `:workflow_cache` has `%{"path" => steps}`, return that.
    2. Else if `:dynamic_workflow` has a list, return that.
    3. Otherwise call `lookup_fun.(id, dag)`.  If it returns `{:ok, steps}`,
       store in `:dynamic_workflow` (with TTL) and return it.
  """
  @spec get_workflow(
          String.t(),
          map(),
          (String.t(), map() -> {:ok, list()} | {:error, term()})
        ) :: {:ok, list()} | {:error, term()}
  def get_workflow(id, dag, lookup_fun) do
    case Cachex.get(@static, id) do
      {:ok, %{"path" => steps}} ->
        {:ok, steps}

      _ ->
        case Cachex.get(@dynamic, id) do
          {:ok, steps} when is_list(steps) ->
            {:ok, steps}

          _ ->
            case lookup_fun.(id, dag) do
              {:ok, steps} = ok when is_list(steps) ->
                # TTL is automatic
                Cachex.put(@dynamic, id, steps)
                ok

              error ->
                error
            end
        end
    end
  end

  @doc """
  Reset static workflows cache with the provided workflows list.
  Used primarily for testing.
  """
  @spec reset_static_workflows(list()) :: :ok
  def reset_static_workflows(workflows) do
    # Clear existing cache
    Cachex.clear(@static)

    # Insert each workflow into the static cache
    Enum.each(workflows, fn %{
                              name: name,
                              path: path,
                              source_input: source,
                              target_output: _target
                            } ->
      Cachex.put(@static, name, %{"path" => path, "source_input" => source})
    end)

    :ok
  end
end
