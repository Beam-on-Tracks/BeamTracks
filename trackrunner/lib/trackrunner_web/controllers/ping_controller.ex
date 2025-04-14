defmodule TrackrunnerWeb.PingController do
  use TrackrunnerWeb, :controller

  require Logger

  def ping(conn, params) do
    Logger.debug("PING PARAMS: #{inspect(params)}")

    result =
      Trackrunner.Registry.register_node(params["agent_id"], %{
        ip: params["ip_hint"],
        public_tools: Map.get(params, "public_tools", %{}),
        private_tools: Map.get(params, "private_tools", %{}),
        tool_dependencies: Map.get(params, "tool_dependencies", %{})
      })

    Logger.debug("REGISTER RESULT: #{inspect(result)}")

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
end
