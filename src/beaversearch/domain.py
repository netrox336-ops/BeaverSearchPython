from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional


class Game(str, Enum):
    CS2 = "cs2"
    DOTA2 = "dota2"
    RUST = "rust"


APP_IDS: dict[Game, int] = {
    Game.CS2: 730,
    Game.DOTA2: 570,
    Game.RUST: 252490,
}


@dataclass(slots=True)
class PriceRange:
    minimum: int
    maximum: int
    enabled: bool = True

    def matches(self, value: Optional[int]) -> bool:
        return bool(self.enabled and value is not None and value > 0 and self.minimum <= value <= self.maximum)


@dataclass(slots=True)
class SearchFilters:
    cs2: PriceRange = field(default_factory=lambda: PriceRange(3500, 30000))
    dota2: PriceRange = field(default_factory=lambda: PriceRange(1000, 5000))
    rust: PriceRange = field(default_factory=lambda: PriceRange(4000, 10000))

    def for_game(self, game: Game) -> PriceRange:
        return {
            Game.CS2: self.cs2,
            Game.DOTA2: self.dota2,
            Game.RUST: self.rust,
        }[game]


@dataclass(slots=True)
class ServerTarget:
    id: int | None
    host: str
    port: int
    name: str = ""
    enabled: bool = True
    poll_interval: int = 60

    @property
    def address(self) -> str:
        return f"{self.host}:{self.port}"


@dataclass(slots=True)
class ServerSnapshot:
    online: bool
    name: str = ""
    map_name: str = ""
    players: int = 0
    max_players: int = 0
    ping_ms: int | None = None
    error: str | None = None


@dataclass(slots=True)
class A2SPlayer:
    nickname: str
    score: int = 0
    duration_seconds: float = 0.0


class ResolveConfidence(str, Enum):
    EXACT = "exact"
    HIGH = "high"
    POSSIBLE = "possible"
    NOT_FOUND = "not_found"


@dataclass(slots=True)
class ResolvedPlayer:
    nickname: str
    steam_id64: str | None
    profile_url: str | None
    avatar_url: str | None = None
    confidence: ResolveConfidence = ResolveConfidence.NOT_FOUND
    source: str = ""
    score: int = 0
    reason: str = ""


@dataclass(slots=True)
class InventoryValue:
    game: Game
    value_rub: int | None
    item_count: int = 0
    status: str = "ok"


@dataclass(slots=True)
class SearchResult:
    nickname: str
    steam_id64: str
    profile_url: str
    server_address: str
    server_name: str
    map_name: str
    cs2_rub: int | None
    dota2_rub: int | None
    rust_rub: int | None
    matched_games: tuple[Game, ...]
    first_seen_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    last_seen_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    times_seen: int = 1

    @property
    def total_rub(self) -> int:
        return sum(v or 0 for v in (self.cs2_rub, self.dota2_rub, self.rust_rub))
