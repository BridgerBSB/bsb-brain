"""Auto-decide: approve / reject queue notes the way Zac would.

A logistic regression over a text embedding (title + TL;DR, bge-small via
fastembed, CPU) trained on Zac's own grades. It acts only where his past grades
say it is safe: the approve and reject cutoffs are re-derived every night from
out-of-fold predictions, against a fixed error budget. Everything between the
cutoffs stays in _review/ for him.

Design + the numbers it was built on:
projects/training-knowledge/2026-10-10-auto-decide-design.md

Two rules this module exists to keep:
- The model trains on ZAC'S grades only. Its own decisions (state auto-*,
  note confidence: model) never become labels, or it would grade its own
  homework and could only look better (blocking rule #19, tautological display).
- Zac overturns by editing `status:` on the note. sweep_overturns() turns that
  edit into a real grade before the next training run.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Callable

import numpy as np

from .notes import read_note, write_note
from .paths import VaultPaths
from .promote import (_log, file_into_library, is_lesson, record_rejection,
                      unwire_from_library)
from .state import State

APPROVE_ERR = 1 / 20     # of notes it auto-approves, at most this share would have been rejected by Zac
REJECT_ERR = 1 / 50      # of notes it auto-rejects, at most this share would have been approved by Zac
C = 1.0
CV_FOLDS = 5
CV_REPEATS = 20
LIKE_K = 3
DECIDABLE_VALUES = ("high", "med")   # low/skip never reach the queue
EMBED_MODEL = "BAAI/bge-small-en-v1.5"

Embed = Callable[[list[str]], np.ndarray]


# --- text + embedding ---------------------------------------------------------

def note_text(meta: dict, body: str) -> str:
    """What Zac reads first when he grades: the title and the TL;DR."""
    m = re.search(r"## TL;DR\n(.*?)(?:\n## |\Z)", body, re.S)
    return f"{meta.get('title') or ''}\n{m.group(1).strip() if m else ''}".strip()


def cache_dir(paths: VaultPaths) -> Path:
    return paths.pipeline / "model" / "cache"


def make_embedder(paths: VaultPaths) -> Embed:
    """fastembed with an on-disk vector cache keyed by text hash, so a night
    only embeds the notes it has not seen. The ONNX model lives in the same
    gitignored cache dir, so a run works offline after the first download."""
    os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")
    cdir = cache_dir(paths)
    cdir.mkdir(parents=True, exist_ok=True)
    cfile = cdir / "embeddings.json"
    cache: dict[str, list[float]] = json.loads(cfile.read_text(encoding="utf-8")) if cfile.exists() else {}
    engine = {}

    def embed(texts: list[str]) -> np.ndarray:
        keys = [hashlib.sha1(f"{EMBED_MODEL}\n{t}".encode("utf-8")).hexdigest() for t in texts]
        todo = [(k, t) for k, t in zip(keys, texts) if k not in cache]
        if todo:
            if "m" not in engine:
                from fastembed import TextEmbedding
                engine["m"] = TextEmbedding(EMBED_MODEL, cache_dir=str(cdir / "fastembed"))
            for (k, _), v in zip(todo, engine["m"].embed([t for _, t in todo])):
                cache[k] = [float(x) for x in v]
            cfile.write_text(json.dumps(cache), encoding="utf-8")
        return np.array([cache[k] for k in keys], dtype=float)

    return embed


# --- training set -------------------------------------------------------------

def training_rows(paths: VaultPaths, state: State) -> list[dict]:
    """Zac's grades only. state promoted/rejected (never auto-*), the note still
    says confidence: zac, and the writer had rated it high/med (the only notes
    the model is ever asked about)."""
    rows = []
    for rec in state.data["items"].values():
        if rec.get("status") not in ("promoted", "rejected") or not rec.get("note"):
            continue
        if (rec.get("proposal") or {}).get("value") not in DECIDABLE_VALUES:
            continue
        p = paths.root / rec["note"]
        if not p.exists():
            continue
        try:
            meta, body = read_note(p)
        except ValueError:
            continue
        if meta.get("confidence") != "zac":
            continue
        rows.append(dict(id=rec["id"], stem=p.stem, y=1 if rec["status"] == "promoted" else 0,
                         value=(rec.get("proposal") or {}).get("value"), text=note_text(meta, body)))
    rows.sort(key=lambda r: r["id"])   # stable order -> reproducible CV
    return rows


# --- cutoffs ------------------------------------------------------------------

def cutoffs(p: np.ndarray, y: np.ndarray, approve_err: float = APPROVE_ERR,
            reject_err: float = REJECT_ERR) -> tuple[float | None, float | None]:
    """Lowest approve cutoff whose zone (p >= t) holds at most approve_err
    rejects, and highest reject cutoff whose zone (p <= t) holds at most
    reject_err approves. None = no zone meets the budget, that side stays off."""
    p, y = np.asarray(p, float), np.asarray(y, int)
    t_a = t_r = None
    o = np.argsort(-p, kind="stable")
    for k in range(1, len(p) + 1):
        if 1 - y[o[:k]].mean() <= approve_err:
            t_a = float(p[o[k - 1]])
    o = np.argsort(p, kind="stable")
    for k in range(1, len(p) + 1):
        if y[o[:k]].mean() <= reject_err:
            t_r = float(p[o[k - 1]])
    if t_a is not None and t_r is not None and t_r >= t_a:
        t_r = None          # never let the zones overlap; approve wins, reject turns off
    return t_a, t_r


# --- the model ----------------------------------------------------------------

@dataclass
class Model:
    clf: object
    X: np.ndarray
    y: np.ndarray
    stems: list[str]
    t_approve: float | None
    t_reject: float | None
    report: dict = field(default_factory=dict)

    def score(self, Xn: np.ndarray) -> np.ndarray:
        return self.clf.predict_proba(Xn)[:, 1]

    def like(self, xn: np.ndarray, k: int = LIKE_K) -> list[tuple[str, int]]:
        """The k graded notes most similar to this one (cosine), with Zac's grade."""
        a = self.X / np.linalg.norm(self.X, axis=1, keepdims=True)
        b = xn / np.linalg.norm(xn)
        idx = np.argsort(-(a @ b), kind="stable")[:k]
        return [(self.stems[i], int(self.y[i])) for i in idx]


def train(rows: list[dict], embed: Embed) -> tuple[Model | None, str]:
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import roc_auc_score
    from sklearn.model_selection import RepeatedStratifiedKFold

    y = np.array([r["y"] for r in rows], int)
    n_pos, n_neg = int(y.sum()), int(len(y) - y.sum())
    if min(n_pos, n_neg) < CV_FOLDS:
        # A cross-validation requirement, not a quality gate: 5 folds need 5 of each.
        return None, f"cannot cross-validate: {n_pos} approved / {n_neg} rejected, need {CV_FOLDS} of each"
    X = embed([r["text"] for r in rows])
    mk = lambda: LogisticRegression(C=C, max_iter=5000, class_weight="balanced")
    P = np.zeros((CV_REPEATS, len(y)))
    cv = RepeatedStratifiedKFold(n_splits=CV_FOLDS, n_repeats=CV_REPEATS, random_state=11)
    for i, (tr, te) in enumerate(cv.split(X, y)):
        m = mk().fit(X[tr], y[tr])
        P[i // CV_FOLDS, te] = m.predict_proba(X[te])[:, 1]
    oof = P.mean(0)
    t_a, t_r = cutoffs(oof, y)
    is_high = np.array([1.0 if r["value"] == "high" else 0.0 for r in rows])
    med = is_high == 0
    rep = dict(
        n=len(y), approved=n_pos, rejected=n_neg,
        auc=float(np.mean([roc_auc_score(y, P[i]) for i in range(CV_REPEATS)])),
        auc_writer=float(roc_auc_score(y, is_high)) if 0 < is_high.sum() < len(y) else None,
        auc_med=float(roc_auc_score(y[med], oof[med])) if 0 < y[med].sum() < med.sum() else None,
        agree=float(np.mean((oof >= 0.5) == y)),
        agree_writer=float(np.mean(y == 1)),     # the writer sends every high/med note on as approvable
        t_approve=t_a, t_reject=t_r,
        zone_approve=int(np.sum(oof >= t_a)) if t_a is not None else 0,
        zone_approve_wrong=int(np.sum((oof >= t_a) & (y == 0))) if t_a is not None else 0,
        zone_reject=int(np.sum(oof <= t_r)) if t_r is not None else 0,
        zone_reject_wrong=int(np.sum((oof <= t_r) & (y == 1))) if t_r is not None else 0,
    )
    return Model(mk().fit(X, y), X, y, [r["stem"] for r in rows], t_a, t_r, rep), "ok"


# --- decide -------------------------------------------------------------------

def _pending(paths: VaultPaths, state: State) -> list[tuple[Path, dict, dict, str]]:
    by_note = {rec["note"]: rec for rec in state.data["items"].values() if rec.get("note")}
    out = []
    for note in sorted(paths.review.glob("*.md")):
        try:
            meta, body = read_note(note)
        except ValueError:
            continue
        if meta.get("type") != "source" or meta.get("status") != "pending":
            continue
        if meta.get("value") not in DECIDABLE_VALUES:
            continue
        rec = by_note.get(paths.rel(note))
        if rec is None:
            continue
        out.append((note, meta, rec, body))
    return out


def decide_pending(paths: VaultPaths, state: State, model: Model, embed: Embed,
                   dry_run: bool = False) -> dict:
    res = dict(approved=0, rejected=0, left=0, touched=[], rows=[])
    todo = _pending(paths, state)
    if not todo:
        return res
    Xn = embed([note_text(m, b) for _, m, _, b in todo])
    ps = model.score(Xn)
    for (note, meta, rec, body), xn, p in zip(todo, Xn, ps):
        p = float(p)
        like = model.like(xn)
        verdict = ("approve" if model.t_approve is not None and p >= model.t_approve else
                   "reject" if model.t_reject is not None and p <= model.t_reject else "left")
        res["rows"].append((verdict, p, meta.get("value"), meta.get("title"), like))
        if verdict == "left":
            res["left"] += 1
            continue
        if dry_run:
            res["approved" if verdict == "approve" else "rejected"] += 1
            continue
        stem = note.stem
        meta["confidence"] = "model"
        meta["model_p"] = p
        meta["model_like"] = [f"[[{s}]] ({'approved' if g else 'rejected'})" for s, g in like]
        if verdict == "approve":
            meta["status"] = "auto-approved"
            dest, wired, _, _ = file_into_library(paths, rec, meta, body, stem)
            res["touched"] += wired
            state.set_status(rec["id"], "auto-promoted")
            res["approved"] += 1
        else:
            meta["status"] = "auto-rejected"
            dest = paths.sources / rec["source"] / "_rejected" / note.name
            write_note(dest, meta, body)
            res["touched"].append(dest)
            state.set_status(rec["id"], "auto-rejected")
            res["rejected"] += 1
        note.unlink()
        res["touched"].append(note)
        state.update(rec["id"], note=paths.rel(dest), model_p=p)
        _log(paths, f"model {meta['status']} {stem} (p {p:.2f})")
    return res


# --- overturns ----------------------------------------------------------------

def sweep_overturns(paths: VaultPaths, state: State) -> dict:
    """Zac's edits to auto-decided notes become real grades."""
    res = dict(overturned=0, confirmed=0, touched=[])
    for rec in list(state.data["items"].values()):
        if rec.get("status") not in ("auto-promoted", "auto-rejected") or not rec.get("note"):
            continue
        note = paths.root / rec["note"]
        if not note.exists():
            _log(paths, f"model sweep: {rec['note']} missing, left as is")
            continue
        try:
            meta, body = read_note(note)
        except ValueError:
            continue
        st = meta.get("status")
        stem = note.stem
        if rec["status"] == "auto-promoted":
            if st == "rejected":
                res["touched"] += unwire_from_library(paths, meta, stem)
                meta["confidence"] = "zac"
                dest = paths.sources / rec["source"] / "_rejected" / note.name
                write_note(dest, meta, body)
                note.unlink()
                res["touched"] += [note, dest]
                state.update(rec["id"], note=paths.rel(dest), overturned=True)
                state.set_status(rec["id"], "rejected")
                if is_lesson(rec):
                    res["touched"].append(record_rejection(paths, rec, meta, body))
                res["overturned"] += 1
                _log(paths, f"model overturned: Zac rejected auto-approved {stem}")
            elif st in ("approved", "edited"):
                meta["confidence"] = "zac"
                write_note(note, meta, body)
                res["touched"].append(note)
                state.set_status(rec["id"], "promoted")
                res["confirmed"] += 1
                _log(paths, f"model confirmed: Zac approved auto-approved {stem}")
        else:  # auto-rejected
            if st in ("approved", "edited"):
                dest = paths.review / note.name
                write_note(dest, meta, body)       # status stays approved/edited -> promote files it this run
                note.unlink()
                res["touched"] += [note, dest]
                state.update(rec["id"], note=paths.rel(dest), overturned=True)
                state.set_status(rec["id"], "summarized")
                res["overturned"] += 1
                _log(paths, f"model overturned: Zac approved auto-rejected {stem}")
            elif st == "rejected":
                meta["confidence"] = "zac"
                write_note(note, meta, body)
                res["touched"].append(note)
                state.set_status(rec["id"], "rejected")
                if is_lesson(rec):
                    res["touched"].append(record_rejection(paths, rec, meta, body))
                res["confirmed"] += 1
                _log(paths, f"model confirmed: Zac rejected auto-rejected {stem}")
    return res


# --- the page Zac reads -------------------------------------------------------

def _pct(x: float | None) -> str:
    return "n/a" if x is None else f"{x * 100:.0f}%"


def _num(x: float | None) -> str:
    return "off" if x is None else f"{x:.2f}"


def write_page(paths: VaultPaths, state: State, model: Model | None, why: str, tonight: dict) -> Path:
    out = ["# Auto-decided notes", "",
           f"Written by `kb.py decide` {datetime.now().strftime('%Y-%m-%d %H:%M')}.", "",
           "**To overturn:** open the note and change `status:` to `rejected` (on an auto-approved note) "
           "or `approved` (on an auto-rejected one). The next nightly run files it and the model learns from it.", ""]
    if model is None:
        out += [f"Model not trained: {why}.", ""]
    else:
        r = model.report
        out += ["## Model", "",
                f"- Trained on **{r['n']}** of your grades ({r['approved']} approved / {r['rejected']} rejected), high and med notes only.",
                f"- Tested on your past grades (each note scored by a model that never saw it): agrees with you "
                f"**{_pct(r['agree'])}** of the time; passing every note as approvable would agree {_pct(r['agree_writer'])}.",
                f"- Ranks your approves above your rejects {_pct(r['auc'])} of the time (the writer's high/med rating: "
                f"{_pct(r['auc_writer'])}; on med notes alone, the model: {_pct(r['auc_med'])}).",
                f"- Auto-approves at p >= {_num(r['t_approve'])}: on your past grades that zone held {r['zone_approve']} notes, "
                f"{r['zone_approve_wrong']} of which you rejected (budget: 1 in {round(1 / APPROVE_ERR)}).",
                f"- Auto-rejects at p <= {_num(r['t_reject'])}: that zone held {r['zone_reject']} notes, "
                f"{r['zone_reject_wrong']} of which you approved (budget: 1 in {round(1 / REJECT_ERR)}).", ""]
    out += [f"**Last run:** auto-approved {tonight.get('approved', 0)}, auto-rejected {tonight.get('rejected', 0)}, "
            f"left for you {tonight.get('left', 0)}.", ""]
    items = state.data["items"].values()
    overturned = sum(1 for r in items if r.get("overturned"))
    out += [f"Overturned by you so far: {overturned}.", ""]
    for label, st in (("Auto-approved", "auto-promoted"), ("Auto-rejected", "auto-rejected")):
        recs = sorted((r for r in items if r.get("status") == st), key=lambda r: r.get("updated", ""), reverse=True)
        out += [f"## {label} ({len(recs)})", ""]
        for r in recs:
            stem = Path(r["note"]).stem
            like = ""
            try:
                m, _ = read_note(paths.root / r["note"])
                like = ", ".join(m.get("model_like") or [])
            except (ValueError, FileNotFoundError):
                pass
            out.append(f"- [[{stem}]] p {_num(r.get('model_p'))}" + (f" - like {like}" if like else ""))
        if not recs:
            out.append("- none")
        out.append("")
    page = paths.review / "auto-decided.md"
    page.parent.mkdir(parents=True, exist_ok=True)
    page.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
    return page


# --- one-time: lessons from rejects made before lessons existed ----------------

def backfill_lessons(paths: VaultPaths, state: State) -> list[Path]:
    have = set()
    for f in paths.examples.glob("*-rejected-*.md"):
        try:
            m, _ = read_note(f)
        except ValueError:
            continue
        have.add(m.get("note"))
    made = []
    for rec in state.data["items"].values():
        if rec.get("status") != "rejected" or not is_lesson(rec) or not rec.get("note"):
            continue
        p = paths.root / rec["note"]
        if p.stem in have or not p.exists():
            continue
        meta, body = read_note(p)
        made.append(record_rejection(paths, rec, meta, body, zac=""))
    return made
