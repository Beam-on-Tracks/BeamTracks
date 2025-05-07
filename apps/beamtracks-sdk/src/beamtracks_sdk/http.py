import httpx

class AsyncHTTPClient:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self._client = httpx.AsyncClient()

    async def post(self, path: str, json: dict):
        url = f"{self.base_url}/{path.lstrip('/')}"
        resp = await self._client.post(url, json=json)
        resp.raise_for_status()
        return resp.json()

