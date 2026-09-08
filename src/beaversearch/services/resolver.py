from __future__ import annotations

import asyncio
import re
import unicodedata
from difflib import SequenceMatcher

from ..domain import ResolveConfidence, ResolvedPlayer, ServerTarget
from .steam_community import CommunityCandidate, CommunityProfile, SteamCommunityClient
from .steam_webapi import SteamWebApiClient


def _norm(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold().strip()
    return re.sub(r"\s+", " ", value)


def _compact(value: str) -> str:
    return "".join(ch for ch in _norm(value) if ch.isalnum())


def _alias_score(query: str, candidate: str) -> int:
    q = _norm(query)
    c = _norm(candidate)
    if q == c:
        return 100
    qc = _compact(query)
    cc = _compact(candidate)
    if qc and qc == cc:
        return 96
    ratio = SequenceMatcher(None, q, c).ratio()
    if ratio >= 0.97:
        return 93
    if ratio >= 0.94:
        return 89
    return int(ratio * 80)


def _same_server(expected: ServerTarget, value: str | None) -> bool:
    if not value:
        return False
    value = value.strip().lower()
    host = expected.host.strip().lower()
    if value == expected.address.lower():
        return True
    return value == host or value.startswith(host + ":")


def _profile_is_cs2(profile: CommunityProfile | None) -> bool:
    if not profile:
        return False
    if profile.game_app_id == "730":
        return True
    name = _norm(profile.game_name or "")
    return name in {"counter-strike 2", "cs2"}


class SteamIdResolver:
    """Conservative free SteamID64 resolver for public CS2 servers.

    It never accepts a nickname-only match as HIGH/EXACT. The strongest path is
    Steam Web API presence with gameserverip. Without an API key, public Steam
    Community XML presence can still validate a unique exact/near-exact alias
    that is currently playing CS2.
    """

    def __init__(self, community: SteamCommunityClient, api: SteamWebApiClient | None = None) -> None:
        self.community = community
        self.api = api

    async def resolve(self, nickname: str, server: ServerTarget) -> ResolvedPlayer:
        candidates = await self.community.search_users(nickname, pages=1)
        if not candidates:
            return ResolvedPlayer(nickname, None, None, confidence=ResolveConfidence.NOT_FOUND, source="steam_search")

        ranked = self._rank(nickname, candidates)
        strong = [pair for pair in ranked if pair[0] >= 89]
        if not any(score >= 96 for score, _ in strong):
            more = await self.community.search_users(nickname, pages=2)
            merged = {c.steam_id64: c for c in candidates}
            merged.update({c.steam_id64: c for c in more})
            ranked = self._rank(nickname, list(merged.values()))
            strong = [pair for pair in ranked if pair[0] >= 89]

        if not strong:
            return ResolvedPlayer(
                nickname, None, None, confidence=ResolveConfidence.NOT_FOUND,
                source="steam_search", score=0, reason="no sufficiently close Steam alias",
            )

        pool = [c for _, c in strong[:25]]
        scores = {c.steam_id64: score for score, c in strong}

        if self.api and self.api.api_key:
            try:
                summaries = await self.api.summaries([c.steam_id64 for c in pool])
            except Exception:
                summaries = []
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
                    source="steam_presence_server",
                    score=100,
                    reason="Steam alias + CS2 gameserverip",
                )

            playing_cs2 = [
                c for c in pool
                if scores.get(c.steam_id64, 0) >= 96
                and (s := by_id.get(c.steam_id64))
                and s.game_id == "730"
            ]
            if len(playing_cs2) == 1:
                c = playing_cs2[0]
                s = by_id[c.steam_id64]
                return ResolvedPlayer(
                    nickname, c.steam_id64, s.profile_url or c.profile_url, s.avatar_url or c.avatar_url,
                    ResolveConfidence.HIGH, "steam_presence_cs2", scores[c.steam_id64],
                    "unique exact/normalized alias currently playing CS2",
                )

        profile_candidates = [c for c in pool if scores.get(c.steam_id64, 0) >= 96][:6]
        if profile_candidates:
            profiles = await asyncio.gather(
                *(self.community.profile(c.steam_id64) for c in profile_candidates),
                return_exceptions=True,
            )
            playing: list[tuple[CommunityCandidate, CommunityProfile]] = []
            for c, p in zip(profile_candidates, profiles):
                if isinstance(p, CommunityProfile) and _profile_is_cs2(p):
                    playing.append((c, p))
            if len(playing) == 1:
                c, p = playing[0]
                return ResolvedPlayer(
                    nickname, c.steam_id64, p.profile_url or c.profile_url, p.avatar_url or c.avatar_url,
                    ResolveConfidence.HIGH, "steam_community_presence", scores[c.steam_id64],
                    "unique exact/normalized alias currently playing CS2",
                )

        exact = [c for score, c in strong if score == 100]
        if len(exact) == 1:
            c = exact[0]
            return ResolvedPlayer(
                nickname, c.steam_id64, c.profile_url, c.avatar_url,
                ResolveConfidence.POSSIBLE, "steam_search", 60,
                "unique exact alias, but current server presence could not be proven",
            )

        return ResolvedPlayer(
            nickname, None, None, confidence=ResolveConfidence.NOT_FOUND,
            source="steam_search", score=0, reason="ambiguous alias",
        )

    @staticmethod
    def _rank(nickname: str, candidates: list[CommunityCandidate]) -> list[tuple[int, CommunityCandidate]]:
        ranked = [(_alias_score(nickname, c.nickname), c) for c in candidates]
        ranked.sort(key=lambda pair: pair[0], reverse=True)
        return ranked
