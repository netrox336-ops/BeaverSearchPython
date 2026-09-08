from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import aiosqlite
from platformdirs import user_data_dir

from ..domain import SearchResult, ServerTarget


class Database:
    def __init__(self) -> None:
        root = Path(user_data_dir("BeaverSearch", "BeaverSearch"))
        root.mkdir(parents=True, exist_ok=True)
        self.path = root / "beaversearch.sqlite3"
        self.db: aiosqlite.Connection | None = None

    async def open(self) -> None:
        self.db = await aiosqlite.connect(self.path)
        self.db.row_factory = aiosqlite.Row
        await self.db.executescript(
            """
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS servers(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              host TEXT NOT NULL,
              port INTEGER NOT NULL,
              name TEXT NOT NULL DEFAULT '',
              enabled INTEGER NOT NULL DEFAULT 1,
              poll_interval INTEGER NOT NULL DEFAULT 60,
              UNIQUE(host, port)
            );
            CREATE TABLE IF NOT EXISTS player_checks(
              server_address TEXT NOT NULL,
              nickname TEXT NOT NULL,
              steam_id64 TEXT,
              checked_at TEXT NOT NULL,
              status TEXT NOT NULL,
              PRIMARY KEY(server_address, nickname)
            );
            CREATE TABLE IF NOT EXISTS price_cache(
              app_id INTEGER NOT NULL,
              market_hash_name TEXT NOT NULL,
              price_rub INTEGER,
              updated_at TEXT NOT NULL,
              PRIMARY KEY(app_id, market_hash_name)
            );
            CREATE TABLE IF NOT EXISTS results(
              steam_id64 TEXT PRIMARY KEY,
              nickname TEXT NOT NULL,
              profile_url TEXT NOT NULL,
              cs2_rub INTEGER,
              dota2_rub INTEGER,
              rust_rub INTEGER,
              total_rub INTEGER NOT NULL,
              matched_games TEXT NOT NULL,
              server_address TEXT NOT NULL,
              server_name TEXT NOT NULL,
              map_name TEXT NOT NULL,
              first_seen_at TEXT NOT NULL,
              last_seen_at TEXT NOT NULL,
              times_seen INTEGER NOT NULL DEFAULT 1
            );
            CREATE TABLE IF NOT EXISTS sightings(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              steam_id64 TEXT NOT NULL,
              nickname TEXT NOT NULL,
              server_address TEXT NOT NULL,
              server_name TEXT NOT NULL,
              map_name TEXT NOT NULL,
              seen_at TEXT NOT NULL
            );
            """
        )
        await self.db.commit()

    async def close(self) -> None:
        if self.db:
            await self.db.close()
            self.db = None

    async def list_servers(self) -> list[ServerTarget]:
        assert self.db
        rows = await (await self.db.execute("SELECT * FROM servers ORDER BY id")).fetchall()
        return [ServerTarget(r["id"], r["host"], r["port"], r["name"], bool(r["enabled"]), r["poll_interval"]) for r in rows]

    async def add_server(self, host: str, port: int, name: str = "") -> ServerTarget:
        assert self.db
        cur = await self.db.execute(
            "INSERT INTO servers(host,port,name) VALUES(?,?,?) ON CONFLICT(host,port) DO UPDATE SET name=excluded.name RETURNING id",
            (host, port, name),
        )
        row = await cur.fetchone()
        await self.db.commit()
        return ServerTarget(int(row[0]), host, port, name)

    async def remove_server(self, server_id: int) -> None:
        assert self.db
        await self.db.execute("DELETE FROM servers WHERE id=?", (server_id,))
        await self.db.commit()

    async def was_checked_recently(self, server_address: str, nickname: str, hours: int) -> bool:
        assert self.db
        row = await (await self.db.execute(
            "SELECT checked_at FROM player_checks WHERE server_address=? AND nickname=?",
            (server_address, nickname),
        )).fetchone()
        if not row:
            return False
        try:
            checked = datetime.fromisoformat(row[0])
        except ValueError:
            return False
        return checked >= datetime.now(timezone.utc) - timedelta(hours=hours)

    async def mark_checked(self, server_address: str, nickname: str, steam_id64: str | None, status: str) -> None:
        assert self.db
        now = datetime.now(timezone.utc).isoformat()
        await self.db.execute(
            """INSERT INTO player_checks(server_address,nickname,steam_id64,checked_at,status)
               VALUES(?,?,?,?,?)
               ON CONFLICT(server_address,nickname) DO UPDATE SET steam_id64=excluded.steam_id64, checked_at=excluded.checked_at, status=excluded.status""",
            (server_address, nickname, steam_id64, now, status),
        )
        await self.db.commit()

    async def save_result(self, result: SearchResult) -> None:
        assert self.db
        await self.db.execute(
            """INSERT INTO results(steam_id64,nickname,profile_url,cs2_rub,dota2_rub,rust_rub,total_rub,matched_games,server_address,server_name,map_name,first_seen_at,last_seen_at,times_seen)
               VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
               ON CONFLICT(steam_id64) DO UPDATE SET
                 nickname=excluded.nickname, profile_url=excluded.profile_url,
                 cs2_rub=excluded.cs2_rub, dota2_rub=excluded.dota2_rub, rust_rub=excluded.rust_rub,
                 total_rub=excluded.total_rub, matched_games=excluded.matched_games,
                 server_address=excluded.server_address, server_name=excluded.server_name, map_name=excluded.map_name,
                 last_seen_at=excluded.last_seen_at, times_seen=results.times_seen+1""",
            (
                result.steam_id64, result.nickname, result.profile_url,
                result.cs2_rub, result.dota2_rub, result.rust_rub, result.total_rub,
                json.dumps([g.value for g in result.matched_games]),
                result.server_address, result.server_name, result.map_name,
                result.first_seen_at.isoformat(), result.last_seen_at.isoformat(), result.times_seen,
            ),
        )
        await self.db.execute(
            "INSERT INTO sightings(steam_id64,nickname,server_address,server_name,map_name,seen_at) VALUES(?,?,?,?,?,?)",
            (result.steam_id64, result.nickname, result.server_address, result.server_name, result.map_name, result.last_seen_at.isoformat()),
        )
        await self.db.commit()

    async def list_results(self) -> list[dict]:
        assert self.db
        rows = await (await self.db.execute("SELECT * FROM results ORDER BY last_seen_at DESC")).fetchall()
        return [dict(r) for r in rows]
