from __future__ import annotations

from dataclasses import dataclass

import httpx

from ..domain import APP_IDS, Game


@dataclass(slots=True)
class MarketItem:
    market_hash_name: str
    amount: int


@dataclass(slots=True)
class InventorySnapshot:
    game: Game
    accessible: bool
    items: list[MarketItem]
    raw_item_count: int
    status: str = "ok"


class SteamInventoryClient:
    def __init__(self, timeout: float = 15.0) -> None:
        self.client = httpx.AsyncClient(
            timeout=timeout,
            follow_redirects=True,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) BeaverSearch/0.1"},
        )

    async def close(self) -> None:
        await self.client.aclose()

    async def fetch(self, steam_id64: str, game: Game) -> InventorySnapshot:
        appid = APP_IDS[game]
        start_assetid: str | None = None
        descriptions: dict[tuple[str, str], dict] = {}
        asset_amounts: dict[tuple[str, str], int] = {}
        raw_count = 0

        while True:
            params = {"l": "english", "count": "2000"}
            if start_assetid:
                params["start_assetid"] = start_assetid
            response = await self.client.get(
                f"https://steamcommunity.com/inventory/{steam_id64}/{appid}/2",
                params=params,
            )
            if response.status_code in (401, 403):
                return InventorySnapshot(game, False, [], 0, "private")
            if response.status_code == 429:
                raise RuntimeError("Steam inventory rate limit (429)")
            response.raise_for_status()
            data = response.json()
            if not data.get("success"):
                return InventorySnapshot(game, False, [], 0, "unavailable")

            for d in data.get("descriptions", []):
                descriptions[(str(d.get("classid")), str(d.get("instanceid", "0")))] = d
            for asset in data.get("assets", []):
                key = (str(asset.get("classid")), str(asset.get("instanceid", "0")))
                asset_amounts[key] = asset_amounts.get(key, 0) + int(asset.get("amount", 1) or 1)
                raw_count += int(asset.get("amount", 1) or 1)

            if not data.get("more_items"):
                break
            start_assetid = str(data.get("last_assetid", "")) or None
            if not start_assetid:
                break

        market_items: list[MarketItem] = []
        for key, amount in asset_amounts.items():
            desc = descriptions.get(key) or {}
            if not bool(desc.get("marketable")):
                continue
            name = (desc.get("market_hash_name") or "").strip()
            if name:
                market_items.append(MarketItem(name, amount))

        return InventorySnapshot(game, True, market_items, raw_count, "ok")
