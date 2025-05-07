import asyncio
from beamtracks_sdk.agent import Agent, ping

class TestAgent(Agent):
    @ping
    async def heartbeat(self):
        print("Heartbeat sent!")

async def main():
    a = TestAgent(agent_id="test-123", base_url="http://localhost:4000/api")
    await a.heartbeat()

if __name__ == "__main__":
    asyncio.run(main())
