from __future__ import annotations

import html
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup


STEAM_ID64_RE = re.compile(r"7656119\d{10}")


@dataclass(slots=True)
class CommunityCandidate:
    steam_id64: str
    nickname: str
    profile_url: str
    avatar_url: str | None = None


class SteamCommunityClient:
    def __init__(self, timeout: float = 10.0) -> None:
        self.client = httpx.AsyncClient(
            timeout=timeout,
            follow_redirects=True,
            headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
                "Accept-Language": "en-US,en;q=0.9",
            },
        )

    async def close(self) -> None:
        await self.client.aclose()

    async def _ensure_session_id(self) -> str:
        if "sessionid" not in self.client.cookies:
            await self.client.get("https://steamcommunity.com/search/users/")
        return self.client.cookies.get("sessionid", "")

    async def search_users(self, nickname: str, pages: int = 2) -> list[CommunityCandidate]:
        session_id = await self._ensure_session_id()
        out: dict[str, CommunityCandidate] = {}
        for page in range(1, max(1, pages) + 1):
            response = await self.client.get(
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
            response.raise_for_status()
            payload = response.json()
            fragment = html.unescape(payload.get("html", ""))
            soup = BeautifulSoup(fragment, "html.parser")
            for link in soup.select("a.searchPersonaName"):
                profile_url = (link.get("href") or "").strip()
                display = link.get_text(" ", strip=True)
                steam_id = await self.resolve_profile_url(profile_url)
                if not steam_id:
                    continue
                row = link.find_parent(class_="search_row")
                avatar = None
                if row:
                    img = row.find("img")
                    if img:
                        avatar = img.get("src")
                out[steam_id] = CommunityCandidate(steam_id, display, profile_url, avatar)
        return list(out.values())

    async def resolve_profile_url(self, profile_url: str) -> str | None:
        match = STEAM_ID64_RE.search(profile_url)
        if match:
            return match.group(0)
        parsed = urlparse(profile_url)
        if "/id/" not in parsed.path:
            return None
        response = await self.client.get(profile_url.rstrip("/") + "/", params={"xml": "1"})
        if response.status_code != 200:
            return None
        try:
            root = ET.fromstring(response.text)
            node = root.find("steamID64")
            value = (node.text or "").strip() if node is not None else ""
            return value if STEAM_ID64_RE.fullmatch(value) else None
        except ET.ParseError:
            return None
