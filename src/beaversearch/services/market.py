from __future__ import annotations

import asyncio
import re
import time
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
    def __init__(
        self,
        timeout: float = 10.0,
        concurrency: int = 2,
        min_interval_seconds: float = 0.35,
    ) -> None:
        self.client = httpx.AsyncClient(
            timeout=timeout,
            follow_redirects=True,
            http2=True,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) BeaverSearch/0.2"},
        )
        self._sem = asyncio.Semaphore(max(1, concurrency))
        self._pace_lock = asyncio.Lock()
        self._last_request = 0.0
        self._min_interval = max(0.0, min_interval_seconds)

    async def close(self) -> None:
        await self.client.aclose()

    async def _pace(self) -> None:
        async with self._pace_lock:
            now = time.monotonic()
            wait = self._min_interval - (now - self._last_request)
            if wait > 0:
                await asyncio.sleep(wait)
            self._last_request = time.monotonic()

    async def quote(self, game: Game, market_hash_name: str) -> PriceQuote:
        async with self._sem:
            last_error: Exception | None = None
            for attempt in range(4):
                await self._pace()
                try:
                    response = await self.client.get(
                        "https://steamcommunity.com/market/priceoverview/",
                        params={
                            "country": "RU",
                            "currency": "5",
                            "appid": str(APP_IDS[game]),
                            "market_hash_name": market_hash_name,
                        },
                    )
                    if response.status_code == 429 or response.status_code >= 500:
                        delay = min(20.0, float(response.headers.get("Retry-After", 0) or 0) or (1.0 * (2**attempt)))
                        await asyncio.sleep(delay)
                        continue
                    response.raise_for_status()
                    data = response.json()
                    if not data.get("success"):
                        return PriceQuote(None)
                    return PriceQuote(parse_rub_price(data.get("lowest_price") or data.get("median_price")))
                except (httpx.HTTPError, ValueError) as exc:
                    last_error = exc
                    if attempt < 3:
                        await asyncio.sleep(0.7 * (2**attempt))
            raise RuntimeError(f"Steam Market request failed: {last_error}")
