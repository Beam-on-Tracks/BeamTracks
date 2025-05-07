from .http import AsyncHTTPClient
import functools

def ping(fn):
    @functools.wraps(fn)
    async def wrapper(self, *args, **kwargs):
        # TODO: build and send payload to Trackrunner
        payload = {
            "agent_id": self.agent_id,
            "method": fn.__name__,
            # you’ll add tools/channels here
        }
        await self.http.post("/ping", json=payload)
        return await fn(self, *args, **kwargs)
    return wrapper

class Agent:
    def __init__(self, agent_id: str, base_url: str, tools: list[str] = None, channels: list[str] = None):
        self.agent_id = agent_id
        self.http = AsyncHTTPClient(base_url)
        self.tools = tools or []
        self.channels = channels or []
    # TODO: wiring for registry, WS, status, workflow, etc.
