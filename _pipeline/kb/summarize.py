"""Raw -> proposed source note in _review/, via headless `claude -p`.

Two passes: a cheap triage (Haiku) that picks kind + domain from the head of
the content, then the full note (Sonnet) only when the item is not marketing.
All model output is validated against the taxonomy before it touches the
vault, and the fields the pipeline owns (status, confidence, raw, source...)
are overwritten no matter what the model wrote.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from .notes import (parse_note_text, read_note, validate_source_meta, write_note,
                    KINDS, DOMAINS)
from .paths import VaultPaths
from .slug import note_name
from .state import State

MODELS = {"triage": "haiku", "full": "sonnet"}
NO_TOOLS = "Write,Edit,MultiEdit,NotebookEdit,Bash,Agent,Task,WebFetch,WebSearch,Read,Glob,Grep"
TRIAGE_HEAD_CHARS = 2000
MAX_RAW_CHARS = 120_000   # ~30k tokens; a 1 h video is ~60k chars


def claude_exe() -> str:
    """The current claude.exe, not whatever shim a scheduler's PATH finds first."""
    local = Path.home() / ".local" / "bin" / "claude.exe"
    return str(local) if local.exists() else (shutil.which("claude") or "claude")


_SANDBOX = Path(tempfile.gettempdir()) / "bsb-kb-claude-sandbox"


def run_claude(instruction: str, stdin_text: str, model: str) -> str:
    # Both flags on purpose: `--tools ""` is dropped somewhere between Python's
    # subprocess and the claude launcher on Windows (a Sonnet run WROTE its note
    # to sources/tread/ instead of printing it, 2026-09-04). A non-empty
    # --disallowedTools list cannot be dropped.
    cmd = [claude_exe(), "-p", instruction, "--model", model, "--output-format", "text",
           "--tools", "", "--disallowedTools", NO_TOOLS, "--no-session-persistence"]
    # cwd is a scratch dir OUTSIDE the vault: a model that writes a file anyway
    # (it happened twice, 2026-09-04 and 09-06) lands there, never in _review/.
    _SANDBOX.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(cmd, input=stdin_text, capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=900, cwd=str(_SANDBOX))
    if r.returncode != 0:
        raise RuntimeError(f"claude -p failed ({r.returncode}): {r.stderr[-400:]}")
    return r.stdout


# --- helpers -----------------------------------------------------------------

def _prompt(paths: VaultPaths, name: str) -> str:
    return (paths.prompts / f"{name}.md").read_text(encoding="utf-8")


def concept_index(paths: VaultPaths) -> str:
    lines = []
    for f in sorted(paths.concepts.glob("*.md")):
        try:
            meta, _ = read_note(f)
        except ValueError:
            continue
        lines.append(f"{f.stem} ({meta.get('domain', '?')})")
    return "\n".join(lines)


def load_examples(paths: VaultPaths, source: str, n: int = 15) -> str:
    """Newest n correction examples for the source, plus any pinned."""
    picked, pinned = [], []
    files = sorted(paths.examples.glob("*.md"), reverse=True)
    for f in files:
        try:
            meta, body = read_note(f)
        except ValueError:
            continue
        if meta.get("source") != source:
            continue
        if meta.get("pin"):
            pinned.append((f, body))
        elif len(picked) < n:
            picked.append((f, body))
    chosen = pinned + picked
    if not chosen:
        return "(no corrections recorded yet for this source)"
    return "\n\n".join(f"### {f.stem}\n{body.strip()}" for f, body in chosen)


def _split_raw(raw_text: str) -> tuple[dict, str, str]:
    """-> (meta, description, body-after-frontmatter)."""
    meta, body = parse_note_text(raw_text)
    desc = ""
    m = re.search(r"## Description\n\n(.*?)\n\n## ", body, re.S)
    if m:
        desc = m.group(1)
    return meta, desc, body


def triage(instruction: str, source: str, title: str, description: str, head: str, run=run_claude) -> dict | None:
    stdin = (f"source: {source}\ntitle: {title}\n\ndescription:\n{description[:1500]}\n\n"
             f"content head:\n{head[:TRIAGE_HEAD_CHARS]}\n")
    out = run(instruction, stdin, MODELS["triage"])
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            kind = d.get("kind")
            dom = d.get("domain")
            if kind in KINDS and isinstance(dom, list) and dom and all(x in DOMAINS for x in dom):
                return {"kind": kind, "domain": dom}
    return None


def low_value_note(item: dict, raw_meta: dict, raw_rel: str, tri: dict) -> tuple[dict, str]:
    title = raw_meta.get("title") or item.get("title") or "untitled"
    meta = dict(
        type="source", source=item["source"], medium=item["medium"], title=title,
        url=item["url"], published=raw_meta.get("published") or item.get("published"),
        author=raw_meta.get("author"), domain=tri["domain"], kind=tri["kind"], value="low",
        status="pending", raw=raw_rel, cues=[], drills=[], concepts=[], confidence="agent",
    )
    if item["medium"] == "video":
        meta["duration_s"] = raw_meta.get("duration_s") or item.get("duration_s")
    links = " ".join(["[[MOC-training-knowledge]]"] + [f"[[MOC-{_moc(d)}]]" for d in tri["domain"] if _moc(d)])
    body = (f"# {title}\n\n## TL;DR\n- {tri['kind']}; filed as low value by triage. "
            f"Raw kept at `{raw_rel}`.\n\n## Zac\n\n## Links\n{links}\n")
    return meta, body


def _save_failed_output(paths: VaultPaths, iid: str, attempt: int, out: str) -> None:
    d = paths.pipeline / "failed_outputs"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{iid}.{attempt}.txt").write_text(out, encoding="utf-8", newline=chr(10))


def _moc(domain: str) -> str | None:
    return {"pitching": "pitching", "hitting": "hitting", "strength": "strength",
            "anatomy-movement": "anatomy"}.get(domain)


# --- the main entry -----------------------------------------------------------

def existing_note_for(paths: VaultPaths, raw_rel: str, url: str, exclude: Path | None = None) -> Path | None:
    """A note anywhere in _review/ or sources/ that already covers this raw or url."""
    cands = list(paths.review.glob("*.md")) + list(paths.sources.glob("*/*.md")) + list(paths.sources.glob("*/_*/*.md"))
    for f in cands:
        if exclude and f.resolve() == Path(exclude).resolve():
            continue
        try:
            m, _ = read_note(f)
        except ValueError:
            continue
        if m.get("type") == "source" and (m.get("raw") == raw_rel or (url and m.get("url") == url)):
            return f
    return None


def summarize_item(paths: VaultPaths, state: State, item: dict, run=run_claude,
                   exclude_domains: list[str] | None = None, force_full: bool = False) -> Path | None:
    iid = item["id"]
    raw_path = paths.root / item["raw"]
    raw_text = raw_path.read_text(encoding="utf-8")
    raw_meta, description, raw_body = _split_raw(raw_text)
    raw_rel = paths.rel(raw_path)
    title = raw_meta.get("title") or item.get("title") or "untitled"

    prior = item.get("note")
    prior_path = (paths.root / prior) if prior else None
    dup = existing_note_for(paths, raw_rel, item.get("url"), exclude=prior_path)
    if dup is not None and not force_full:
        state.update(iid, duplicate_of=paths.rel(dup))
        state.set_status(iid, "duplicate")
        return None

    tri = triage(_prompt(paths, "triage"), item["source"], title, description, raw_body, run=run)
    if tri is None:
        tri = {"kind": "instruction", "domain": ["pitching"]}   # let Sonnet decide; still validated

    excluded = exclude_domains and any(d in exclude_domains for d in tri["domain"])

    if (tri["kind"] == "marketing" and not force_full) or excluded:
        meta, body = low_value_note(item, raw_meta, raw_rel, tri)
        if excluded:
            meta["value"] = "skip"
    else:
        instruction = _prompt(paths, "summarize")
        scope = f"Source scope: excludes domains {exclude_domains}\n" if exclude_domains else ""
        stdin = (
            f"# taxonomy\n\n{paths.taxonomy.read_text(encoding='utf-8')}\n\n"
            f"# past corrections for {item['source']}\n\n{load_examples(paths, item['source'])}\n\n"
            f"# existing concept slugs (link only these)\n\n{concept_index(paths)}\n\n"
            f"# triage says\n\nkind: {tri['kind']}\ndomain: {tri['domain']}\n{scope}\n"
            f"# raw path\n\n{raw_rel}\n\n"
            f"# raw\n\n{raw_text[:MAX_RAW_CHARS]}\n"
        )
        meta = body = None
        last_err = ""
        for attempt in range(2):
            instr = instruction if attempt == 0 else (
                instruction + chr(10) + chr(10)
                + "YOUR PREVIOUS REPLY HAD NO YAML FRONTMATTER. The very first line of your reply must be --- "
                "followed by the frontmatter keys, then --- again, then the body. No preamble.")
            out = run(instr, stdin, MODELS["full"])
            try:
                meta, body = parse_note_text(out)
            except ValueError as e:
                last_err = f"model output had no frontmatter: {e}"
                _save_failed_output(paths, iid, attempt, out)
                continue
            probs = validate_source_meta(meta, exclude_domains=exclude_domains)
            if probs:
                last_err = "schema: " + "; ".join(probs)
                meta = body = None
                continue
            break
        if meta is None:
            state.set_status(iid, "failed", error=last_err)
            return None

    # fields the pipeline owns
    meta.update(type="source", source=item["source"], medium=item["medium"], url=item["url"],
                raw=raw_rel, status="pending", confidence="agent")
    meta["title"] = title
    meta["published"] = raw_meta.get("published") or item.get("published")
    meta["author"] = raw_meta.get("author") or meta.get("author")
    if item["medium"] == "video":
        meta["duration_s"] = raw_meta.get("duration_s") or item.get("duration_s")
    for k in ("cues", "drills", "concepts"):
        meta[k] = [str(x) for x in (meta.get(k) or [])]
    if excluded:
        meta["value"] = "skip"

    # low-value notes never enter the queue: Zac rejected essentially all of them
    # (2026-09-06). They are filed under sources/<source>/_low/ with status auto-low,
    # listed in _review/auto-low.md by lint, and `kb.py rescue --id=` brings one back.
    auto_low = meta["value"] == "low" and not force_full
    if auto_low:
        meta["status"] = "auto-low"
    if prior and prior.startswith("_review/") and (paths.root / prior).exists() and not auto_low:
        out_path = paths.root / prior          # re-run: same file, no apostrophe-variant twins
    else:
        folder = paths.low_dir(item["source"]) if auto_low else paths.review
        out_path = folder / f"{note_name(meta['published'], title)}.md"
        if prior and (paths.root / prior).exists() and (paths.root / prior).resolve() != out_path.resolve():
            (paths.root / prior).unlink()      # moving from queue to _low on a rescue reversal, or vice versa
    write_note(out_path, meta, body)
    # Cues/drills recorded from the BODY, the same extractor promote uses. The
    # model writes the frontmatter list and the body separately and they can
    # disagree; comparing Zac's body edit against the model's frontmatter would
    # log a correction he never made (and miss ones he did).
    from .promote import parse_cues as _pc, parse_drills as _pd
    from .slug import cue_slug as _cs, drill_slug as _ds
    state.update(iid, note=paths.rel(out_path),
                 proposal=dict(domain=list(meta["domain"]), kind=meta["kind"], value=meta["value"],
                               cues=[_cs(c["phrase"]) for c in _pc(body)],
                               drills=[_ds(d["name"]) for d in _pd(body)]))
    state.set_status(iid, "skipped" if meta["value"] == "skip" else ("filed-low" if auto_low else "summarized"))
    return out_path
