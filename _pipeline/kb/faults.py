"""Fault layer -- one node per inefficiency, collecting the cues and drills
that address it.

Read-only against the vault. `propose` writes ONE file per domain into
_review/ and touches nothing else: no cue note, no drill note, no source
note, no MOC, no state. Filing a proposal is a separate, later step that
does not exist yet, on purpose.

DOMAIN SEPARATION IS STRUCTURAL (Zac, 2026-09-08: "those are separate --
hitting and pitching are different things"). The model is called once PER
DOMAIN and is handed only that domain's strings, so a cross-domain merge is
not something it is asked to avoid -- it is something it cannot see. The
partition is asserted in tests, not just documented.
"""
from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

from .notes import read_note
from .paths import VaultPaths

# every domain in taxonomy.md; a note whose domain is unknown is reported, never merged
KNOWN_DOMAINS = ("pitching", "hitting", "strength", "anatomy-movement", "mental", "business")


def _first_domain(meta: dict) -> str:
    d = meta.get("domain")
    if isinstance(d, list):
        d = d[0] if d else ""
    return str(d or "").strip()


def collect(paths: VaultPaths) -> dict[str, list[dict]]:
    """{domain: [{kind, slug, phrase, fault, sources}]} over cues/ and drills/."""
    out: dict[str, list[dict]] = defaultdict(list)
    for folder, kind, label_key, fault_key in (
        (paths.cues, "cue", "phrase", "fixes"),
        (paths.drills, "drill", "name", "builds"),
    ):
        if not folder.exists():
            continue
        for f in sorted(folder.glob("*.md")):
            try:
                meta, _ = read_note(f)
            except ValueError:
                continue
            fault = str(meta.get(fault_key) or "").strip()
            if not fault:
                continue
            out[_first_domain(meta)].append(dict(
                kind=kind, slug=f.stem, label=str(meta.get(label_key) or f.stem),
                fault=fault, sources=[str(s) for s in (meta.get("sources") or [])]))
    return dict(out)


def render_input(items: list[dict]) -> str:
    """The block handed to the model. One domain's strings only -- never a mix."""
    lines = []
    for it in items:
        lines.append(f'{it["kind"]}\t{it["slug"]}\t{it["label"]}\t{it["fault"]}')
    return "\n".join(lines)


def proposal_path(paths: VaultPaths, domain: str) -> Path:
    return paths.review / f"faults-proposal-{domain}.md"


def write_proposal(paths: VaultPaths, domain: str, body: str, n_items: int) -> Path:
    p = proposal_path(paths, domain)
    header = (
        "---\n"
        "type: faults-proposal\n"
        f"domain: {domain}\n"
        "status: pending\n"
        "---\n"
        f"# Proposed {domain} faults\n\n"
        f"Grouped from {n_items} cue/drill fault strings in the **{domain}** domain only.\n"
        "Nothing has been filed. This is a proposal to read and correct.\n\n"
        "Delete a group you disagree with, rename one, move a line between groups.\n"
        "Filing is a separate step that does not exist yet.\n\n")
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(header + body.strip() + "\n", encoding="utf-8", newline="\n")
    return p
