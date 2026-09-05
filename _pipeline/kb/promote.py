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
from .slug import cue_slug
from .state import State

REVIEWED = ("approved", "edited", "rejected")
_CUE_LINE = re.compile(r'^\s*-\s*\*\*"(.+?)"\*\*\s*-\s*(.*)$')
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


def zac_section(body: str) -> str:
    m = re.search(r"## Zac\n(.*?)(?:\n## |\Z)", body, re.S)
    return (m.group(1).strip() if m else "")


def diff_proposal(proposal: dict, now: dict) -> dict:
    d = {}
    for k in ("domain", "kind", "value", "cues"):
        a, b = proposal.get(k), now.get(k)
        if isinstance(a, list):
            a = sorted(map(str, a))
        if isinstance(b, list):
            b = sorted(map(str, b))
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


def _link_concept(paths: VaultPaths, slug: str, note_stem: str, title: str) -> bool:
    p = paths.concepts / f"{slug}.md"
    if not p.exists():
        return False
    meta, body = read_note(p)
    body = _section_append(body, "From sources", f"- [[{note_stem}]] - {title}")
    write_note(p, meta, body)
    return True


def _link_moc(paths: VaultPaths, domain: str, note_stem: str, title: str, cue_slugs: list[str]) -> None:
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


def _log(paths: VaultPaths, line: str) -> None:
    with open(paths.log, "a", encoding="utf-8", newline="\n") as f:
        f.write(f"- {datetime.now().strftime('%Y-%m-%d %H:%M')} {line}\n")


# --- git -----------------------------------------------------------------------

def git_commit_and_push(root: Path, paths_to_add: list[Path], message: str) -> bool:
    rel = [str(Path(p).resolve().relative_to(root.resolve())) for p in paths_to_add if Path(p).exists()]
    if not rel:
        return False
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
        if item is None:
            _log(paths, f"promote: {rel} has no state record, left in place")
            continue
        stem = note.stem
        touched = [note]

        # corrections
        now = dict(domain=meta.get("domain"), kind=meta.get("kind"), value=meta.get("value"),
                   cues=meta.get("cues") or [])
        changes = diff_proposal(item.get("proposal") or {}, now)
        zac = zac_section(body)
        if changes or zac:
            ex = _record_example(paths, item, meta, body, changes, zac)
            touched += [ex, paths.taxonomy]
            res["examples"] += 1

        meta["confidence"] = "zac"
        if meta["status"] == "rejected":
            dest = paths.sources / item["source"] / "_rejected" / note.name
            write_note(dest, meta, body)
            note.unlink()
            state.update(item["id"], note=paths.rel(dest))
            state.set_status(item["id"], "rejected")
            res["rejected"] += 1
            touched.append(dest)
            _log(paths, f"rejected {stem}")
            res["touched"] += touched
            continue

        # cues + concepts + MOCs
        primary = (meta.get("domain") or ["pitching"])[0]
        cue_slugs = []
        if meta.get("value") in ("high", "med"):
            for cue in parse_cues(body):
                cue_slugs.append(_upsert_cue(paths, cue, primary, stem))
                touched.append(paths.cues / f"{cue_slugs[-1]}.md")
            meta["cues"] = cue_slugs
            for c in meta.get("concepts") or []:
                if _link_concept(paths, str(c), stem, meta.get("title", stem)):
                    touched.append(paths.concepts / f"{c}.md")
        if meta.get("value") == "high":
            for d in meta.get("domain") or []:
                _link_moc(paths, d, stem, meta.get("title", stem), cue_slugs)
                mp = paths.root / f"{_MOC_FOR.get(d, '')}.md"
                if mp.exists():
                    touched.append(mp)

        dest = paths.sources / item["source"] / note.name
        write_note(dest, meta, body)
        note.unlink()
        state.update(item["id"], note=paths.rel(dest))
        state.set_status(item["id"], "promoted")
        res["promoted"] += 1
        touched.append(dest)
        _log(paths, f"promoted {stem} ({meta.get('kind')}/{meta.get('value')}, {len(cue_slugs)} cues"
                    + (", corrected" if changes or zac else "") + ")")
        res["touched"] += touched

    touched = list(dict.fromkeys(res["touched"])) + [paths.log, paths.state]
    if git and (res["promoted"] or res["rejected"]):
        state.save()
        git_commit_and_push(paths.root, touched,
                            f"kb: promote {res['promoted']} notes, {res['rejected']} rejected, {res['examples']} corrections")
    return res
