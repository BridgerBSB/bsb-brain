"""sources.yml access. One place decides which feeds are live.

A feed with `paused: true` is kept in the file (its notes, raw files and
state records stay) but discover finds nothing new for it, and fetch /
summarize leave its queued items untouched. `kb.py rescue` still works on a
paused source because that is an explicit human action.
"""
from __future__ import annotations

import yaml

from .paths import VaultPaths

_MEDIUM = {"youtube": "video"}          # everything else is a blog


def medium_for(kind: str) -> str:
    return _MEDIUM.get(kind, "blog")


def load_sources(paths: VaultPaths) -> dict:
    return yaml.safe_load(paths.sources_yml.read_text(encoding="utf-8"))["sources"]


def feeds_for(sources: dict, source: str | None, include_paused: bool = False) -> list[tuple[str, dict]]:
    """(key, feed) pairs for one source or all; paused feeds are dropped unless asked for."""
    out = []
    for k, f in sources.items():
        if source and f["source"] != source:
            continue
        if f.get("paused") and not include_paused:
            continue
        out.append((k, f))
    return out


def paused_media(sources: dict) -> set[tuple[str, str]]:
    """(source, medium) pairs whose feed is paused. State items carry source +
    medium, not the feed key, so this is the grain fetch/summarize filter on."""
    return {(f["source"], medium_for(f["kind"])) for f in sources.values() if f.get("paused")}


def drop_paused(items: list[dict], sources: dict) -> tuple[list[dict], int]:
    """Filter queued items for paused feeds. Returns (kept, n_skipped)."""
    paused = paused_media(sources)
    if not paused:
        return items, 0
    kept = [r for r in items if (r["source"], r["medium"]) not in paused]
    return kept, len(items) - len(kept)
