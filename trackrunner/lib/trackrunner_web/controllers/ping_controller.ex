defmodule TTrackrunnerWeb.PingController do
  use TrackrunnerWeb, :controller

  require Logger

  alias Trackrunner.Tool.Contract, as: ToolContract
  alias Trackrunner.WebsocketContract

  def ping(conn, params) do
    Logger.debug("PING PARAMS: #{inspect(params)}")

    result =
      Trackrunner.Registry.register_node(params["agent_id"], %{
        ip: params["ip_hint"],
        public_tools: parse_tools(Map.get(params, "public_tools", [])),
        private_tools: parse_tools(Map.get(params, "private_tools", [])),
        tool_dependencies: Map.get(params, "tool_dependencies", %{}),
        agent_channels: parse_channels(Map.get(params, "agent_channels", []))
      })

    Logger.debug("REGISER RESULT: #{inspect(result)}")

    case result do
      {:ok, %{uid: uid}} ->
        json(conn, %{status: "ok", uid: uid, message: "Node registered"})

      {:error, reason} ->
        Logger.error("Registry error: #{inspect(reason)}")
        json(conn, %{error: inspect(reason)})
    end
  rescue
    err ->
      Logger.error("🔥 CRASH in ping: #{inspect(err)}")
      json(conn, %{error: Exception.message(err)})
  end

  defp parse_tools([]), do: %{}

  defp parse_tools(tool_list) when is_list(tool_list) do
    Enum.reduce(tool_list, %{}, fn tool, acc ->
      name = tool["name"] || tool[:name]
      type = tool["type"] || tool[:type] || "MOCK"
      target = tool["target"] || tool[:target] || ""
      inputs = tool["input"] || tool[:input] || %{}
      outputs = tool["output"] || tool[:output] || %{}

      {mode, verb} = parse_mode(type)

      contract = %ToolContract{
        name: name,
        mode: mode,
        target: target,
        inputs: inputs,
        outputs: outputs,
        verb: verb
      }

      Map.put(acc, name, contract)
    end)
  end

  defp parse_channels(list) when is_list(list) do
    Enum.map(list, fn %{
                        "category" => cat,
                        "identity" => id,
                        "subscription" => subs,
                        "publish" => pubs
                      } ->
      %WebsocketContract{
        category: cat,
        identity: id,
        subscriptions: subs,
        publishes: pubs
      }
    end)
  end

  defp parse_mode("HTP:GET"), do: {:http, :get}
  defp parse_mode("HTP:POST"), do: {:http, :post}
  defp parse_mode("HTP:PUT"), do: {:http, :put}
  defp parse_mode("HTP:DELETE"), do: {:http, :delete}
  defp parse_mode("MOCK"), do: {:mock, nil}
  defp parse_mode("FUNCION"), do: {:function, nil}
  defp parse_mode("SCRIP"), do: {:script, nil}
  defp parse_mode("FLAME"), do: {:flame, nil}
  defp parse_mode(_), do: {:mock, nil}
end
