from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass

import httpx

from ..domain import APP_IDS, Game


_PRICE_RE = re.compile(r"[-+]?\d[\d\s\u00a0.,]*")


def parse_rub_price(value: str | None) -> int | None:
    if not value:
        return None
    match = _PRICE_RE.search(value)
    if not match:
        return None
    raw = match.group(0).replace("\u00a0", " ").replace(" ", "")
    if raw.count(",") == 1 and len(raw.rsplit(",", 1)[1]) <= 2:
        raw = raw.replace(".", "").replace(",", ".")
    else:
        raw = raw.replace(",", "")
    try:
        return max(0, int(round(float(raw))))
    except ValueError:
        return None


@dataclass(slots=True)
class PriceQuote:
    value_rub: int | None
    source: str = "steam_market"


class SteamMarketClient:
    def __init__(self, timeout: float = 10.0, concurrency: int = 3) -> None:
        self.client = httpx.AsyncClient(
            timeout=timeout,
            follow_redirects=True,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) BeaverSearch/0.1"},
        )
        self._sem = asyncio.Semaphore(concurrency)

    async def close(self) -> None:
        await self.client.aclose()

    async def quote(self, game: Game, market_hash_name: str) -> PriceQuote:
        async with self._sem:
            response = await self.client.get(
                "https://steamcommunity.com/market/priceoverview/",
                params={
                    "country": "RU",
                    "currency": "5",
                    "appid": str(APP_IDS[game]),
                    "market_hash_name": market_hash_name,
                },
            )
            if response.status_code == 429:
                raise RuntimeError("Steam Market rate limit (429)")
            response.raise_for_status()
            data = response.json()
            if not data.get("success"):
                return PriceQuote(None)
            return PriceQuote(parse_rub_price(data.get("lowest_price") or data.get("median_price")))
