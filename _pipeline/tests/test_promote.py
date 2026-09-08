from pathlib import Path

from kb.paths import VaultPaths
from kb.state import State
from kb.notes import read_note, write_note
from kb.promote import parse_cues, promote_all, diff_proposal

NOTE_META = dict(type="source", source="tread", medium="video", title="Long toss and velo",
                 url="https://www.youtube.com/watch?v=vid1", published="2026-08-01",
                 author="Tread Athletics", duration_s=1157, domain=["pitching"], kind="instruction",
                 value="high", status="pending", raw="sources/_raw/tread/vid1.md",
                 cues=["cue-get-the-ball-out-early"], concepts=["pitch-design-logic"], confidence="agent")
NOTE_BODY = """# Long toss and velo

## TL;DR
- long toss

## Claims
- [00:00](https://youtu.be/vid1?t=0) 300 feet

## Cues
- **"get the ball out early"** - fixes late arm; for youth
- **"ride the back leg"** - fixes early rotation

## Evidence cited
- none

## Open questions
- none

## Zac

## Links
[[MOC-training-knowledge]] [[MOC-pitching]] [[pitch-design-logic]]
"""


def _vault(tmp_path):
    p = VaultPaths(tmp_path)
    for d in (p.review, p.examples, p.cues, p.concepts, p.raw / "tread"):
        d.mkdir(parents=True, exist_ok=True)
    p.taxonomy.write_text("# taxonomy\n\n## Worked examples\n\n", encoding="utf-8")
    p.log.write_text("# log\n", encoding="utf-8")
    write_note(p.concepts / "pitch-design-logic.md", dict(type="concept", domain="pitching"), "# PDL\n\n## Links\n[[x]]\n")
    (p.root / "MOC-pitching.md").write_text("# MOC\n\n## From sources\n<!-- x -->\n\n## Cues\n<!-- y -->\n\n## Related\n", encoding="utf-8")
    write_note(p.raw_file("tread", "vid1"), dict(type="raw", source="tread"), "## Transcript\n\n[00:00](u) words words\n")
    return p


def _state(p, note_rel, proposal=None):
    st = State.load(p.state)
    st.add(dict(id="vid1", source="tread", medium="video", url=NOTE_META["url"], title=NOTE_META["title"],
                published="2026-08-01", raw="sources/_raw/tread/vid1.md"))
    st.set_status("vid1", "summarized")
    # body-derived, matching what summarize now stores: the model's frontmatter
    # list can drift from its own body, and only Zac's edits should read as corrections
    from kb.slug import cue_slug
    st.update("vid1", note=note_rel, proposal=proposal or dict(
        domain=["pitching"], kind="instruction", value="high",
        cues=[cue_slug(c["phrase"]) for c in parse_cues(NOTE_BODY)]))
    return st


def test_parse_cues_reads_phrase_fix_population():
    cues = parse_cues(NOTE_BODY)
    assert cues[0] == dict(phrase="get the ball out early", fixes="late arm", population="youth")
    assert cues[1] == dict(phrase="ride the back leg", fixes="early rotation", population="")


def test_diff_proposal_reports_changed_fields_only():
    prop = dict(domain=["pitching"], kind="instruction", value="high", cues=["a"])
    now = dict(domain=["pitching", "strength"], kind="instruction", value="med", cues=["a", "b"])
    d = diff_proposal(prop, now)
    assert set(d) == {"domain", "value", "cues"}
    assert d["value"] == ("high", "med")


def test_promote_pending_is_left_alone(tmp_path):
    p = _vault(tmp_path)
    note = p.review / "2026-08-01-long-toss-and-velo.md"
    write_note(note, NOTE_META, NOTE_BODY)
    st = _state(p, "_review/2026-08-01-long-toss-and-velo.md")
    res = promote_all(p, st, git=False)
    assert res["promoted"] == 0
    assert note.exists()


def test_promote_approved_moves_creates_cues_and_links(tmp_path):
    p = _vault(tmp_path)
    note = p.review / "2026-08-01-long-toss-and-velo.md"
    write_note(note, dict(NOTE_META, status="approved"), NOTE_BODY)
    st = _state(p, "_review/2026-08-01-long-toss-and-velo.md")
    res = promote_all(p, st, git=False)
    assert res["promoted"] == 1
    dest = p.sources / "tread" / "2026-08-01-long-toss-and-velo.md"
    assert dest.exists() and not note.exists()
    meta, _ = read_note(dest)
    assert meta["confidence"] == "zac" and meta["status"] == "approved"
    # cues: one note each, linked back
    c1 = p.cues / "cue-get-the-ball-out-early.md"
    assert c1.exists()
    cm, cb = read_note(c1)
    assert cm["phrase"] == "get the ball out early" and cm["domain"] == "pitching"
    assert "[[2026-08-01-long-toss-and-velo]]" in cb
    assert (p.cues / "cue-ride-the-back-leg.md").exists()
    # concept got a From sources bullet
    _, concept_body = read_note(p.concepts / "pitch-design-logic.md")
    assert "## From sources" in concept_body and "[[2026-08-01-long-toss-and-velo]]" in concept_body
    # MOC got the source and the cues
    moc = (p.root / "MOC-pitching.md").read_text(encoding="utf-8")
    assert "[[2026-08-01-long-toss-and-velo]]" in moc
    assert "[[cue-get-the-ball-out-early]]" in moc
    # no correction -> no example
    assert not list(p.examples.glob("*.md"))
    assert st.get("vid1")["status"] == "promoted"
    assert "long-toss" in p.log.read_text(encoding="utf-8")


def test_promote_edited_records_example_and_appends_taxonomy(tmp_path):
    p = _vault(tmp_path)
    note = p.review / "2026-08-01-long-toss-and-velo.md"
    body = NOTE_BODY.replace("## Zac\n", "## Zac\nthis is really a program pitch\n")
    write_note(note, dict(NOTE_META, status="edited", kind="marketing", value="low"), body)
    st = _state(p, "_review/2026-08-01-long-toss-and-velo.md")
    promote_all(p, st, git=False)
    ex = list(p.examples.glob("*.md"))
    assert len(ex) == 1
    em, eb = read_note(ex[0])
    assert em["source"] == "tread" and em["pin"] is False
    assert "instruction -> marketing" in eb
    assert "this is really a program pitch" in eb
    assert "words words" in eb  # raw excerpt
    tax = p.taxonomy.read_text(encoding="utf-8")
    assert "instruction -> marketing" in tax


def test_promote_rejected_goes_to_rejected_folder(tmp_path):
    p = _vault(tmp_path)
    note = p.review / "2026-08-01-long-toss-and-velo.md"
    write_note(note, dict(NOTE_META, status="rejected"), NOTE_BODY)
    st = _state(p, "_review/2026-08-01-long-toss-and-velo.md")
    promote_all(p, st, git=False)
    assert (p.sources / "tread" / "_rejected" / "2026-08-01-long-toss-and-velo.md").exists()
    assert not (p.cues / "cue-get-the-ball-out-early.md").exists()
    assert st.get("vid1")["status"] == "rejected"


def test_promote_second_source_appends_phrasing_to_existing_cue(tmp_path):
    p = _vault(tmp_path)
    write_note(p.cues / "cue-get-the-ball-out-early.md",
               dict(type="cue", domain="pitching", phrase="get the ball out early", fixes="late arm",
                    population="", sources=["[[older-note]]"], status="pending"),
               "# get the ball out early\n\n## Phrasings\n- \"get the ball out early\" - [[older-note]]\n\n## Links\n")
    note = p.review / "2026-08-01-long-toss-and-velo.md"
    write_note(note, dict(NOTE_META, status="approved"), NOTE_BODY)
    st = _state(p, "_review/2026-08-01-long-toss-and-velo.md")
    promote_all(p, st, git=False)
    cm, cb = read_note(p.cues / "cue-get-the-ball-out-early.md")
    assert cm["sources"] == ["[[older-note]]", "[[2026-08-01-long-toss-and-velo]]"]
    assert cb.count("[[older-note]]") == 1


def test_parse_drills_reads_setup_builds_population():
    from kb.promote import parse_drills
    body = ("# t\n\n## Cues\n- none given\n\n## Drills\n"
            "- **Step-behind long bat** - step-behind into contact with a long bat; builds holding space in the load; for hitters who drift\n"
            "- **Pivot picks** - pivot pick off the back foot\n\n## Evidence cited\n- none\n")
    d = parse_drills(body)
    assert d[0] == dict(name="Step-behind long bat", setup="step-behind into contact with a long bat",
                        builds="holding space in the load", population="hitters who drift")
    assert d[1] == dict(name="Pivot picks", setup="pivot pick off the back foot", builds="", population="")


def test_promote_creates_drill_notes_and_links_moc(tmp_path):
    p = _vault(tmp_path)
    (p.root / "MOC-hitting.md").write_text("# MOC\n\n## From sources\n\n## Cues\n\n## Drills\n\n## Related\n", encoding="utf-8")
    body = NOTE_BODY.replace("## Evidence cited", "## Drills\n- **Step-behind long bat** - long bat, step-behind; builds holding space; for drifters\n\n## Evidence cited")
    meta = dict(NOTE_META, status="approved", domain=["hitting"], drills=["drill-step-behind-long-bat"])
    note = p.review / "2026-08-01-long-toss-and-velo.md"
    write_note(note, meta, body)
    st = _state(p, "_review/2026-08-01-long-toss-and-velo.md")
    promote_all(p, st, git=False)
    d = p.drills / "drill-step-behind-long-bat.md"
    assert d.exists()
    dm, db = read_note(d)
    assert dm["name"] == "Step-behind long bat" and dm["builds"] == "holding space" and dm["domain"] == "hitting"
    assert "[[2026-08-01-long-toss-and-velo]]" in db
    moc = (p.root / "MOC-hitting.md").read_text(encoding="utf-8")
    assert "[[drill-step-behind-long-bat]]" in moc
    fm, _ = read_note(p.sources / "tread" / "2026-08-01-long-toss-and-velo.md")
    assert fm["drills"] == ["drill-step-behind-long-bat"]


def test_promote_adopts_hand_copied_note_by_raw_path(tmp_path):
    p = _vault(tmp_path)
    note = p.review / "tread-vid1-copy-zac-made.md"
    write_note(note, dict(NOTE_META, status="approved"), NOTE_BODY)
    st = _state(p, "_review/2026-08-01-long-toss-and-velo.md")   # state points at a name that no longer exists
    res = promote_all(p, st, git=False)
    assert res["promoted"] == 1
    assert (p.sources / "tread" / "tread-vid1-copy-zac-made.md").exists()
    assert st.get("vid1")["status"] == "promoted"


def test_deleting_a_cue_from_the_body_is_recorded_as_a_correction(tmp_path):
    """2026-09-08: the summarizer extracted two cues the source CRITICISES
    ("get over the top", "get behind the ball", both named as injury causes).
    Zac deleted them from the body and marked the note edited. The diff read
    the stale frontmatter list, saw 4 == 4, and recorded no correction -- so
    the tagger never learned the single thing most worth learning."""
    from kb.promote import parse_cues, diff_proposal
    from kb.slug import cue_slug

    body = (
        '## Cues\n'
        '- **"Unravel out"** - fixes disrespecting the plane; for pitchers\n'
        '- **"Let the pelvis just do the work"** - fixes muscling the arm up; for pitchers\n'
        '\n## Drills\n'
    )
    frontmatter_cues = ["cue-get-over-the-top", "cue-get-behind-the-ball",
                        "cue-unravel-out", "cue-let-the-pelvis-just-do-the-work"]
    proposal = {"domain": ["pitching"], "kind": "instruction", "value": "high",
                "cues": frontmatter_cues, "drills": []}

    from_body = [cue_slug(c["phrase"]) for c in parse_cues(body)]
    assert len(from_body) == 2, from_body

    # the old way: frontmatter, which nobody hand-syncs -> the deletion vanishes
    assert "cues" not in diff_proposal(proposal, {**proposal, "cues": frontmatter_cues})
    # the fixed way: the body, which is what Zac edits and what promote files
    changes = diff_proposal(proposal, {**proposal, "cues": from_body})
    assert "cues" in changes and len(changes["cues"][1]) == 2


def test_anti_cues_never_become_cue_notes(tmp_path):
    """2026-09-08: the summarizer put two cues the source CRITICISES under
    ## Cues, honestly worded ("meant to fix X; causes Y") -- but a cue note is
    read in cues/ on its own, with a fixes: field, so it reads as advice. They
    now go under ## Anti-cues, which the pipeline deliberately does not file."""
    p = _vault(tmp_path)
    body = NOTE_BODY.replace(
        "## Evidence cited",
        '## Anti-cues\n'
        '- **"Get over the top"** - taught to fix a low slot; actually causes '
        'shoulder climb and flexion stress; per Tread\n'
        '\n## Evidence cited', 1)
    note = p.review / "2026-08-01-long-toss-and-velo.md"
    write_note(note, dict(NOTE_META, status="approved"), body)
    promote_all(p, _state(p, "_review/2026-08-01-long-toss-and-velo.md"), git=False)

    assert not (p.cues / "cue-get-over-the-top.md").exists(), "an anti-cue was filed as a cue"
    assert (p.cues / "cue-get-the-ball-out-early.md").exists(), "real cues must still file"
    # the knowledge is kept on the source note, where the argument lives
    _, filed = read_note(p.sources / "tread" / "2026-08-01-long-toss-and-velo.md")
    assert "Get over the top" in filed and "## Anti-cues" in filed
    moc = (p.root / "MOC-pitching.md").read_text(encoding="utf-8")
    assert "[[cue-get-over-the-top]]" not in moc
