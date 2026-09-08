from __future__ import annotations

import asyncio
from datetime import datetime, timezone

from ..domain import Game, InventoryValue, ResolveConfidence, SearchFilters, SearchResult, ServerTarget
from ..storage.database import Database
from .a2s_client import A2SClient, A2SScan
from .inventory import SteamInventoryClient
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
    ) -> None:
        self.db = db
        self.a2s = a2s
        self.resolver = resolver
        self.inventories = inventories
        self.market = market
        self.filters = filters
        self.recheck_hours = recheck_hours
        self.sem = asyncio.Semaphore(concurrency)
        self.price_cache: dict[tuple[Game, str], int | None] = {}

    async def scan_server(self, target: ServerTarget, timeout: float = 10.0) -> tuple[A2SScan, list[SearchResult]]:
        scan = await self.a2s.scan(target, timeout)
        if not scan.snapshot.online:
            return scan, []
        tasks = []
        for player in scan.players:
            if await self.db.was_checked_recently(target.address, player.nickname, self.recheck_hours):
                continue
            tasks.append(asyncio.create_task(self._scan_player(target, scan, player.nickname)))
        results = [r for r in await asyncio.gather(*tasks, return_exceptions=False) if r]
        return scan, results

    async def _scan_player(self, target: ServerTarget, scan: A2SScan, nickname: str) -> SearchResult | None:
        async with self.sem:
            resolved = await self.resolver.resolve(nickname, target)
            if not resolved.steam_id64 or resolved.confidence not in {ResolveConfidence.EXACT, ResolveConfidence.HIGH}:
                await self.db.mark_checked(target.address, nickname, resolved.steam_id64, resolved.confidence.value)
                return None

            values: dict[Game, InventoryValue] = {}
            for game in Game:
                try:
                    inv = await self.inventories.fetch(resolved.steam_id64, game)
                    if not inv.accessible or not inv.items:
                        values[game] = InventoryValue(game, None, inv.raw_item_count, inv.status)
                        continue
                    total = 0
                    priced = 0
                    for item in inv.items:
                        key = (game, item.market_hash_name)
                        if key not in self.price_cache:
                            self.price_cache[key] = (await self.market.quote(game, item.market_hash_name)).value_rub
                        unit = self.price_cache[key]
                        if unit is None:
                            continue
                        total += unit * item.amount
                        priced += item.amount
                    values[game] = InventoryValue(game, total if priced else None, priced, "ok")
                except Exception:
                    values[game] = InventoryValue(game, None, 0, "error")

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
