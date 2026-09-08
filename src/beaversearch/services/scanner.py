from __future__ import annotations

import asyncio
from datetime import datetime, timezone

from ..domain import Game, InventoryValue, ResolveConfidence, SearchFilters, SearchResult, ServerTarget
from ..storage.database import Database
from .a2s_client import A2SClient, A2SScan
from .inventory import InventorySnapshot, SteamInventoryClient
from .market import SteamMarketClient
from .resolver import SteamIdResolver


class PlayerScanner:
    def __init__(
        self,
        db: Database,
        a2s: A2SClient,
        resolver: SteamIdResolver,
        inventories: SteamInventoryClient,
        market: SteamMarketClient,
        filters: SearchFilters,
        recheck_hours: int = 24,
        concurrency: int = 5,
        price_cache_minutes: int = 30,
    ) -> None:
        self.db = db
        self.a2s = a2s
        self.resolver = resolver
        self.inventories = inventories
        self.market = market
        self.filters = filters
        self.recheck_hours = recheck_hours
        self.price_cache_minutes = max(1, price_cache_minutes)
        self.sem = asyncio.Semaphore(max(1, concurrency))

    async def scan_server(self, target: ServerTarget, timeout: float = 10.0) -> tuple[A2SScan, list[SearchResult]]:
        scan = await self.a2s.scan(target, timeout)
        if not scan.snapshot.online or not scan.players:
            return scan, []

        nicknames = list(dict.fromkeys(p.nickname for p in scan.players if p.nickname.strip()))
        tasks = []
        for nickname in nicknames:
            if await self.db.was_checked_recently(target.address, nickname, self.recheck_hours):
                continue
            tasks.append(asyncio.create_task(self._scan_player(target, scan, nickname)))

        if not tasks:
            return scan, []
        rows = await asyncio.gather(*tasks, return_exceptions=True)
        results = [row for row in rows if isinstance(row, SearchResult)]
        return scan, results

    async def _scan_player(self, target: ServerTarget, scan: A2SScan, nickname: str) -> SearchResult | None:
        async with self.sem:
            try:
                resolved = await self.resolver.resolve(nickname, target)
            except Exception:
                await self.db.mark_checked(target.address, nickname, None, "resolver_error")
                return None

            if not resolved.steam_id64 or resolved.confidence not in {ResolveConfidence.EXACT, ResolveConfidence.HIGH}:
                await self.db.mark_checked(target.address, nickname, resolved.steam_id64, resolved.confidence.value)
                return None

            values = await self.db.get_recent_inventory_values(resolved.steam_id64, self.recheck_hours)
            if values is None:
                values = await self._fetch_values(resolved.steam_id64)
                await self.db.save_inventory_values(resolved.steam_id64, nickname, values)

            matched = tuple(g for g in Game if self.filters.for_game(g).matches(values[g].value_rub))
            await self.db.mark_checked(target.address, nickname, resolved.steam_id64, "matched" if matched else "no_match")
            if not matched:
                return None

            now = datetime.now(timezone.utc)
            result = SearchResult(
                nickname=nickname,
                steam_id64=resolved.steam_id64,
                profile_url=resolved.profile_url or f"https://steamcommunity.com/profiles/{resolved.steam_id64}",
                server_address=target.address,
                server_name=scan.snapshot.name or target.name,
                map_name=scan.snapshot.map_name,
                cs2_rub=values[Game.CS2].value_rub,
                dota2_rub=values[Game.DOTA2].value_rub,
                rust_rub=values[Game.RUST].value_rub,
                matched_games=matched,
                first_seen_at=now,
                last_seen_at=now,
            )
            await self.db.save_result(result)
            return result

    async def _fetch_values(self, steam_id64: str) -> dict[Game, InventoryValue]:
        snapshots = await asyncio.gather(
            *(self.inventories.fetch(steam_id64, game) for game in Game),
            return_exceptions=True,
        )
        values: dict[Game, InventoryValue] = {}
        for game, snapshot in zip(Game, snapshots):
            if isinstance(snapshot, Exception):
                values[game] = InventoryValue(game, None, 0, "error")
                continue
            values[game] = await self._value_inventory(snapshot)
        return values

    async def _value_inventory(self, inv: InventorySnapshot) -> InventoryValue:
        game = inv.game
        if not inv.accessible:
            return InventoryValue(game, None, inv.raw_item_count, inv.status)
        if not inv.items:
            return InventoryValue(game, None, 0, "empty_or_no_marketable")

        names = [item.market_hash_name for item in inv.items]
        prices = await self.db.get_cached_prices(game, names, self.price_cache_minutes)
        missing = [name for name in dict.fromkeys(names) if name not in prices]

        async def quote_one(name: str) -> tuple[str, int | None]:
            try:
                quote = await self.market.quote(game, name)
                return name, quote.value_rub
            except Exception:
                return name, None

        if missing:
            quoted = await asyncio.gather(*(quote_one(name) for name in missing))
            fresh = dict(quoted)
            prices.update(fresh)
            await self.db.set_cached_prices(game, fresh)

        total = 0
        priced_count = 0
        for item in inv.items:
            unit = prices.get(item.market_hash_name)
            if unit is None or unit <= 0:
                continue
            total += unit * item.amount
            priced_count += item.amount

        if priced_count <= 0:
            return InventoryValue(game, None, 0, "no_prices")
        status = "ok" if priced_count == sum(item.amount for item in inv.items) else "partial"
        return InventoryValue(game, total, priced_count, status)
