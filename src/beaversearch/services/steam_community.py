from __future__ import annotations

import asyncio
import html
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup


STEAM_ID64_RE = re.compile(r"7656119\d{10}")
_APP_LINK_RE = re.compile(r"/app/(\d+)")


@dataclass(slots=True)
class CommunityCandidate:
    steam_id64: str
    nickname: str
    profile_url: str
    avatar_url: str | None = None


@dataclass(slots=True)
class CommunityProfile:
    steam_id64: str
    nickname: str
    profile_url: str
    avatar_url: str | None = None
    online_state: str | None = None
    game_name: str | None = None
    game_app_id: str | None = None


class SteamCommunityClient:
    def __init__(self, timeout: float = 10.0, resolve_concurrency: int = 8) -> None:
        self.client = httpx.AsyncClient(
            timeout=timeout,
            follow_redirects=True,
            http2=True,
            headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
                "Accept-Language": "en-US,en;q=0.9",
            },
        )
        self._resolve_sem = asyncio.Semaphore(max(1, resolve_concurrency))

    async def close(self) -> None:
        await self.client.aclose()

    async def _get(self, url: str, **kwargs) -> httpx.Response:
        last: Exception | None = None
        for attempt in range(3):
            try:
                response = await self.client.get(url, **kwargs)
                if response.status_code == 429 or response.status_code >= 500:
                    delay = min(8.0, float(response.headers.get("Retry-After", 0) or 0) or (0.7 * (2**attempt)))
                    await asyncio.sleep(delay)
                    continue
                response.raise_for_status()
                return response
            except (httpx.HTTPError, ValueError) as exc:
                last = exc
                if attempt < 2:
                    await asyncio.sleep(0.5 * (2**attempt))
        raise RuntimeError(f"Steam Community request failed: {last}")

    async def _ensure_session_id(self) -> str:
        if "sessionid" not in self.client.cookies:
            await self._get("https://steamcommunity.com/search/users/")
        return self.client.cookies.get("sessionid", "")

    async def search_users(self, nickname: str, pages: int = 1) -> list[CommunityCandidate]:
        session_id = await self._ensure_session_id()
        rows: dict[str, tuple[str, str | None]] = {}
        for page in range(1, max(1, pages) + 1):
            response = await self._get(
                "https://steamcommunity.com/search/SearchCommunityAjax",
                params={
                    "text": nickname,
                    "filter": "users",
                    "sessionid": session_id,
                    "steamid_user": "false",
                    "page": str(page),
                },
                headers={"X-Requested-With": "XMLHttpRequest"},
            )
            payload = response.json()
            fragment = html.unescape(payload.get("html", ""))
            soup = BeautifulSoup(fragment, "html.parser")
            for link in soup.select("a.searchPersonaName"):
                profile_url = (link.get("href") or "").strip()
                if not profile_url:
                    continue
                display = link.get_text(" ", strip=True)
                row = link.find_parent(class_="search_row")
                avatar = None
                if row:
                    img = row.find("img")
                    if img:
                        avatar = img.get("src")
                rows[profile_url] = (display, avatar)

        async def resolve_one(profile_url: str, display: str, avatar: str | None):
            async with self._resolve_sem:
                steam_id = await self.resolve_profile_url(profile_url)
                if not steam_id:
                    return None
                return CommunityCandidate(steam_id, display, profile_url, avatar)

        resolved = await asyncio.gather(
            *(resolve_one(url, display, avatar) for url, (display, avatar) in rows.items()),
            return_exceptions=True,
        )
        out: dict[str, CommunityCandidate] = {}
        for item in resolved:
            if isinstance(item, CommunityCandidate):
                out[item.steam_id64] = item
        return list(out.values())

    async def resolve_profile_url(self, profile_url: str) -> str | None:
        match = STEAM_ID64_RE.search(profile_url)
        if match:
            return match.group(0)
        parsed = urlparse(profile_url)
        if "/id/" not in parsed.path:
            return None
        try:
            response = await self._get(profile_url.rstrip("/") + "/", params={"xml": "1"})
            root = ET.fromstring(response.text)
            value = (root.findtext("steamID64") or "").strip()
            return value if STEAM_ID64_RE.fullmatch(value) else None
        except (ET.ParseError, RuntimeError):
            return None

    async def profile(self, steam_id64: str) -> CommunityProfile | None:
        if not STEAM_ID64_RE.fullmatch(steam_id64):
            return None
        try:
            response = await self._get(
                f"https://steamcommunity.com/profiles/{steam_id64}/",
                params={"xml": "1"},
            )
            root = ET.fromstring(response.text)
        except (ET.ParseError, RuntimeError):
            return None

        nickname = (root.findtext("steamID") or "").strip()
        avatar = (root.findtext("avatarFull") or root.findtext("avatarMedium") or "").strip() or None
        online_state = (root.findtext("onlineState") or "").strip() or None
        game_name = None
        game_app_id = None
        in_game = root.find("inGameInfo")
        if in_game is not None:
            game_name = (in_game.findtext("gameName") or "").strip() or None
            game_link = (in_game.findtext("gameLink") or "").strip()
            match = _APP_LINK_RE.search(game_link)
            if match:
                game_app_id = match.group(1)
        return CommunityProfile(
            steam_id64=steam_id64,
            nickname=nickname,
            profile_url=f"https://steamcommunity.com/profiles/{steam_id64}/",
            avatar_url=avatar,
            online_state=online_state,
            game_name=game_name,
            game_app_id=game_app_id,
        )
