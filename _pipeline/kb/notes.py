"""Read / write / validate vault notes (YAML frontmatter + markdown body)."""
from __future__ import annotations

import re
from pathlib import Path

import frontmatter
import yaml

DOMAINS = ("pitching", "hitting", "strength", "anatomy-movement", "mental", "business")
KINDS = ("instruction", "philosophy", "research", "interview", "athlete-story", "marketing")
VALUES = ("high", "med", "low", "skip")
STATUSES = ("pending", "approved", "edited", "rejected")
REQUIRED = ("type", "source", "medium", "title", "url", "published", "domain",
            "kind", "value", "status", "raw", "cues", "concepts", "confidence")

_FENCE = re.compile(r"^\s*```[a-zA-Z]*\s*\n(.*?)\n\s*```\s*$", re.S)


class _Dumper(yaml.SafeDumper):
    pass


def _represent_str(dumper, data):
    if any(ch in data for ch in ":#[]{}\"'\n") or data.strip() != data or data == "":
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style='"')
    return dumper.represent_scalar("tag:yaml.org,2002:str", data)


_Dumper.add_representer(str, _represent_str)


def dump_meta(meta: dict) -> str:
    return yaml.dump(meta, Dumper=_Dumper, sort_keys=False, allow_unicode=True,
                     default_flow_style=None, width=1000).rstrip("\n")


def parse_note_text(text: str) -> tuple[dict, str]:
    """Split note text into (meta, body). Tolerates a ``` wrapper."""
    m = _FENCE.match(text)
    if m:
        text = m.group(1)
    text = text.lstrip("﻿ \n")
    if not text.startswith("---"):
        raise ValueError("note has no frontmatter")
    post = frontmatter.loads(text)
    if not post.metadata:
        raise ValueError("note frontmatter is empty")
    return dict(post.metadata), post.content


def read_note(path: Path) -> tuple[dict, str]:
    return parse_note_text(Path(path).read_text(encoding="utf-8"))


def write_note(path: Path, meta: dict, body: str) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = f"---\n{dump_meta(meta)}\n---\n{body.rstrip()}\n"
    path.write_text(text, encoding="utf-8", newline="\n")


def validate_source_meta(meta: dict, exclude_domains: list[str] | None = None) -> list[str]:
    """Return a list of problems (empty = valid). Mutates meta in one case:
    a domain the source's scope excludes forces value: skip."""
    probs = []
    for k in REQUIRED:
        if k not in meta or meta[k] is None:
            probs.append(f"missing {k}")
    dom = meta.get("domain")
    if not isinstance(dom, list):
        probs.append("domain must be a list")
        dom = []
    for d in dom:
        if d not in DOMAINS:
            probs.append(f"unknown domain {d!r}")
    if meta.get("kind") not in KINDS:
        probs.append(f"bad kind {meta.get('kind')!r}")
    if meta.get("value") not in VALUES:
        probs.append(f"bad value {meta.get('value')!r}")
    if meta.get("status") not in STATUSES:
        probs.append(f"bad status {meta.get('status')!r}")
    for k in ("cues", "concepts"):
        if k in meta and meta[k] is not None and not isinstance(meta[k], list):
            probs.append(f"{k} must be a list")
    if exclude_domains and any(d in exclude_domains for d in dom):
        meta["value"] = "skip"
    return probs
