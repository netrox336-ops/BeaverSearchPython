from __future__ import annotations

import asyncio
import re
from pathlib import Path

from PySide6.QtCore import QObject, Property, Signal, Slot

from .domain import PriceRange, SearchFilters
from .exporter import export_csv, export_xlsx
from .services.a2s_client import A2SClient
from .services.inventory import SteamInventoryClient
from .services.market import SteamMarketClient
from .services.resolver import SteamIdResolver
from .services.scanner import PlayerScanner
from .services.steam_community import SteamCommunityClient
from .services.steam_webapi import SteamWebApiClient
from .settings import AppSettings, SettingsStore
from .storage.database import Database


_ADDRESS_RE = re.compile(r"^\s*([^:\s]+)(?::(\d{1,5}))?\s*$")


class AppController(QObject):
    serversChanged = Signal()
    resultsChanged = Signal()
    monitoringChanged = Signal()
    statsChanged = Signal()
    toastRequested = Signal(str, str)

    def __init__(self) -> None:
        super().__init__()
        self.store = SettingsStore()
        self.settings: AppSettings = self.store.load()
        self.db = Database()
        self._servers: list[dict] = []
        self._results: list[dict] = []
        self._monitoring = False
        self._monitor_task: asyncio.Task | None = None
        self._checked_today = 0
        self._matched_session = 0
        self._services_ready = False

    @Property("QVariantList", notify=serversChanged)
    def servers(self):
        return self._servers

    @Property("QVariantList", notify=resultsChanged)
    def results(self):
        return self._results

    @Property(bool, notify=monitoringChanged)
    def monitoring(self) -> bool:
        return self._monitoring

    @Property(int, notify=statsChanged)
    def checkedToday(self) -> int:
        return self._checked_today

    @Property(int, notify=statsChanged)
    def matchedSession(self) -> int:
        return self._matched_session

    @Property(str, constant=True)
    def language(self) -> str:
        return self.settings.language

    async def initialize(self) -> None:
        await self.db.open()
        await self._rebuild_services()
        await self.refresh_models()

    async def shutdown(self) -> None:
        await self.stop_monitoring()
        await self._close_services()
        await self.db.close()

    async def _close_services(self) -> None:
        if not self._services_ready:
            return
        await self.community.close()
        await self.inventory.close()
        await self.market.close()
        if self.webapi:
            await self.webapi.close()
        self._services_ready = False

    async def _rebuild_services(self) -> None:
        await self._close_services()
        self.community = SteamCommunityClient(self.settings.request_timeout_seconds)
        self.webapi = (
            SteamWebApiClient(self.settings.steam_web_api_key, self.settings.request_timeout_seconds)
            if self.settings.steam_web_api_key else None
        )
        self.inventory = SteamInventoryClient(
            self.settings.request_timeout_seconds + 5,
            self.settings.inventory_concurrency,
        )
        self.market = SteamMarketClient(
            self.settings.request_timeout_seconds,
            self.settings.market_concurrency,
            self.settings.market_min_interval_seconds,
        )
        self.scanner = PlayerScanner(
            self.db,
            A2SClient(),
            SteamIdResolver(self.community, self.webapi),
            self.inventory,
            self.market,
            self.settings.filters,
            self.settings.player_recheck_hours,
            self.settings.concurrent_scans,
            self.settings.price_cache_minutes,
        )
        self._services_ready = True

    async def refresh_models(self) -> None:
        servers = await self.db.list_servers()
        self._servers = [
            {
                "id": s.id,
                "address": s.address,
                "name": s.name or s.address,
                "online": False,
                "map": "—",
                "players": "—",
                "ping": "—",
                "playerQueryOk": True,
                "playerError": "",
            }
            for s in servers
        ]
        self._results = await self.db.list_results()
        self.serversChanged.emit()
        self.resultsChanged.emit()

    @Slot(str, str)
    def addServer(self, address: str, name: str = "") -> None:
        asyncio.create_task(self._add_server(address, name))

    async def _add_server(self, address: str, name: str) -> None:
        if len(self._servers) >= 20:
            self.toastRequested.emit("limit", "Можно отслеживать не более 20 серверов")
            return
        match = _ADDRESS_RE.match(address)
        if not match:
            self.toastRequested.emit("error", "Неверный IP:PORT")
            return
        host = match.group(1)
        port = int(match.group(2) or 27015)
        if not 1 <= port <= 65535:
            self.toastRequested.emit("error", "Неверный порт")
            return
        await self.db.add_server(host, port, name.strip())
        await self.refresh_models()
        self.toastRequested.emit("ok", "Сервер добавлен")

    @Slot(int)
    def removeServer(self, server_id: int) -> None:
        asyncio.create_task(self._remove_server(server_id))

    async def _remove_server(self, server_id: int) -> None:
        await self.db.remove_server(server_id)
        await self.refresh_models()

    @Slot()
    def toggleMonitoring(self) -> None:
        if self._monitoring:
            asyncio.create_task(self.stop_monitoring())
        else:
            asyncio.create_task(self.start_monitoring())

    async def start_monitoring(self) -> None:
        if self._monitoring:
            return
        servers = [s for s in await self.db.list_servers() if s.enabled]
        if not servers:
            self.toastRequested.emit("info", "Добавьте хотя бы один CS2 сервер")
            return
        self._monitoring = True
        self.monitoringChanged.emit()
        self._monitor_task = asyncio.create_task(self._monitor_loop())

    async def stop_monitoring(self) -> None:
        if not self._monitoring and not self._monitor_task:
            return
        self._monitoring = False
        self.monitoringChanged.emit()
        if self._monitor_task:
            self._monitor_task.cancel()
            try:
                await self._monitor_task
            except asyncio.CancelledError:
                pass
            self._monitor_task = None

    async def _monitor_loop(self) -> None:
        server_sem = asyncio.Semaphore(max(1, self.settings.server_concurrency))

        async def run_one(server):
            async with server_sem:
                try:
                    scan, found = await self.scanner.scan_server(server, self.settings.request_timeout_seconds)
                    return server, scan, found, None
                except Exception as exc:
                    return server, None, [], exc

        while self._monitoring:
            servers = [s for s in await self.db.list_servers() if s.enabled]
            rows = await asyncio.gather(*(run_one(server) for server in servers))
            any_found = False

            for server, scan, found, error in rows:
                index = next((i for i, row in enumerate(self._servers) if row.get("id") == server.id), None)
                if index is None:
                    continue
                row = dict(self._servers[index])
                if error is not None or scan is None:
                    row.update({"online": False, "players": "—", "ping": "—", "playerQueryOk": False, "playerError": str(error)})
                else:
                    row.update({
                        "name": scan.snapshot.name or row["name"],
                        "online": scan.snapshot.online,
                        "map": scan.snapshot.map_name or "—",
                        "players": f"{scan.snapshot.players} / {scan.snapshot.max_players}" if scan.snapshot.online else "—",
                        "ping": f"{scan.snapshot.ping_ms} мс" if scan.snapshot.ping_ms is not None else "—",
                        "playerQueryOk": scan.player_error is None,
                        "playerError": scan.player_error or "",
                    })
                    self._checked_today += len(scan.players)
                    self._matched_session += len(found)
                    any_found = any_found or bool(found)
                self._servers[index] = row

            self.serversChanged.emit()
            self.statsChanged.emit()
            if any_found:
                self._results = await self.db.list_results()
                self.resultsChanged.emit()

            await asyncio.sleep(max(10, self.settings.poll_interval_seconds))

    @Slot(int, int, int, int, int, int)
    def saveFilters(self, cs2_min: int, cs2_max: int, dota_min: int, dota_max: int, rust_min: int, rust_max: int) -> None:
        self.settings.filters = SearchFilters(
            PriceRange(cs2_min, cs2_max), PriceRange(dota_min, dota_max), PriceRange(rust_min, rust_max)
        )
        self.store.save(self.settings)
        self.scanner.filters = self.settings.filters
        self.toastRequested.emit("ok", "Фильтры сохранены")

    @Slot(str)
    def saveSteamApiKey(self, key: str) -> None:
        self.settings.steam_web_api_key = key.strip()
        self.store.save(self.settings)
        asyncio.create_task(self._apply_service_settings())

    async def _apply_service_settings(self) -> None:
        was_monitoring = self._monitoring
        if was_monitoring:
            await self.stop_monitoring()
        await self._rebuild_services()
        self.toastRequested.emit("ok", "Steam Web API key сохранён")
        if was_monitoring:
            await self.start_monitoring()

    @Slot(str)
    def setLanguage(self, language: str) -> None:
        self.settings.language = "en" if language == "en" else "ru"
        self.store.save(self.settings)
        self.toastRequested.emit("info", "Language will fully apply after restart" if language == "en" else "Язык полностью применится после перезапуска")

    @Slot(str)
    def requestTheme(self, theme: str) -> None:
        if theme != "dark":
            self.toastRequested.emit("info", "Станет доступно позже" if self.settings.language == "ru" else "Coming later")

    @Slot(str, str)
    def exportResults(self, path: str, format_name: str = "xlsx") -> None:
        try:
            target = Path(path)
            if format_name.lower() == "csv":
                export_csv(target, self._results, self.settings.language)
            else:
                export_xlsx(target, self._results, self.settings.language)
            self.toastRequested.emit("ok", "Экспорт завершён" if self.settings.language == "ru" else "Export complete")
        except Exception as exc:
            self.toastRequested.emit("error", str(exc))
