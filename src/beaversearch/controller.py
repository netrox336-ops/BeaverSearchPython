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
    settingsChanged = Signal()
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
        self._online_servers = 0
        self._online_players = 0
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

    @Property(int, notify=statsChanged)
    def onlineServers(self) -> int:
        return self._online_servers

    @Property(int, notify=statsChanged)
    def onlinePlayers(self) -> int:
        return self._online_players

    @Property(str, notify=settingsChanged)
    def language(self) -> str:
        return self.settings.language

    @Property(int, notify=settingsChanged)
    def cs2Min(self) -> int:
        return self.settings.filters.cs2.minimum

    @Property(int, notify=settingsChanged)
    def cs2Max(self) -> int:
        return self.settings.filters.cs2.maximum

    @Property(int, notify=settingsChanged)
    def dotaMin(self) -> int:
        return self.settings.filters.dota2.minimum

    @Property(int, notify=settingsChanged)
    def dotaMax(self) -> int:
        return self.settings.filters.dota2.maximum

    @Property(int, notify=settingsChanged)
    def rustMin(self) -> int:
        return self.settings.filters.rust.minimum

    @Property(int, notify=settingsChanged)
    def rustMax(self) -> int:
        return self.settings.filters.rust.maximum

    @Property(int, notify=settingsChanged)
    def pollInterval(self) -> int:
        return self.settings.poll_interval_seconds

    @Property(int, notify=settingsChanged)
    def requestTimeout(self) -> int:
        return self.settings.request_timeout_seconds

    @Property(int, notify=settingsChanged)
    def recheckHours(self) -> int:
        return self.settings.player_recheck_hours

    @Property(int, notify=settingsChanged)
    def concurrentScans(self) -> int:
        return self.settings.concurrent_scans

    @Property(bool, notify=settingsChanged)
    def steamApiConfigured(self) -> bool:
        return bool(self.settings.steam_web_api_key.strip())

    @Property(str, constant=True)
    def dataDirectory(self) -> str:
        return str(self.store.data_dir)

    @Property(str, constant=True)
    def settingsFile(self) -> str:
        return str(self.store.path)

    @Property(bool, notify=settingsChanged)
    def servicesReady(self) -> bool:
        return self._services_ready

    async def initialize(self) -> None:
        await self.db.open()
        await self._rebuild_services()
        await self.refresh_models()
        self.settingsChanged.emit()

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
        self.settingsChanged.emit()

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
        self.settingsChanged.emit()

    async def refresh_models(self) -> None:
        servers = await self.db.list_servers()
        old = {row.get("id"): row for row in self._servers}
        self._servers = []
        for server in servers:
            previous = old.get(server.id, {})
            self._servers.append(
                {
                    "id": server.id,
                    "address": server.address,
                    "name": server.name or previous.get("name") or server.address,
                    "online": previous.get("online", False),
                    "map": previous.get("map", "—"),
                    "players": previous.get("players", "—"),
                    "playerCount": previous.get("playerCount", 0),
                    "maxPlayers": previous.get("maxPlayers", 0),
                    "ping": previous.get("ping", "—"),
                    "playerQueryOk": previous.get("playerQueryOk", True),
                    "playerError": previous.get("playerError", ""),
                }
            )
        self._results = await self.db.list_results()
        self._recalculate_live_stats()
        self.serversChanged.emit()
        self.resultsChanged.emit()
        self.statsChanged.emit()

    def _recalculate_live_stats(self) -> None:
        self._online_servers = sum(1 for row in self._servers if row.get("online"))
        self._online_players = sum(int(row.get("playerCount", 0) or 0) for row in self._servers if row.get("online"))

    @Slot(str, str)
    def addServer(self, address: str, name: str = "") -> None:
        asyncio.create_task(self._add_server(address, name))

    async def _add_server(self, address: str, name: str) -> None:
        if len(self._servers) >= 20:
            self.toastRequested.emit("limit", "Можно отслеживать не более 20 серверов" if self.settings.language == "ru" else "Up to 20 servers can be monitored")
            return
        match = _ADDRESS_RE.match(address)
        if not match:
            self.toastRequested.emit("error", "Неверный IP:PORT" if self.settings.language == "ru" else "Invalid IP:PORT")
            return
        host = match.group(1)
        port = int(match.group(2) or 27015)
        if not 1 <= port <= 65535:
            self.toastRequested.emit("error", "Неверный порт" if self.settings.language == "ru" else "Invalid port")
            return
        await self.db.add_server(host, port, name.strip())
        await self.refresh_models()
        self.toastRequested.emit("ok", "Сервер добавлен" if self.settings.language == "ru" else "Server added")

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
            self.toastRequested.emit("info", "Добавьте хотя бы один CS2 сервер" if self.settings.language == "ru" else "Add at least one CS2 server")
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
                    row.update({
                        "online": False,
                        "players": "—",
                        "playerCount": 0,
                        "maxPlayers": 0,
                        "ping": "—",
                        "playerQueryOk": False,
                        "playerError": str(error),
                    })
                else:
                    row.update(
                        {
                            "name": scan.snapshot.name or row["name"],
                            "online": scan.snapshot.online,
                            "map": scan.snapshot.map_name or "—",
                            "players": f"{scan.snapshot.players} / {scan.snapshot.max_players}" if scan.snapshot.online else "—",
                            "playerCount": int(scan.snapshot.players or 0) if scan.snapshot.online else 0,
                            "maxPlayers": int(scan.snapshot.max_players or 0) if scan.snapshot.online else 0,
                            "ping": f"{scan.snapshot.ping_ms} мс" if scan.snapshot.ping_ms is not None else "—",
                            "playerQueryOk": scan.player_error is None,
                            "playerError": scan.player_error or "",
                        }
                    )
                    self._checked_today += len(scan.players)
                    self._matched_session += len(found)
                    any_found = any_found or bool(found)
                self._servers[index] = row

            self._recalculate_live_stats()
            self.serversChanged.emit()
            self.statsChanged.emit()
            if any_found:
                self._results = await self.db.list_results()
                self.resultsChanged.emit()

            await asyncio.sleep(max(10, self.settings.poll_interval_seconds))

    @Slot(int, int, int, int, int, int)
    def saveFilters(self, cs2_min: int, cs2_max: int, dota_min: int, dota_max: int, rust_min: int, rust_max: int) -> None:
        values = (cs2_min, cs2_max, dota_min, dota_max, rust_min, rust_max)
        if any(value < 0 for value in values) or cs2_min > cs2_max or dota_min > dota_max or rust_min > rust_max:
            self.toastRequested.emit("error", "Проверьте диапазоны цен" if self.settings.language == "ru" else "Check the price ranges")
            return
        self.settings.filters = SearchFilters(
            PriceRange(cs2_min, cs2_max),
            PriceRange(dota_min, dota_max),
            PriceRange(rust_min, rust_max),
        )
        self.store.save(self.settings)
        if self._services_ready:
            self.scanner.filters = self.settings.filters
        self.settingsChanged.emit()
        self.toastRequested.emit("ok", "Фильтры сохранены" if self.settings.language == "ru" else "Filters saved")

    @Slot(int, int, int, int)
    def saveScanSettings(self, poll_interval: int, timeout: int, recheck_hours: int, concurrent_scans: int) -> None:
        self.settings.poll_interval_seconds = max(10, min(3600, int(poll_interval)))
        self.settings.request_timeout_seconds = max(3, min(60, int(timeout)))
        self.settings.player_recheck_hours = max(1, min(168, int(recheck_hours)))
        self.settings.concurrent_scans = max(1, min(20, int(concurrent_scans)))
        self.store.save(self.settings)
        self.settingsChanged.emit()
        asyncio.create_task(self._apply_service_settings("Параметры сканирования сохранены", "Scan settings saved"))

    @Slot(str)
    def saveSteamApiKey(self, key: str) -> None:
        self.settings.steam_web_api_key = key.strip()
        self.store.save(self.settings)
        self.settingsChanged.emit()
        asyncio.create_task(self._apply_service_settings("Steam Web API key сохранён", "Steam Web API key saved"))

    async def _apply_service_settings(self, message_ru: str = "Настройки применены", message_en: str = "Settings applied") -> None:
        was_monitoring = self._monitoring
        if was_monitoring:
            await self.stop_monitoring()
        await self._rebuild_services()
        self.toastRequested.emit("ok", message_ru if self.settings.language == "ru" else message_en)
        if was_monitoring:
            await self.start_monitoring()

    @Slot(str)
    def setLanguage(self, language: str) -> None:
        self.settings.language = "en" if language == "en" else "ru"
        self.store.save(self.settings)
        self.settingsChanged.emit()
        self.toastRequested.emit("ok", "English enabled" if self.settings.language == "en" else "Русский язык включён")

    @Slot(str)
    def requestTheme(self, theme: str) -> None:
        if theme != "dark":
            self.toastRequested.emit("info", "Станет доступно позже" if self.settings.language == "ru" else "Coming later")

    @Slot(str)
    def showMessage(self, message: str) -> None:
        self.toastRequested.emit("info", message)

    @Slot()
    def clearCache(self) -> None:
        asyncio.create_task(self._clear_cache())

    async def _clear_cache(self) -> None:
        if not self.db.db:
            return
        await self.db.db.execute("DELETE FROM price_cache")
        await self.db.db.execute("DELETE FROM inventory_checks")
        await self.db.db.commit()
        self.toastRequested.emit("ok", "Кэш очищен" if self.settings.language == "ru" else "Cache cleared")

    @Slot()
    def refreshNow(self) -> None:
        if not self._monitoring:
            self.toastRequested.emit("info", "Сначала запустите мониторинг" if self.settings.language == "ru" else "Start monitoring first")
            return
        self.toastRequested.emit("info", "Следующий цикл уже выполняется автоматически" if self.settings.language == "ru" else "The next scan cycle runs automatically")

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
