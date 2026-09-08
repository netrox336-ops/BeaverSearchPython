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
    player_error: str | None = None


class A2SClient:
    """Async adapter around python-a2s.

    A2S_INFO and A2S_PLAYER are intentionally queried independently. A server
    can answer INFO while blocking PLAYER; that must not be reported as
    "offline" because it makes diagnostics misleading.
    """

    async def scan(self, target: ServerTarget, timeout: float = 10.0) -> A2SScan:
        address = (target.host, target.port)
        started = time.perf_counter()
        try:
            info = await asyncio.wait_for(
                asyncio.to_thread(a2s.info, address, timeout=timeout),
                timeout=timeout + 0.5,
            )
        except Exception as exc:
            return A2SScan(
                snapshot=ServerSnapshot(online=False, error=f"{type(exc).__name__}: {exc}"),
                players=[],
            )

        ping_ms = int((time.perf_counter() - started) * 1000)
        snapshot = ServerSnapshot(
            online=True,
            name=str(getattr(info, "server_name", target.name or target.address)),
            map_name=str(getattr(info, "map_name", "")),
            players=int(getattr(info, "player_count", 0) or 0),
            max_players=int(getattr(info, "max_players", 0) or 0),
            ping_ms=ping_ms,
        )

        player_error: str | None = None
        player_rows = []
        for attempt in range(2):
            try:
                player_rows = await asyncio.wait_for(
                    asyncio.to_thread(a2s.players, address, timeout=timeout),
                    timeout=timeout + 0.5,
                )
                player_error = None
                break
            except Exception as exc:
                player_error = f"{type(exc).__name__}: {exc}"
                if attempt == 0:
                    await asyncio.sleep(0.15)

        players = [
            A2SPlayer(
                nickname=(p.name or "").strip(),
                score=int(getattr(p, "score", 0) or 0),
                duration_seconds=float(getattr(p, "duration", 0.0) or 0.0),
            )
            for p in player_rows
            if (p.name or "").strip()
        ]
        if players and snapshot.players <= 0:
            snapshot.players = len(players)
        return A2SScan(snapshot=snapshot, players=players, player_error=player_error)
