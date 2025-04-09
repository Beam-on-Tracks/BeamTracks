describe "GET /tool/public/:agent_id/:name" do
  test "returns tool URL for existing tool" do
    # Pre-register an AgentNode for "agentzero" with tool "voice"
    # (either via mock or calling Registry directly)

    conn =
      get(build_conn(), "/api/tool/public/agentzero/voice")
      |> json_response(200)

    assert conn["tool_url"] == "http://localhost:5001/voice"
  end
end
