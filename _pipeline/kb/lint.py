"""Health checks over the training-knowledge zone. Reports; fixes nothing."""
from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path

from .notes import read_note
from .paths import VaultPaths
from .state import State

STUCK_RETRIES = 3
_LINK = re.compile(r"\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]")


def _all_note_stems(paths: VaultPaths) -> set[str]:
    stems = set()
    for f in paths.root.rglob("*.md"):
        parts = f.relative_to(paths.root).parts
        if parts[0] in (".git", ".obsidian", ".claude", "00-inbox") or parts[0].startswith("."):
            continue
        stems.add(f.stem)
        stems.add(f.relative_to(paths.root).with_suffix("").as_posix())
    return stems


def lint_vault(paths: VaultPaths, state: State) -> dict:
    rep = dict(orphan_cues=[], orphan_drills=[], sources_without_concepts=[], dangling_links=[], stuck=[],
               pending=0, heavy_concepts=[])
    stems = _all_note_stems(paths)

    for f in sorted(paths.cues.glob("*.md")) if paths.cues.exists() else []:
        try:
            meta, _ = read_note(f)
        except ValueError:
            continue
        if not meta.get("sources"):
            rep["orphan_cues"].append(f.stem)

    for f in sorted(paths.drills.glob("*.md")) if paths.drills.exists() else []:
        try:
            meta, _ = read_note(f)
        except ValueError:
            continue
        if not meta.get("sources"):
            rep["orphan_drills"].append(f.stem)

    concept_hits: dict[str, int] = {}
    for f in sorted(paths.sources.rglob("*.md")) if paths.sources.exists() else []:
        if "_raw" in f.parts or "_rejected" in f.parts:
            continue
        try:
            meta, body = read_note(f)
        except ValueError:
            continue
        if meta.get("type") != "source":
            continue
        if meta.get("value") in ("high", "med") and not meta.get("concepts"):
            rep["sources_without_concepts"].append(f.stem)
        for c in meta.get("concepts") or []:
            concept_hits[str(c)] = concept_hits.get(str(c), 0) + 1
        for link in _LINK.findall(body):
            link = link.strip()
            if link and link not in stems and not link.startswith("http"):
                rep["dangling_links"].append((f.stem, link))

    rep["heavy_concepts"] = sorted(c for c, n in concept_hits.items() if n >= 5)

    for rec in state.data["items"].values():
        if rec.get("status") == "failed" and rec.get("retries", 0) >= STUCK_RETRIES:
            rep["stuck"].append(rec["id"])
    rep["stuck"].sort()

    if paths.review.exists():
        for f in paths.review.glob("*.md"):
            try:
                meta, _ = read_note(f)
            except ValueError:
                continue
            if meta.get("type") == "source" and meta.get("status") == "pending":
                rep["pending"] += 1

    _write_failed(paths, state, rep["stuck"])
    rep["duplicates"] = _write_duplicates(paths, state)
    rep["auto_low"] = _write_auto_low(paths)
    return rep


def _source_notes(paths: VaultPaths):
    files = list(paths.review.glob("*.md")) if paths.review.exists() else []
    if paths.sources.exists():
        files += [f for f in paths.sources.rglob("*.md") if "_raw" not in f.parts]
    for f in files:
        try:
            meta, _ = read_note(f)
        except ValueError:
            continue
        if meta.get("type") == "source":
            yield f, meta


def _write_duplicates(paths: VaultPaths, state: State) -> int:
    """One place to see every duplicate: same raw, same url, or same source+title."""
    groups: dict[str, list[str]] = {}
    for f, m in _source_notes(paths):
        rel = f.relative_to(paths.root).as_posix()
        title = re.sub(r"[^a-z0-9]+", " ", str(m.get("title", "")).lower()).strip()
        for key in (f"raw:{m.get('raw')}", f"url:{m.get('url')}", f"title:{m.get('source')}:{title}"):
            groups.setdefault(key, [])
            if rel not in groups[key]:
                groups[key].append(rel)
    seen, lines, n_groups = set(), [], 0
    for key, files in groups.items():
        if len(files) < 2 or tuple(files) in seen:
            continue
        seen.add(tuple(files))
        n_groups += 1
        lines.append(f"- **{key.split(':', 1)[0]}** `{key.split(':', 1)[1]}`")
        lines += [f"  - [[{Path(x).stem}]] (`{x}`)" for x in files]
    dstate = [r for r in state.data["items"].values() if r.get("status") == "duplicate"]
    out = ["# Duplicates", "",
           f"Written by `kb.py lint` {datetime.now().strftime('%Y-%m-%d %H:%M')}. Notes that cover the same raw file, url, "
           "or the same title from one source. Keep ONE (grade it), set the rest to `duplicate`.", ""]
    out += lines or ["- none"]
    out += ["", f"## Caught before fetch ({len(dstate)})", ""]
    out += [f"- `{r['id']}` {r.get('title')} - duplicate of `{r.get('duplicate_of')}`" for r in dstate] or ["- none"]
    (paths.review / "duplicates.md").parent.mkdir(parents=True, exist_ok=True)
    (paths.review / "duplicates.md").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
    return n_groups


def _write_auto_low(paths: VaultPaths) -> int:
    """Titles the pipeline filed as low without review, newest first, so a wrong
    triage can be rescued: `python kb.py rescue --id=<id>`."""
    rows = []
    for f, m in _source_notes(paths):
        if m.get("status") == "auto-low":
            iid = Path(str(m.get("raw", ""))).stem
            rows.append((str(m.get("published") or ""), m.get("source"), m.get("kind"), m.get("title"), m.get("url"), iid))
    rows.sort(reverse=True)
    out = ["# Auto-filed as low value (not reviewed)", "",
           f"Written by `kb.py lint` {datetime.now().strftime('%Y-%m-%d %H:%M')}. Marketing and low-value items skip the queue. "
           "Skim the titles; if one deserves a full note, run `python _pipeline\\kb.py rescue --id=<id>`.", ""]
    out += [f"- {p} {s} {k}: {t} - {u} - id `{i}`" for p, s, k, t, u, i in rows] or ["- none"]
    (paths.review / "auto-low.md").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
    return len(rows)


def _write_failed(paths: VaultPaths, state: State, stuck: list[str]) -> None:
    lines = ["# Items that need a human", "",
             f"Written by `kb.py lint` {datetime.now().strftime('%Y-%m-%d %H:%M')}. "
             f"Each failed {STUCK_RETRIES}+ times. Fix the cause, then `kb.py retry --id <id>`.", ""]
    for iid in stuck:
        r = state.get(iid)
        lines.append(f"- `{iid}` {r.get('source')} {r.get('medium')} - {r.get('title')} - "
                     f"{r.get('url')} - **{r.get('error')}** (x{r.get('retries')})")
    if not stuck:
        lines.append("- none")
    paths.failed.parent.mkdir(parents=True, exist_ok=True)
    paths.failed.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def format_report(rep: dict) -> str:
    out = [f"pending in _review: {rep['pending']}",
           f"orphan cues: {len(rep['orphan_cues'])}, orphan drills: {len(rep['orphan_drills'])}",
           f"high/med sources with no concept link: {len(rep['sources_without_concepts'])}",
           f"dangling [[links]]: {len(rep['dangling_links'])}",
           f"stuck items (failed {STUCK_RETRIES}+): {len(rep['stuck'])}",
           f"duplicate groups: {rep.get('duplicates', 0)}; auto-filed low: {rep.get('auto_low', 0)}",
           f"concepts with 5+ sources (worth a contradiction pass): {', '.join(rep['heavy_concepts']) or 'none'}"]
    return "\n".join(out)
