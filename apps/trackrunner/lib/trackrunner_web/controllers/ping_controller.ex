defmodule TrackrunnerWeb.PingController do
  use TrackrunnerWeb, :controller

  require Logger

  alias Trackrunner.Tool.Contract, as: ToolContract
  alias Trackrunner.Channel.AgentChannelManager
  alias Trackrunner.Channel.WebsocketContract

  def ping(conn, params) do
    Logger.debug("PING PARAMS: #{inspect(params)}")

    agent_id = params["agent_id"]

    node_data = %{
      agent_id: agent_id,
      ip: params["ip_hint"],
      public_tools: parse_tools(Map.get(params, "public_tools", [])),
      private_tools: parse_tools(Map.get(params, "private_tools", [])),
      tool_dependencies: Map.get(params, "tool_dependencies", %{}),
      agent_channels: parse_channels(Map.get(params, "agent_channels", []))
    }

    warning_msg =
      if node_data.public_tools do
        msg = "Agent #{agent_id} pinged without any public tools"
        Logger.warn(msg)
        msg
      else
        nil
      end

    Logger.debug("REGISTER DATA: #{inspect(node_data)}")

    case Trackrunner.Registry.register_node(agent_id, node_data) do
      {:ok, %{uid: uid}} = ok ->
        # broadcast this ping out to any CLI watchers
        TrackrunnerWeb.Endpoint.broadcast!(
          "cli:ping",
          "agent:ping",
          %{
            agent_id: agent_id,
            uid: uid,
            ts: DateTime.utc_now(),
            public_tools: Map.keys(node_data.public_tools),
            private_tools: Map.keys(node_data.private_tools)
          }
        )

        AgentChannelManager.register_channels(
          agent_id,
          uid,
          node_data.agent_channels
        )

        json(conn, %{uid: uid})

      error ->
        Logger.error("Ping registration failed: #{inspect(error)}")
        send_resp(conn, 500, "Error")
    end
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

  defp parse_channels(list) do
    Enum.map(list, fn item ->
      %WebsocketContract{
        uid: nil,
        # agent_id comes later in AgentChannelManager
        category: Map.get(item, "category", Map.get(item, :category)),
        subscriptions: Map.get(item, "subscriptions", []),
        publishes: Map.get(item, "publishes", []),
        init_event: Map.get(item, "initEvents", Map.get(item, :init_event)),
        close_event: Map.get(item, "closeEvents", Map.get(item, :close_event))
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
