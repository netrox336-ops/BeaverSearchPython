from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path

from platformdirs import user_config_dir, user_data_dir

from .domain import PriceRange, SearchFilters


APP_NAME = "BeaverSearch"
APP_AUTHOR = "BeaverSearch"


@dataclass(slots=True)
class AppSettings:
    language: str = "ru"
    close_to_tray: bool = True
    start_behavior: str = "main"
    poll_interval_seconds: int = 60
    request_timeout_seconds: int = 10
    player_recheck_hours: int = 24
    concurrent_scans: int = 5
    server_concurrency: int = 4
    inventory_concurrency: int = 4
    market_concurrency: int = 2
    market_min_interval_seconds: float = 0.35
    price_cache_minutes: int = 30
    steam_web_api_key: str = ""
    filters: SearchFilters = field(default_factory=SearchFilters)


class SettingsStore:
    def __init__(self) -> None:
        self.config_dir = Path(user_config_dir(APP_NAME, APP_AUTHOR))
        self.data_dir = Path(user_data_dir(APP_NAME, APP_AUTHOR))
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.path = self.config_dir / "settings.json"

    def load(self) -> AppSettings:
        if not self.path.exists():
            return AppSettings()
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            filters_raw = raw.pop("filters", {})
            filters = SearchFilters(
                cs2=PriceRange(**filters_raw.get("cs2", {"minimum": 3500, "maximum": 30000, "enabled": True})),
                dota2=PriceRange(**filters_raw.get("dota2", {"minimum": 1000, "maximum": 5000, "enabled": True})),
                rust=PriceRange(**filters_raw.get("rust", {"minimum": 4000, "maximum": 10000, "enabled": True})),
            )
            known = {field_name for field_name in AppSettings.__dataclass_fields__ if field_name != "filters"}
            sanitized = {k: v for k, v in raw.items() if k in known}
            return AppSettings(filters=filters, **sanitized)
        except Exception:
            return AppSettings()

    def save(self, settings: AppSettings) -> None:
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(asdict(settings), ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(self.path)
