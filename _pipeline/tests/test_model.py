"""Auto-decide: cutoffs, the training-set guard, decide, overturns, lessons.
A fake embedder keeps these DB- and download-free."""
import hashlib
import subprocess

import numpy as np
import pytest

from kb import model as M
from kb.notes import read_note, write_note
from kb.promote import promote_all
from kb.state import State
from kb.summarize import load_examples
from test_promote import NOTE_BODY, NOTE_META, _vault


def fake_embed(texts):
    """Deterministic 16-dim vector per text; texts sharing words land close."""
    out = []
    for t in texts:
        v = np.zeros(16)
        for w in t.lower().split():
            v[int(hashlib.md5(w.encode()).hexdigest(), 16) % 16] += 1.0
        out.append(v + 1e-6)
    return np.array(out)


class FixedModel:
    """Stands in for a trained Model: scores by a lookup on the note title."""
    def __init__(self, scores, t_approve=0.6, t_reject=0.3):
        self.scores, self.t_approve, self.t_reject = scores, t_approve, t_reject
        self.titles = []

    def score(self, Xn):
        return np.array([self.scores[t] for t in self.titles])

    def like(self, xn, k=3):
        return [("2026-01-01-some-graded-note", 1)]


# --- cutoffs -------------------------------------------------------------------

def test_cutoffs_respect_both_budgets():
    p = np.array([0.9, 0.85, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1])
    y = np.array([1,   1,    1,   1,   0,   1,   0,   0,   0,   0])
    t_a, t_r = M.cutoffs(p, y, approve_err=1 / 20, reject_err=1 / 50)
    assert t_a == 0.7          # 0.6 would let a reject into the approve zone
    assert t_r == 0.4          # 0.5 would put an approve into the reject zone


def test_cutoffs_off_when_no_zone_meets_budget():
    p = np.array([0.9, 0.8, 0.2, 0.1])
    y = np.array([0,   1,   0,   1])      # the most confident on each side is wrong
    assert M.cutoffs(p, y, 1 / 20, 1 / 50) == (None, None)


# --- the training-set guard (rule #19: the model never grades its own homework) --

def _graded_vault(tmp_path, n_each=6):
    p = _vault(tmp_path)
    st = State.load(p.state)
    for i in range(n_each * 2):
        approved = i < n_each
        iid = f"v{i}"
        folder = p.sources / "tread" if approved else p.sources / "tread" / "_rejected"
        stem = f"2026-08-{i + 1:02d}-note-{i}"
        word = "velocity arm drill" if approved else "recruiting parents college"
        write_note(folder / f"{stem}.md", dict(NOTE_META, title=f"{word} {i}", status="approved" if approved else "rejected",
                                               confidence="zac"), f"# t\n\n## TL;DR\n- {word} {word}\n")
        st.add(dict(id=iid, source="tread", medium="video", url=f"u{i}", title=f"t{i}", raw=f"sources/_raw/tread/{iid}.md"))
        st.update(iid, note=p.rel(folder / f"{stem}.md"), proposal=dict(value="high", kind="instruction", domain=["pitching"]))
        st.set_status(iid, "promoted" if approved else "rejected")
    return p, st


def test_training_rows_are_zacs_grades_only(tmp_path):
    p, st = _graded_vault(tmp_path)
    base = len(M.training_rows(p, st))
    assert base == 12
    # a model decision is never a label, by state OR by the note's confidence
    st.set_status("v0", "auto-promoted")
    assert len(M.training_rows(p, st)) == base - 1
    st.set_status("v0", "promoted")
    note = p.root / st.get("v1")["note"]
    m, b = read_note(note)
    write_note(note, dict(m, confidence="model"), b)
    assert len(M.training_rows(p, st)) == base - 1
    # a low-rated proposal is never asked about, so never trained on
    st.update("v2", proposal=dict(value="low"))
    assert len(M.training_rows(p, st)) == base - 2


def test_train_refuses_without_five_of_each(tmp_path):
    p, st = _graded_vault(tmp_path, n_each=4)
    model, why = M.train(M.training_rows(p, st), fake_embed)
    assert model is None and "need 5 of each" in why


def test_train_learns_separable_grades(tmp_path):
    p, st = _graded_vault(tmp_path, n_each=10)
    model, why = M.train(M.training_rows(p, st), fake_embed)
    assert why == "ok"
    assert model.report["auc"] > 0.9
    assert model.t_approve is not None


# --- decide --------------------------------------------------------------------

def _pending_note(p, st, iid, title, value="high"):
    stem = f"2026-08-01-{iid}"
    write_note(p.review / f"{stem}.md", dict(NOTE_META, title=title, value=value, raw=f"sources/_raw/tread/{iid}.md"), NOTE_BODY)
    st.add(dict(id=iid, source="tread", medium="video", url=f"https://x/{iid}", title=title, raw=f"sources/_raw/tread/{iid}.md"))
    st.update(iid, note=f"_review/{stem}.md", proposal=dict(value=value, kind="instruction", domain=["pitching"]))
    st.set_status(iid, "summarized")
    return stem


def _decide(p, st, scores):
    fm = FixedModel(scores)
    def embed(texts):
        fm.titles = [t.split("\n")[0] for t in texts]
        return fake_embed(texts)
    return M.decide_pending(p, st, fm, embed)


def test_decide_approves_rejects_and_leaves_the_middle(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    a = _pending_note(p, st, "a1", "approve me")
    r = _pending_note(p, st, "r1", "reject me", value="med")
    m_ = _pending_note(p, st, "m1", "unsure")
    res = _decide(p, st, {"approve me": 0.9, "reject me": 0.1, "unsure": 0.45})
    assert (res["approved"], res["rejected"], res["left"]) == (1, 1, 1)
    # approved: filed into the library exactly like Zac's approve (cues wired), marked as the model's
    dest = p.sources / "tread" / f"{a}.md"
    meta, _ = read_note(dest)
    assert meta["status"] == "auto-approved" and meta["confidence"] == "model" and meta["model_p"] == 0.9
    assert (p.cues / "cue-get-the-ball-out-early.md").exists()
    assert st.get("a1")["status"] == "auto-promoted"
    # rejected: in _rejected, not wired
    rmeta, _ = read_note(p.sources / "tread" / "_rejected" / f"{r}.md")
    assert rmeta["status"] == "auto-rejected" and st.get("r1")["status"] == "auto-rejected"
    # the middle stays with Zac
    assert (p.review / f"{m_}.md").exists() and st.get("m1")["status"] == "summarized"
    # and none of it is a training label
    assert M.training_rows(p, st) == []


# --- overturns -------------------------------------------------------------------

def test_overturned_auto_approve_is_unwired_rejected_and_becomes_a_lesson(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    a = _pending_note(p, st, "a1", "approve me")
    _decide(p, st, {"approve me": 0.9})
    cue = p.cues / "cue-get-the-ball-out-early.md"
    assert cue.exists() and f"[[{a}]]" in (p.root / "MOC-pitching.md").read_text(encoding="utf-8")
    # Zac overturns in Obsidian
    note = p.sources / "tread" / f"{a}.md"
    m, b = read_note(note)
    write_note(note, dict(m, status="rejected"), b)
    res = M.sweep_overturns(p, st)
    assert res["overturned"] == 1
    assert not cue.exists()                                   # its only source is gone
    moc = (p.root / "MOC-pitching.md").read_text(encoding="utf-8")
    assert f"[[{a}]]" not in moc and "[[cue-get-the-ball-out-early]]" not in moc
    _, concept = read_note(p.concepts / "pitch-design-logic.md")
    assert f"[[{a}]]" not in concept
    moved = p.sources / "tread" / "_rejected" / f"{a}.md"
    assert moved.exists() and read_note(moved)[0]["confidence"] == "zac"
    assert st.get("a1")["status"] == "rejected" and st.get("a1")["overturned"]
    assert list(p.examples.glob("*-rejected-*.md"))           # the writer learns from it
    assert len(M.training_rows(p, st)) == 1                   # and so does the model


def test_unwire_keeps_a_cue_another_source_still_uses(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    a = _pending_note(p, st, "a1", "approve me")
    _decide(p, st, {"approve me": 0.9})
    cue = p.cues / "cue-get-the-ball-out-early.md"
    cm, cb = read_note(cue)
    write_note(cue, dict(cm, sources=cm["sources"] + ["[[other-note]]"]), cb + '\n- "x" - [[other-note]]\n')
    note = p.sources / "tread" / f"{a}.md"
    m, b = read_note(note)
    write_note(note, dict(m, status="rejected"), b)
    M.sweep_overturns(p, st)
    cm2, cb2 = read_note(cue)
    assert cm2["sources"] == ["[[other-note]]"] and f"[[{a}]]" not in cb2


def test_overturned_auto_reject_goes_back_and_promotes_the_same_run(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    r = _pending_note(p, st, "r1", "reject me")
    _decide(p, st, {"reject me": 0.1})
    note = p.sources / "tread" / "_rejected" / f"{r}.md"
    m, b = read_note(note)
    write_note(note, dict(m, status="approved"), b)
    assert M.sweep_overturns(p, st)["overturned"] == 1
    assert (p.review / f"{r}.md").exists()
    promote_all(p, st, git=False)
    assert st.get("r1")["status"] == "promoted"
    assert read_note(p.sources / "tread" / f"{r}.md")[0]["confidence"] == "zac"


def test_confirming_an_auto_decision_makes_it_a_label(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    a = _pending_note(p, st, "a1", "approve me")
    _decide(p, st, {"approve me": 0.9})
    note = p.sources / "tread" / f"{a}.md"
    m, b = read_note(note)
    write_note(note, dict(m, status="approved"), b)
    assert M.sweep_overturns(p, st)["confirmed"] == 1
    assert st.get("a1")["status"] == "promoted" and len(M.training_rows(p, st)) == 1


# --- lessons for the writer ------------------------------------------------------

def _review_note(p, st, status, value):
    write_note(p.review / "2026-08-01-long-toss-and-velo.md", dict(NOTE_META, status=status), NOTE_BODY)
    st.add(dict(id="vid1", source="tread", medium="video", url="u", title="t", raw="sources/_raw/tread/vid1.md"))
    st.update("vid1", note="_review/2026-08-01-long-toss-and-velo.md",
              proposal=dict(value=value, kind="instruction", domain=["pitching"], cues=[]))
    st.set_status("vid1", "summarized")


def test_plain_reject_of_a_high_note_is_a_lesson(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    _review_note(p, st, "rejected", "high")
    promote_all(p, st, git=False)
    ex = list(p.examples.glob("*-rejected-*.md"))
    assert len(ex) == 1
    em, eb = read_note(ex[0])
    assert em["kind"] == "rejection" and "REJECTED" in eb and "long toss" in eb


def test_reject_of_a_low_note_teaches_nothing(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    _review_note(p, st, "rejected", "low")
    promote_all(p, st, git=False)
    assert not list(p.examples.glob("*-rejected-*.md"))


def test_rejections_never_crowd_out_corrections(tmp_path):
    p = _vault(tmp_path)
    for i in range(3):
        write_note(p.examples / f"2026-01-0{i + 1}-c{i}.md", dict(type="example", source="tread"), f"correction {i}")
    for i in range(30):
        write_note(p.examples / f"2026-09-{i + 1:02d}-rejected-r{i}.md",
                   dict(type="example", kind="rejection", source="tread"), f"rejection {i}")
    txt = load_examples(p, "tread", n=15, n_rejected=10)
    assert all(f"correction {i}" in txt for i in range(3))
    assert "rejection 29" in txt and "rejection 19" not in txt
    assert txt.index("correction 0") < txt.index("Notes Zac rejected outright")


def test_backfill_lessons_is_idempotent(tmp_path):
    p, st = _graded_vault(tmp_path)
    first = M.backfill_lessons(p, st)
    assert len(first) == 6                       # the 6 rejected high notes
    assert M.backfill_lessons(p, st) == []


# --- git: a deleted file is committed as a deletion -------------------------------

def test_commit_stages_deleted_files(tmp_path):
    from kb.promote import git_commit_and_push
    root = tmp_path
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=root, check=True)
    f = root / "cue.md"
    f.write_text("x", encoding="utf-8")
    subprocess.run(["git", "add", "cue.md"], cwd=root, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=root, check=True)
    f.unlink()
    assert git_commit_and_push(root, [f], "drop cue")
    tracked = subprocess.run(["git", "ls-files"], cwd=root, capture_output=True, text=True).stdout
    assert "cue.md" not in tracked
