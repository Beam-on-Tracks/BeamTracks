defmodule Beamtracks.CLI do
  alias Beamtracks.CLI.Parser
  alias Beamtracks.CLI.PingTracker

  def main(argv) do
    optimus = Parser.build()

    case Optimus.parse(optimus, argv) do
      {:ok, %{command: ["watch", "agents"]}, _} -> watch_agents()
      _ -> IO.puts(Optimus.help(optimus))
    end
  end

  defp watch_agents do
    # 1) start our ping tracker Agent
    {:ok, _pid} = PingTracker.start_link([])

    # 2) connect to the Trackrunner WS endpoint
    url = System.get_env("BEAMTRACKS_WS_URL") || "ws://localhost:4000/socket/websocket"
    {:ok, socket} = Socket.start_link(url, transport: :websocket)
    Socket.connect!(socket)

    # 3) subscribe to the “cli:ping” topic
    {:ok, chan} = Channel.join(socket, "cli:ping")

    IO.puts("👀 Watching agent pings (last 5s) on #{url}\n")

    # 4) on each ping event, record it
    Channel.on(chan, "agent:ping", fn payload ->
      PingTracker.record_ping(payload["agent_id"])
    end)

    # 5) loop to refresh and redraw the screen
    loop_draw()
  end

  defp loop_draw do
    # clear terminal
    IO.write("\e[H\e[2J")

    # fetch only fresh pings
    entries = PingTracker.get_active()

    IO.puts("👀 Active pings (last 5s):\n")

    for {id, ts} <- entries do
      IO.puts("▶ #{id} at #{DateTime.to_iso8601(ts)}")
    end

    # wait, then redraw
    :timer.sleep(2_000)
    loop_draw()
  end
end
