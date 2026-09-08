from __future__ import annotations

import asyncio
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
    game_extra_info: str | None = None


class SteamWebApiClient:
    def __init__(self, api_key: str, timeout: float = 10.0) -> None:
        self.api_key = api_key.strip()
        self.client = httpx.AsyncClient(timeout=timeout, follow_redirects=True, http2=True)

    async def close(self) -> None:
        await self.client.aclose()

    async def summaries(self, steam_ids: list[str]) -> list[PlayerSummary]:
        if not self.api_key or not steam_ids:
            return []
        out: list[PlayerSummary] = []
        unique_ids = list(dict.fromkeys(steam_ids))
        for start in range(0, len(unique_ids), 100):
            chunk = unique_ids[start:start + 100]
            last_error: Exception | None = None
            for attempt in range(3):
                try:
                    response = await self.client.get(
                        "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/",
                        params={"key": self.api_key, "steamids": ",".join(chunk)},
                    )
                    if response.status_code == 429 or response.status_code >= 500:
                        delay = min(8.0, float(response.headers.get("Retry-After", 0) or 0) or (0.7 * (2**attempt)))
                        await asyncio.sleep(delay)
                        continue
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
                                game_extra_info=p.get("gameextrainfo"),
                            )
                        )
                    last_error = None
                    break
                except (httpx.HTTPError, ValueError) as exc:
                    last_error = exc
                    if attempt < 2:
                        await asyncio.sleep(0.5 * (2**attempt))
            if last_error is not None:
                raise RuntimeError(f"Steam Web API request failed: {last_error}")
        return out
