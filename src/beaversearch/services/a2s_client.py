from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass

import a2s

from ..domain import A2SPlayer, ServerSnapshot, ServerTarget


@dataclass(slots=True)
class A2SScan:
    snapshot: ServerSnapshot
    players: list[A2SPlayer]


class A2SClient:
    """Thin async adapter around python-a2s.

    A2S_PLAYER intentionally only gives nickname/score/duration. SteamID
    resolution is handled by the resolver pipeline, not by this class.
    """

    async def scan(self, target: ServerTarget, timeout: float = 10.0) -> A2SScan:
        address = (target.host, target.port)
        started = time.perf_counter()
        try:
            info = await asyncio.wait_for(asyncio.to_thread(a2s.info, address), timeout=timeout)
            player_rows = await asyncio.wait_for(asyncio.to_thread(a2s.players, address), timeout=timeout)
            ping_ms = int((time.perf_counter() - started) * 1000)
            players = [
                A2SPlayer(
                    nickname=(p.name or "").strip(),
                    score=int(getattr(p, "score", 0) or 0),
                    duration_seconds=float(getattr(p, "duration", 0.0) or 0.0),
                )
                for p in player_rows
                if (p.name or "").strip()
            ]
            snapshot = ServerSnapshot(
                online=True,
                name=str(getattr(info, "server_name", target.name or target.address)),
                map_name=str(getattr(info, "map_name", "")),
                players=int(getattr(info, "player_count", len(players)) or len(players)),
                max_players=int(getattr(info, "max_players", 0) or 0),
                ping_ms=ping_ms,
            )
            return A2SScan(snapshot=snapshot, players=players)
        except Exception as exc:
            return A2SScan(
                snapshot=ServerSnapshot(online=False, error=f"{type(exc).__name__}: {exc}"),
                players=[],
            )
