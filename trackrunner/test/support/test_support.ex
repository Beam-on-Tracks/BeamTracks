defmodule Trackrunner.TestSupport do
  @moduledoc """
  Utility helpers for test setup and safe process supervision.
  """

  @doc """
  Ensures a registry with the given name is started, unless it's already running.
  Accepts optional options like `:keys`.
  """
  def ensure_registry_started(name, opts \\ [keys: :unique]) do
    case Process.whereis(name) do
      nil ->
        spec = {Registry, Keyword.put(opts, :name, name)}
        start_child_safely(spec)

      _pid ->
        :ok
    end
  end

  @doc """
  Ensures a supervisor or process with a named identifier is started.
  This works for GenServers or DynamicSupervisors as well.
  """
  def ensure_process_started(name, start_spec) do
    case Process.whereis(name) do
      nil -> start_child_safely(start_spec)
      _pid -> :ok
    end
  end

  defp start_child_safely(spec) do
    case Supervisor.start_child(Test.Supervisor, spec) do
      {:ok, _} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, _} = err -> err
    end
  end
end
