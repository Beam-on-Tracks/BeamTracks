defmodule Trackrunner.ToolValidator do
  @moduledoc """
  Validates tool input against the contract's input schema using simple type checks.
  """

  alias Trackrunner.ToolContract

  @spec validate_input(ToolContract.t(), map()) :: :ok | {:error, any()}
  def validate_input(%ToolContract{inputs: schema}, data) when is_map(schema) do
    errors =
      Enum.reduce(schema, [], fn {key_str, type_str}, acc ->
        key_atom = String.to_existing_atom(key_str)

        cond do
          Map.has_key?(data, key_atom) ->
            val = Map.get(data, key_atom)

            if valid_type?(val, type_str),
              do: acc,
              else: [{:type_mismatch, key_atom, type_str, val} | acc]

          Map.has_key?(data, key_str) ->
            val = Map.get(data, key_str)

            if valid_type?(val, type_str),
              do: acc,
              else: [{:type_mismatch, key_atom, type_str, val} | acc]

          true ->
            [{:missing_key, key_atom} | acc]
        end
      end)

    case errors do
      [] ->
        :ok

      errs ->
        {:error, errs}
    end
  end

  defp valid_type?(val, "string"), do: is_binary(val)
  defp valid_type?(val, "number"), do: is_number(val)
  defp valid_type?(val, "integer"), do: is_integer(val)
  defp valid_type?(val, "boolean"), do: is_boolean(val)
  defp valid_type?(_val, "any"), do: true
  defp valid_type?(_val, _), do: true
end

