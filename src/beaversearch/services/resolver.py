from __future__ import annotations

import re
import unicodedata

from ..domain import ResolveConfidence, ResolvedPlayer, ServerTarget
from .steam_community import SteamCommunityClient
from .steam_webapi import SteamWebApiClient


def _norm(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold().strip()
    return re.sub(r"\s+", " ", value)


def _same_server(expected: ServerTarget, value: str | None) -> bool:
    if not value:
        return False
    value = value.strip().lower()
    host = expected.host.strip().lower()
    return value in {host, expected.address.lower()} or value.startswith(host + ":")


class SteamIdResolver:
    """Free resolver pipeline.

    1. Search Steam Community aliases.
    2. If a free user Steam Web API key is configured, batch-check candidates.
       gameserverip + appid 730 provides the strongest validation available
       without RCON/server plugins.
    3. Fall back to conservative alias scoring when presence data is private.
    """

    def __init__(self, community: SteamCommunityClient, api: SteamWebApiClient | None = None) -> None:
        self.community = community
        self.api = api

    async def resolve(self, nickname: str, server: ServerTarget) -> ResolvedPlayer:
        candidates = await self.community.search_users(nickname, pages=2)
        if not candidates:
            return ResolvedPlayer(nickname, None, None, confidence=ResolveConfidence.NOT_FOUND, source="steam_search")

        exact_alias = [c for c in candidates if _norm(c.nickname) == _norm(nickname)]
        pool = exact_alias or candidates

        if self.api and self.api.api_key:
            summaries = await self.api.summaries([c.steam_id64 for c in pool])
            by_id = {x.steam_id64: x for x in summaries}
            server_matches = [
                c for c in pool
                if (s := by_id.get(c.steam_id64)) and s.game_id == "730" and _same_server(server, s.game_server_ip)
            ]
            if len(server_matches) == 1:
                c = server_matches[0]
                s = by_id[c.steam_id64]
                return ResolvedPlayer(
                    nickname=nickname,
                    steam_id64=c.steam_id64,
                    profile_url=s.profile_url or c.profile_url,
                    avatar_url=s.avatar_url or c.avatar_url,
                    confidence=ResolveConfidence.EXACT,
                    source="steam_presence",
                    score=100,
                    reason="alias + CS2 gameserverip match",
                )

            playing_cs2 = [
                c for c in exact_alias
                if (s := by_id.get(c.steam_id64)) and s.game_id == "730"
            ]
            if len(playing_cs2) == 1:
                c = playing_cs2[0]
                s = by_id[c.steam_id64]
                return ResolvedPlayer(
                    nickname, c.steam_id64, s.profile_url or c.profile_url, s.avatar_url or c.avatar_url,
                    ResolveConfidence.HIGH, "steam_presence", 85, "unique exact alias currently in CS2",
                )

        if len(exact_alias) == 1:
            c = exact_alias[0]
            return ResolvedPlayer(
                nickname, c.steam_id64, c.profile_url, c.avatar_url,
                ResolveConfidence.POSSIBLE, "steam_search", 60, "unique exact alias; server presence unavailable",
            )

        return ResolvedPlayer(
            nickname, None, None, confidence=ResolveConfidence.NOT_FOUND,
            source="steam_search", score=0, reason="ambiguous alias",
        )
