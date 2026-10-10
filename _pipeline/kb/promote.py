"""Move reviewed notes out of _review/, wire cues/concepts/MOCs, record Zac's
corrections as examples, commit and push."""
from __future__ import annotations

import re
import shutil
import subprocess
from datetime import date, datetime, timezone
from pathlib import Path

from .notes import read_note, write_note
from .paths import VaultPaths
from .slug import cue_slug, drill_slug
from .state import State

REVIEWED = ("approved", "edited", "rejected", "duplicate")   # duplicate = rejected, logged as such
_CUE_LINE = re.compile(r'^\s*-\s*\*\*"(.+?)"\*\*\s*-\s*(.*)$')
_DRILL_LINE = re.compile(r'^\s*-\s*\*\*([^"*][^*]*?)\*\*\s*-\s*(.*)$')
_MOC_FOR = {"pitching": "MOC-pitching", "hitting": "MOC-hitting", "strength": "MOC-strength",
            "anatomy-movement": "MOC-anatomy"}


# --- pure helpers ------------------------------------------------------------

def parse_cues(body: str) -> list[dict]:
    """Bullets under ## Cues shaped `- **"phrase"** - fixes X; for Y`."""
    sec = re.search(r"## Cues\n(.*?)(?:\n## |\Z)", body, re.S)
    if not sec:
        return []
    out = []
    for line in sec.group(1).splitlines():
        m = _CUE_LINE.match(line)
        if not m:
            continue
        phrase, rest = m.group(1).strip(), m.group(2).strip()
        fixes, pop = rest, ""
        fm = re.match(r"fixes\s+(.*?)(?:;\s*for\s+(.*))?$", rest)
        if fm:
            fixes = fm.group(1).strip().rstrip(".")
            pop = (fm.group(2) or "").strip().rstrip(".")
        out.append(dict(phrase=phrase, fixes=fixes, population=pop))
    return out


def parse_drills(body: str) -> list[dict]:
    """Bullets under ## Drills shaped `- **Name** - setup; builds X; for Y`."""
    sec = re.search(r"## Drills\n(.*?)(?:\n## |\Z)", body, re.S)
    if not sec:
        return []
    out = []
    for line in sec.group(1).splitlines():
        m = _DRILL_LINE.match(line)
        if not m:
            continue
        name, rest = m.group(1).strip(), m.group(2).strip()
        setup, builds, pop = rest, "", ""
        bm = re.match(r"(.*?)(?:;\s*builds\s+(.*?))?(?:;\s*for\s+(.*))?$", rest)
        if bm:
            setup = (bm.group(1) or "").strip().rstrip(".")
            builds = (bm.group(2) or "").strip().rstrip(".")
            pop = (bm.group(3) or "").strip().rstrip(".")
        out.append(dict(name=name, setup=setup, builds=builds, population=pop))
    return out


def zac_section(body: str) -> str:
    m = re.search(r"## Zac\n(.*?)(?:\n## |\Z)", body, re.S)
    return (m.group(1).strip() if m else "")


def diff_proposal(proposal: dict, now: dict) -> dict:
    d = {}
    for k in ("domain", "kind", "value", "cues", "drills"):
        a, b = proposal.get(k), now.get(k)
        if k in ("domain", "cues", "drills"):        # an absent list field is an empty one (older proposals had no drills)
            a = sorted(map(str, a or []))
            b = sorted(map(str, b or []))
        if a != b:
            d[k] = (proposal.get(k), now.get(k))
    return d


def _section_append(text: str, heading: str, line: str) -> str:
    """Append `line` at the end of `## heading` (create the section if absent)."""
    if line in text:
        return text
    pat = re.compile(rf"(## {re.escape(heading)}\n)(.*?)(?=\n## |\Z)", re.S)
    m = pat.search(text)
    if not m:
        return text.rstrip("\n") + f"\n\n## {heading}\n{line}\n"
    block = m.group(2).rstrip("\n")
    new = f"{m.group(1)}{block}\n{line}\n" if block.strip() else f"{m.group(1)}{line}\n"
    return text[: m.start()] + new + text[m.end():]


# --- the pieces ------------------------------------------------------------------

def _upsert_cue(paths: VaultPaths, cue: dict, domain: str, note_stem: str) -> str:
    slug = cue_slug(cue["phrase"])
    p = paths.cues / f"{slug}.md"
    link = f"[[{note_stem}]]"
    phrasing = f'- "{cue["phrase"]}" - {link}'
    if p.exists():
        meta, body = read_note(p)
        srcs = [str(s) for s in (meta.get("sources") or [])]
        if link not in srcs:
            srcs.append(link)
        meta["sources"] = srcs
        if not meta.get("fixes") and cue["fixes"]:
            meta["fixes"] = cue["fixes"]
        body = _section_append(body, "Phrasings", phrasing)
    else:
        meta = dict(type="cue", domain=domain, phrase=cue["phrase"], fixes=cue["fixes"],
                    population=cue["population"], sources=[link], status="pending",
                    created=str(date.today()))
        body = (f"# {cue['phrase']}\n\n**Fixes:** {cue['fixes']}\n**For:** {cue['population'] or 'not stated'}\n\n"
                f"## Phrasings\n{phrasing}\n\n## Notes\n\n\n## Links\n[[MOC-training-knowledge]] [[{_MOC_FOR.get(domain, 'MOC-training-knowledge')}]]\n")
    write_note(p, meta, body)
    return slug


def _upsert_drill(paths: VaultPaths, drill: dict, domain: str, note_stem: str) -> str:
    slug = drill_slug(drill["name"])
    p = paths.drills / f"{slug}.md"
    link = f"[[{note_stem}]]"
    usage = f'- {drill["setup"] or drill["name"]}' + (f' (builds {drill["builds"]})' if drill["builds"] else "") + f" - {link}"
    if p.exists():
        meta, body = read_note(p)
        srcs = [str(s) for s in (meta.get("sources") or [])]
        if link not in srcs:
            srcs.append(link)
        meta["sources"] = srcs
        if not meta.get("builds") and drill["builds"]:
            meta["builds"] = drill["builds"]
        body = _section_append(body, "Used in", usage)
    else:
        meta = dict(type="drill", domain=domain, name=drill["name"], setup=drill["setup"],
                    builds=drill["builds"], population=drill["population"], sources=[link],
                    status="pending", created=str(date.today()))
        body = (f"# {drill['name']}\n\n**Setup:** {drill['setup'] or 'see source'}\n**Builds:** {drill['builds'] or 'not stated'}\n"
                f"**For:** {drill['population'] or 'not stated'}\n\n## Used in\n{usage}\n\n## Notes\n\n\n## Links\n"
                f"[[MOC-training-knowledge]] [[{_MOC_FOR.get(domain, 'MOC-training-knowledge')}]]\n")
    write_note(p, meta, body)
    return slug


def _link_concept(paths: VaultPaths, slug: str, note_stem: str, title: str) -> bool:
    p = paths.concepts / f"{slug}.md"
    if not p.exists():
        return False
    meta, body = read_note(p)
    body = _section_append(body, "From sources", f"- [[{note_stem}]] - {title}")
    write_note(p, meta, body)
    return True


def _link_moc(paths: VaultPaths, domain: str, note_stem: str, title: str, cue_slugs: list[str],
              drill_slugs: list[str] | None = None) -> None:
    name = _MOC_FOR.get(domain)
    if not name:
        return
    p = paths.root / f"{name}.md"
    if not p.exists():
        return
    text = p.read_text(encoding="utf-8")
    text = _section_append(text, "From sources", f"- [[{note_stem}]] - {title}")
    for c in cue_slugs:
        text = _section_append(text, "Cues", f"- [[{c}]]")
    for d in drill_slugs or []:
        text = _section_append(text, "Drills", f"- [[{d}]]")
    p.write_text(text, encoding="utf-8", newline="\n")


def _record_example(paths: VaultPaths, item: dict, meta: dict, body: str, changes: dict, zac: str) -> Path:
    stem = Path(item["note"]).stem
    raw_excerpt = ""
    rp = paths.root / item["raw"]
    if rp.exists():
        _, rb = read_note(rp)
        m = re.search(r"## Transcript\n\n(.*)", rb, re.S)
        raw_excerpt = (m.group(1) if m else rb)[:600].strip()
    lines = [f"# Correction on {stem}", "", f"Source: {item['source']} ({item['medium']}) - {meta.get('title')}", ""]
    for k, (a, b) in changes.items():
        lines.append(f"- **{k}**: {a} -> {b}")
    if zac:
        lines += ["", "Zac:", "", zac]
    lines += ["", "Raw excerpt:", "", "> " + raw_excerpt.replace("\n", "\n> ")]
    ex_meta = dict(type="example", source=item["source"], note=stem, pin=False,
                   created=datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    p = paths.examples / f"{date.today()}-{stem}.md"
    write_note(p, ex_meta, "\n".join(lines) + "\n")
    # also into the taxonomy's worked examples so a human sees the pattern
    tax = paths.taxonomy.read_text(encoding="utf-8")
    entry = f"- {date.today()} [[{stem}]]: " + "; ".join(f"{k} {a} -> {b}" for k, (a, b) in changes.items())
    if zac:
        entry += f" ({zac.splitlines()[0][:120]})"
    tax = _section_append(tax, "Worked examples", entry)
    paths.taxonomy.write_text(tax, encoding="utf-8", newline="\n")
    return p


LESSON_VALUES = ("high", "med")   # a reject of a low note agrees with the writer: nothing to learn


def is_lesson(item: dict) -> bool:
    return (item.get("proposal") or {}).get("value") in LESSON_VALUES


def record_rejection(paths: VaultPaths, item: dict, meta: dict, body: str, zac: str = "") -> Path:
    """A note Zac rejected, written where the summarizer reads its examples
    (`kind: rejection`, loaded beside the corrections, never instead of them)."""
    stem = Path(item["note"]).stem
    prop = item.get("proposal") or {}
    tldr = re.search(r"## TL;DR\n(.*?)(?:\n## |\Z)", body, re.S)
    lines = [f"# Rejected: {meta.get('title') or stem}", "",
             f"Source: {item['source']} ({item['medium']}). The writer proposed value {prop.get('value')}, "
             f"kind {prop.get('kind')}, domain {prop.get('domain')}.",
             "Zac REJECTED the whole note: content like this does not belong in the knowledge base. "
             "Rate similar content low.", ""]
    if zac:
        lines += ["Zac:", "", zac, ""]
    lines += ["What the writer said it covered:", "", (tldr.group(1).strip() if tldr else "(no TL;DR)")]
    ex_meta = dict(type="example", kind="rejection", source=item["source"], note=stem, pin=False,
                   created=datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    p = paths.examples / f"{date.today()}-rejected-{stem}.md"
    write_note(p, ex_meta, "\n".join(lines) + "\n")
    return p


def file_into_library(paths: VaultPaths, item: dict, meta: dict, body: str, stem: str) -> tuple[Path, list[Path], list[str], list[str]]:
    """Wire cues/drills/concepts/MOCs and write the note to sources/<source>/.
    Shared by Zac's approve and the model's auto-approve, so the two can never
    file a note differently. Returns (dest, touched, cue_slugs, drill_slugs);
    the caller removes the old file and updates state."""
    touched: list[Path] = []
    primary = (meta.get("domain") or ["pitching"])[0]
    cue_slugs, drill_slugs = [], []
    if meta.get("value") in ("high", "med"):
        for cue in parse_cues(body):
            cue_slugs.append(_upsert_cue(paths, cue, primary, stem))
            touched.append(paths.cues / f"{cue_slugs[-1]}.md")
        meta["cues"] = cue_slugs
        for drill in parse_drills(body):
            drill_slugs.append(_upsert_drill(paths, drill, primary, stem))
            touched.append(paths.drills / f"{drill_slugs[-1]}.md")
        meta["drills"] = drill_slugs
        for c in meta.get("concepts") or []:
            if _link_concept(paths, str(c), stem, meta.get("title", stem)):
                touched.append(paths.concepts / f"{c}.md")
    if meta.get("value") == "high":
        for d in meta.get("domain") or []:
            _link_moc(paths, d, stem, meta.get("title", stem), cue_slugs, drill_slugs)
            mp = paths.root / f"{_MOC_FOR.get(d, '')}.md"
            if mp.exists():
                touched.append(mp)
    dest = paths.sources / item["source"] / f"{stem}.md"
    write_note(dest, meta, body)
    touched.append(dest)
    return dest, touched, cue_slugs, drill_slugs


def _drop_link_lines(text: str, link: str) -> str:
    return "\n".join(l for l in text.split("\n") if link not in l)


def unwire_from_library(paths: VaultPaths, meta: dict, stem: str) -> list[Path]:
    """Undo file_into_library for one note (an auto-approve Zac overturned):
    take its [[stem]] out of every cue / drill / concept / MOC, and delete a cue
    or drill note that is left with no source at all. Returns files touched
    (deleted ones included, so git stages the deletion)."""
    link = f"[[{stem}]]"
    touched: list[Path] = []
    gone: list[str] = []
    for folder, slugs in ((paths.cues, meta.get("cues") or []), (paths.drills, meta.get("drills") or [])):
        for slug in slugs:
            p = folder / f"{slug}.md"
            if not p.exists():
                continue
            m, b = read_note(p)
            srcs = [str(s) for s in (m.get("sources") or []) if str(s) != link]
            if not srcs:
                p.unlink()
                gone.append(str(slug))
            else:
                m["sources"] = srcs
                write_note(p, m, _drop_link_lines(b, link))
            touched.append(p)
    for c in meta.get("concepts") or []:
        p = paths.concepts / f"{c}.md"
        if p.exists():
            m, b = read_note(p)
            write_note(p, m, _drop_link_lines(b, link))
            touched.append(p)
    for name in _MOC_FOR.values():
        p = paths.root / f"{name}.md"
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        new = _drop_link_lines(text, link)
        for slug in gone:
            new = _drop_link_lines(new, f"[[{slug}]]")
        if new != text:
            p.write_text(new, encoding="utf-8", newline="\n")
            touched.append(p)
    return touched


def _log(paths: VaultPaths, line: str) -> None:
    with open(paths.log, "a", encoding="utf-8", newline="\n") as f:
        f.write(f"- {datetime.now().strftime('%Y-%m-%d %H:%M')} {line}\n")


# --- git -----------------------------------------------------------------------

def git_commit_and_push(root: Path, paths_to_add: list[Path], message: str) -> bool:
    rel = [str(Path(p).resolve().relative_to(root.resolve())) for p in paths_to_add if Path(p).exists()]
    # A file this run DELETED (a note moved out of _review/, a cue an overturn
    # left with no source) is staged as a removal; skipping it would leave the
    # deletion uncommitted. --ignore-unmatch: never-tracked paths are a no-op.
    gone = [str(Path(p).resolve().relative_to(root.resolve())) for p in paths_to_add if not Path(p).exists()]
    if gone:
        subprocess.run(["git", "rm", "-q", "--cached", "--ignore-unmatch", "--"] + gone, cwd=root, capture_output=True)
    if not rel and not gone:
        return False
    if rel:
        subprocess.run(["git", "add", "--"] + rel, cwd=root, check=True, capture_output=True)
    r = subprocess.run(["git", "commit", "-q", "-m", message], cwd=root, capture_output=True, text=True)
    if r.returncode != 0:
        return False
    for remote in ("origin", "astros"):
        subprocess.run(["git", "push", "-q", remote, "HEAD"], cwd=root, capture_output=True)
    return True


# --- main --------------------------------------------------------------------------

def promote_all(paths: VaultPaths, state: State, git: bool = True) -> dict:
    res = {"promoted": 0, "rejected": 0, "examples": 0, "touched": []}
    by_note = {rec["note"]: rec for rec in state.data["items"].values() if rec.get("note")}
    for note in sorted(paths.review.glob("*.md")):
        try:
            meta, body = read_note(note)
        except ValueError:
            continue
        if meta.get("type") != "source" or meta.get("status") not in REVIEWED:
            continue
        rel = paths.rel(note)
        item = by_note.get(rel)
        if item is None and meta.get("raw"):
            # a copy Zac made by hand in Obsidian: adopt it by its raw path
            item = next((r for r in state.data["items"].values() if r.get("raw") == meta["raw"]), None)
            if item is not None:
                state.update(item["id"], note=rel)
        if item is None:
            _log(paths, f"promote: {rel} has no state record, left in place")
            continue
        stem = note.stem
        touched = [note]

        # corrections
        # Cues/drills come from the BODY, which is what Zac edits and what the
        # promotion below actually files -- NOT the frontmatter list, which the
        # agent wrote and he has no reason to hand-sync. Reading frontmatter here
        # made his most valuable correction invisible: on the plane-of-rotation
        # note (2026-09-08) he deleted two cues the source CRITICISES
        # ("get over the top", "get behind the ball" -- both named as causes of
        # injury), the body went 4 -> 2, the stale frontmatter still said 4, and
        # the diff reported no change. The tagger would never have learned it.
        now = dict(domain=meta.get("domain"), kind=meta.get("kind"), value=meta.get("value"),
                   cues=[cue_slug(c["phrase"]) for c in parse_cues(body)],
                   drills=[drill_slug(d["name"]) for d in parse_drills(body)])
        changes = diff_proposal(item.get("proposal") or {}, now)
        zac = zac_section(body)
        if meta["status"] == "rejected" and is_lesson(item):
            # A plain reject used to teach the writer nothing (99 approves and 42
            # rejects -> 1 correction, Oct 2026). A reject of a note the writer
            # rated high/med is exactly the disagreement it needs to see.
            touched.append(record_rejection(paths, item, meta, body, zac))
            res["examples"] += 1
        elif changes or zac:
            ex = _record_example(paths, item, meta, body, changes, zac)
            touched += [ex, paths.taxonomy]
            res["examples"] += 1

        meta["confidence"] = "zac"
        if meta["status"] in ("rejected", "duplicate"):
            dest = paths.sources / item["source"] / "_rejected" / note.name
            write_note(dest, meta, body)
            note.unlink()
            state.update(item["id"], note=paths.rel(dest))
            state.set_status(item["id"], "rejected")
            res["rejected"] += 1
            touched.append(dest)
            _log(paths, f"{meta['status']} {stem}")
            res["touched"] += touched
            continue

        dest, wired, cue_slugs, drill_slugs = file_into_library(paths, item, meta, body, stem)
        note.unlink()
        state.update(item["id"], note=paths.rel(dest))
        state.set_status(item["id"], "promoted")
        res["promoted"] += 1
        touched += wired
        _log(paths, f"promoted {stem} ({meta.get('kind')}/{meta.get('value')}, {len(cue_slugs)} cues, {len(drill_slugs)} drills"
                    + (", corrected" if changes or zac else "") + ")")
        res["touched"] += touched

    touched = list(dict.fromkeys(res["touched"])) + [paths.log, paths.state]
    if git and (res["promoted"] or res["rejected"]):
        state.save()
        git_commit_and_push(paths.root, touched,
                            f"kb: promote {res['promoted']} notes, {res['rejected']} rejected, {res['examples']} corrections")
    return res
