from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import aiosqlite
from platformdirs import user_data_dir

from ..domain import APP_IDS, Game, InventoryValue, SearchResult, ServerTarget


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
            PRAGMA synchronous=NORMAL;
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
            CREATE TABLE IF NOT EXISTS inventory_checks(
              steam_id64 TEXT PRIMARY KEY,
              nickname TEXT NOT NULL,
              checked_at TEXT NOT NULL,
              cs2_rub INTEGER,
              dota2_rub INTEGER,
              rust_rub INTEGER,
              cs2_count INTEGER NOT NULL DEFAULT 0,
              dota2_count INTEGER NOT NULL DEFAULT 0,
              rust_count INTEGER NOT NULL DEFAULT 0,
              cs2_status TEXT NOT NULL DEFAULT 'unknown',
              dota2_status TEXT NOT NULL DEFAULT 'unknown',
              rust_status TEXT NOT NULL DEFAULT 'unknown'
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
            CREATE INDEX IF NOT EXISTS idx_player_checks_checked_at ON player_checks(checked_at);
            CREATE INDEX IF NOT EXISTS idx_price_cache_updated_at ON price_cache(updated_at);
            CREATE INDEX IF NOT EXISTS idx_sightings_steam_seen ON sightings(steam_id64, seen_at DESC);
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

    async def get_cached_prices(self, game: Game, names: list[str], max_age_minutes: int) -> dict[str, int | None]:
        assert self.db
        if not names:
            return {}
        cutoff = (datetime.now(timezone.utc) - timedelta(minutes=max_age_minutes)).isoformat()
        appid = APP_IDS[game]
        unique_names = list(dict.fromkeys(names))
        out: dict[str, int | None] = {}
        for start in range(0, len(unique_names), 400):
            chunk = unique_names[start:start + 400]
            placeholders = ",".join("?" for _ in chunk)
            rows = await (await self.db.execute(
                f"SELECT market_hash_name, price_rub FROM price_cache WHERE app_id=? AND updated_at>=? AND market_hash_name IN ({placeholders})",
                (appid, cutoff, *chunk),
            )).fetchall()
            for row in rows:
                out[str(row["market_hash_name"])] = row["price_rub"]
        return out

    async def set_cached_prices(self, game: Game, prices: dict[str, int | None]) -> None:
        assert self.db
        if not prices:
            return
        now = datetime.now(timezone.utc).isoformat()
        appid = APP_IDS[game]
        await self.db.executemany(
            """INSERT INTO price_cache(app_id,market_hash_name,price_rub,updated_at) VALUES(?,?,?,?)
               ON CONFLICT(app_id,market_hash_name) DO UPDATE SET price_rub=excluded.price_rub, updated_at=excluded.updated_at""",
            [(appid, name, value, now) for name, value in prices.items()],
        )
        await self.db.commit()

    async def get_recent_inventory_values(self, steam_id64: str, hours: int) -> dict[Game, InventoryValue] | None:
        assert self.db
        row = await (await self.db.execute(
            "SELECT * FROM inventory_checks WHERE steam_id64=?",
            (steam_id64,),
        )).fetchone()
        if not row:
            return None
        try:
            checked = datetime.fromisoformat(row["checked_at"])
        except ValueError:
            return None
        if checked < datetime.now(timezone.utc) - timedelta(hours=hours):
            return None
        return {
            Game.CS2: InventoryValue(Game.CS2, row["cs2_rub"], row["cs2_count"], row["cs2_status"]),
            Game.DOTA2: InventoryValue(Game.DOTA2, row["dota2_rub"], row["dota2_count"], row["dota2_status"]),
            Game.RUST: InventoryValue(Game.RUST, row["rust_rub"], row["rust_count"], row["rust_status"]),
        }

    async def save_inventory_values(self, steam_id64: str, nickname: str, values: dict[Game, InventoryValue]) -> None:
        assert self.db
        now = datetime.now(timezone.utc).isoformat()
        cs2, dota, rust = values[Game.CS2], values[Game.DOTA2], values[Game.RUST]
        await self.db.execute(
            """INSERT INTO inventory_checks(
                 steam_id64,nickname,checked_at,cs2_rub,dota2_rub,rust_rub,
                 cs2_count,dota2_count,rust_count,cs2_status,dota2_status,rust_status
               ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
               ON CONFLICT(steam_id64) DO UPDATE SET
                 nickname=excluded.nickname, checked_at=excluded.checked_at,
                 cs2_rub=excluded.cs2_rub, dota2_rub=excluded.dota2_rub, rust_rub=excluded.rust_rub,
                 cs2_count=excluded.cs2_count, dota2_count=excluded.dota2_count, rust_count=excluded.rust_count,
                 cs2_status=excluded.cs2_status, dota2_status=excluded.dota2_status, rust_status=excluded.rust_status""",
            (
                steam_id64, nickname, now,
                cs2.value_rub, dota.value_rub, rust.value_rub,
                cs2.item_count, dota.item_count, rust.item_count,
                cs2.status, dota.status, rust.status,
            ),
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
