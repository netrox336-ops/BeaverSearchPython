from __future__ import annotations

from dataclasses import dataclass

import httpx


@dataclass(slots=True)
class PlayerSummary:
    steam_id64: str
    personaname: str
    profile_url: str
    avatar_url: str | None
    game_id: str | None
    game_server_ip: str | None


class SteamWebApiClient:
    def __init__(self, api_key: str, timeout: float = 10.0) -> None:
        self.api_key = api_key.strip()
        self.client = httpx.AsyncClient(timeout=timeout, follow_redirects=True)

    async def close(self) -> None:
        await self.client.aclose()

    async def summaries(self, steam_ids: list[str]) -> list[PlayerSummary]:
        if not self.api_key or not steam_ids:
            return []
        out: list[PlayerSummary] = []
        for start in range(0, len(steam_ids), 100):
            chunk = steam_ids[start:start + 100]
            response = await self.client.get(
                "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/",
                params={"key": self.api_key, "steamids": ",".join(chunk)},
            )
            response.raise_for_status()
            for p in response.json().get("response", {}).get("players", []):
                out.append(
                    PlayerSummary(
                        steam_id64=str(p.get("steamid", "")),
                        personaname=str(p.get("personaname", "")),
                        profile_url=str(p.get("profileurl", "")),
                        avatar_url=p.get("avatarfull") or p.get("avatarmedium"),
                        game_id=str(p.get("gameid")) if p.get("gameid") is not None else None,
                        game_server_ip=p.get("gameserverip"),
                    )
                )
        return out
