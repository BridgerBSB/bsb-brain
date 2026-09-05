from kb.paths import VaultPaths
from kb.state import State
from kb.notes import write_note
from kb.lint import lint_vault


def _vault(tmp_path):
    p = VaultPaths(tmp_path)
    for d in (p.review, p.cues, p.concepts, p.sources / "tread", p.pipeline):
        d.mkdir(parents=True, exist_ok=True)
    return p


def test_lint_finds_orphan_cue_and_unlinked_source_and_dangling_links(tmp_path):
    p = _vault(tmp_path)
    write_note(p.cues / "cue-lonely.md", dict(type="cue", sources=[]), "# lonely\n")
    write_note(p.sources / "tread" / "2026-01-01-a.md",
               dict(type="source", source="tread", value="high", concepts=[], status="approved"),
               "# a\n\n[[nowhere-note]] [[MOC-pitching]]\n")
    (p.root / "MOC-pitching.md").write_text("# moc\n", encoding="utf-8")
    st = State.load(p.state)
    rep = lint_vault(p, st)
    assert "cue-lonely" in rep["orphan_cues"]
    assert "2026-01-01-a" in rep["sources_without_concepts"]
    assert ("2026-01-01-a", "nowhere-note") in rep["dangling_links"]
    assert not any(l == "MOC-pitching" for _, l in rep["dangling_links"])


def test_lint_writes_failed_md_for_stuck_items(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="x1", source="tread", medium="video", url="u", title="Stuck", published=None))
    for _ in range(3):
        st.set_status("x1", "failed", error="NoCaptions")
    st.add(dict(id="x2", source="tread", medium="video", url="u", title="Fine", published=None))
    st.set_status("x2", "failed", error="once")
    rep = lint_vault(p, st)
    assert rep["stuck"] == ["x1"]
    txt = p.failed.read_text(encoding="utf-8")
    assert "Stuck" in txt and "NoCaptions" in txt and "Fine" not in txt


def test_lint_review_queue_count(tmp_path):
    p = _vault(tmp_path)
    write_note(p.review / "n1.md", dict(type="source", status="pending"), "# n1\n")
    write_note(p.review / "n2.md", dict(type="source", status="approved"), "# n2\n")
    rep = lint_vault(p, State.load(p.state))
    assert rep["pending"] == 1
