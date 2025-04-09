Mix.install([
  {:req, "~> 0.4.0"}
])

ping_payload = %{
  "agent_id" => "agentzero",
  "public_tools" => %{
    "voice" => "http://localhost:5001/voice"
  },
  "private_tools" => %{},
  "ip_hint" => "192.168.1.100"
}

url = "http://localhost:4000/api/ping"

case Req.post(url, json: ping_payload) do
  {:ok, %{status: 200, body: body}} ->
    IO.puts("✅ Success: Node registered")
    IO.inspect(body)

  {:ok, %{status: code, body: body}} ->
    IO.puts("⚠️ Unexpected status #{code}")
    IO.inspect(body)

  {:error, err} ->
    IO.puts("❌ HTTP error:")
    IO.inspect(err)
end
