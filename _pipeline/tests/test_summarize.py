import json
from pathlib import Path

from kb.paths import VaultPaths
from kb.state import State
from kb.summarize import (triage, summarize_item, load_examples, concept_index,
                          low_value_note)
from kb.notes import read_note, write_note

RAW_FM = dict(type="raw", source="tread", medium="video", id="vid1", title="Long toss and velo",
              url="https://www.youtube.com/watch?v=vid1", published="2026-08-01",
              author="Tread Athletics", duration_s=1157, caption_type="auto")
RAW_BODY = "# Long toss and velo\n\n## Transcript\n\n[00:00](https://youtu.be/vid1?t=0) we long toss to 300 feet and the cue is get the ball out early\n"

FULL_NOTE = """---
type: source
source: tread
medium: video
title: "Long toss and velo"
url: https://www.youtube.com/watch?v=vid1
published: 2026-08-01
author: Tread Athletics
duration_s: 1157
domain: [pitching]
kind: instruction
value: high
status: approved
raw: whatever/the/model/said.md
cues: [cue-get-the-ball-out-early]
concepts: [pitch-design-logic]
confidence: zac
---
# Long toss and velo

## TL;DR
- long toss to 300 ft

## Claims
- [00:00](https://youtu.be/vid1?t=0) 300 feet

## Cues
- **"get the ball out early"** - fixes late arm; for youth

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
    (p.pipeline / "prompts").mkdir(parents=True)
    (p.pipeline / "prompts" / "triage.md").write_text("TRIAGE", encoding="utf-8")
    (p.pipeline / "prompts" / "summarize.md").write_text("SUMMARIZE", encoding="utf-8")
    p.taxonomy.write_text("# taxonomy\n", encoding="utf-8")
    p.examples.mkdir()
    p.concepts.mkdir()
    write_note(p.concepts / "pitch-design-logic.md", dict(type="concept", domain="pitching"), "# PDL\n")
    write_note(p.raw_file("tread", "vid1"), RAW_FM, RAW_BODY)
    return p


def test_triage_parses_json_line():
    calls = []

    def fake(instruction, stdin, model):
        calls.append((instruction, model))
        return 'Sure!\n{"kind": "instruction", "domain": ["pitching", "strength"], "reason": "x"}\n'

    out = triage("TRIAGE", "tread", "t", "d", "body", run=fake)
    assert out == {"kind": "instruction", "domain": ["pitching", "strength"]}
    assert calls[0][1] == "haiku"


def test_triage_bad_json_returns_none():
    assert triage("T", "s", "t", "d", "b", run=lambda *a: "nope") is None


def test_summarize_item_full_path_forces_pipeline_fields(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="vid1", source="tread", medium="video", url=RAW_FM["url"], title=RAW_FM["title"],
                published="2026-08-01", raw=p.rel(p.raw_file("tread", "vid1"))))
    st.set_status("vid1", "fetched")
    models_seen = []

    def fake(instruction, stdin, model):
        models_seen.append(model)
        if model == "haiku":
            return '{"kind":"instruction","domain":["pitching"]}'
        assert "taxonomy" in stdin
        assert "pitch-design-logic" in stdin  # concept index offered
        assert "[00:00](https://youtu.be/vid1?t=0)" in stdin  # raw included
        return FULL_NOTE

    note_path = summarize_item(p, st, st.get("vid1"), run=fake)
    assert note_path.parent == p.review
    meta, body = read_note(note_path)
    assert meta["status"] == "pending"           # forced, model said approved
    assert meta["confidence"] == "agent"         # forced
    assert meta["raw"] == "sources/_raw/tread/vid1.md"  # forced to the real path
    assert meta["cues"] == ["cue-get-the-ball-out-early"]
    assert st.get("vid1")["status"] == "summarized"
    assert st.get("vid1")["note"] == "_review/2026-08-01-long-toss-and-velo.md"
    assert st.get("vid1")["proposal"]["kind"] == "instruction"
    assert models_seen == ["haiku", "sonnet"]


def test_summarize_item_marketing_skips_sonnet(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="vid1", source="tread", medium="video", url=RAW_FM["url"], title=RAW_FM["title"],
                published="2026-08-01", raw=p.rel(p.raw_file("tread", "vid1"))))
    st.set_status("vid1", "fetched")
    models = []

    def fake(instruction, stdin, model):
        models.append(model)
        return '{"kind":"marketing","domain":["business"]}'

    note_path = summarize_item(p, st, st.get("vid1"), run=fake)
    meta, body = read_note(note_path)
    assert models == ["haiku"]
    assert meta["kind"] == "marketing" and meta["value"] == "low"
    assert "## TL;DR" in body


def test_summarize_scope_exclusion_forces_skip(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="vid1", source="bpc", medium="video", url=RAW_FM["url"], title=RAW_FM["title"],
                published="2026-08-01", raw=p.rel(p.raw_file("tread", "vid1"))))
    st.set_status("vid1", "fetched")

    def fake(instruction, stdin, model):
        if model == "haiku":
            return '{"kind":"instruction","domain":["hitting"]}'
        return FULL_NOTE.replace("domain: [pitching]", "domain: [hitting]").replace("source: tread", "source: bpc")

    note_path = summarize_item(p, st, st.get("vid1"), run=fake, exclude_domains=["hitting"])
    meta, _ = read_note(note_path)
    assert meta["value"] == "skip"
    assert st.get("vid1")["status"] == "skipped"


def test_summarize_invalid_output_retries_once_then_fails(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="vid1", source="tread", medium="video", url=RAW_FM["url"], title=RAW_FM["title"],
                published="2026-08-01", raw=p.rel(p.raw_file("tread", "vid1"))))
    st.set_status("vid1", "fetched")
    n = {"sonnet": 0}

    def fake(instruction, stdin, model):
        if model == "haiku":
            return '{"kind":"research","domain":["pitching"]}'
        n["sonnet"] += 1
        return "no frontmatter here"

    out = summarize_item(p, st, st.get("vid1"), run=fake)
    assert out is None
    assert n["sonnet"] == 2
    assert st.get("vid1")["status"] == "failed"
    assert "frontmatter" in st.get("vid1")["error"]


def test_load_examples_newest_and_pinned(tmp_path):
    p = _vault(tmp_path)
    for i in range(20):
        write_note(p.examples / f"2026-01-{i+1:02d}-x.md",
                   dict(type="example", source="tread", pin=(i == 0)), f"ex {i}")
    write_note(p.examples / "2026-02-01-other.md", dict(type="example", source="driveline"), "other")
    txt = load_examples(p, "tread", n=3)
    assert "ex 19" in txt and "ex 18" in txt and "ex 17" in txt
    assert "ex 0" in txt          # pinned
    assert "ex 10" not in txt
    assert "other" not in txt


def test_concept_index_lists_slugs_and_domains(tmp_path):
    p = _vault(tmp_path)
    idx = concept_index(p)
    assert "pitch-design-logic (pitching)" in idx


def test_low_value_note_shape():
    meta, body = low_value_note(dict(id="v", source="tread", medium="video", url="u", title="T",
                                     published="2026-01-01"), RAW_FM, "sources/_raw/tread/v.md",
                                {"kind": "marketing", "domain": ["business"]})
    assert meta["value"] == "low" and meta["status"] == "pending" and meta["cues"] == []
    assert body.startswith("# Long toss and velo")  # raw title beats discover-time title
    assert "[[MOC-training-knowledge]]" in body


def test_run_claude_command_disables_tools_twice(monkeypatch):
    import kb.summarize as S
    seen = {}

    class R:
        returncode, stdout, stderr = 0, "ok", ""

    def fake_run(cmd, **kw):
        seen["cmd"] = cmd
        return R()

    monkeypatch.setattr(S.subprocess, "run", fake_run)
    S.run_claude("do", "text", "haiku")
    cmd = seen["cmd"]
    assert cmd[cmd.index("--tools") + 1] == ""
    assert "Write" in cmd[cmd.index("--disallowedTools") + 1]
    assert "--no-session-persistence" in cmd


def test_run_claude_uses_explicit_exe_and_sandbox_cwd(monkeypatch):
    import kb.summarize as S
    seen = {}

    class R:
        returncode, stdout, stderr = 0, "ok", ""

    def fake_run(cmd, **kw):
        seen["cmd"], seen["kw"] = cmd, kw
        return R()

    monkeypatch.setattr(S.subprocess, "run", fake_run)
    S.run_claude("do", "text", "haiku")
    assert seen["cmd"][0].lower().endswith("claude.exe") or seen["cmd"][0] == "claude"
    assert "bsb-kb-claude-sandbox" in seen["kw"]["cwd"]


def test_resummarize_overwrites_tracked_note(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="vid1", source="tread", medium="video", url=RAW_FM["url"], title=RAW_FM["title"],
                published="2026-08-01", raw=p.rel(p.raw_file("tread", "vid1"))))
    st.set_status("vid1", "fetched")
    p.review.mkdir(exist_ok=True)
    (p.review / "2026-08-01-old-slug.md").write_text("---\ntype: source\n---\n# old\n", encoding="utf-8")
    st.update("vid1", note="_review/2026-08-01-old-slug.md")

    def fake(instruction, stdin, model):
        return '{"kind":"instruction","domain":["pitching"]}' if model == "haiku" else FULL_NOTE

    out = summarize_item(p, st, st.get("vid1"), run=fake)
    assert out.name == "2026-08-01-old-slug.md"
    assert len(list(p.review.glob("*.md"))) == 1


def test_summarize_marketing_is_auto_filed_low_not_queued(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="vid1", source="tread", medium="video", url=RAW_FM["url"], title=RAW_FM["title"],
                published="2026-08-01", raw=p.rel(p.raw_file("tread", "vid1"))))
    st.set_status("vid1", "fetched")
    out = summarize_item(p, st, st.get("vid1"), run=lambda i, s, m: '{"kind":"marketing","domain":["business"]}')
    assert out.parent == p.low_dir("tread")
    meta, _ = read_note(out)
    assert meta["status"] == "auto-low" and meta["value"] == "low"
    assert st.get("vid1")["status"] == "filed-low"
    assert not list(p.review.glob("*.md"))


def test_rescue_forces_full_note_into_review(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="vid1", source="tread", medium="video", url=RAW_FM["url"], title=RAW_FM["title"],
                published="2026-08-01", raw=p.rel(p.raw_file("tread", "vid1"))))
    st.set_status("vid1", "fetched")
    low = summarize_item(p, st, st.get("vid1"), run=lambda i, s, m: '{"kind":"marketing","domain":["business"]}')
    assert low.exists()

    def fake(instruction, stdin, model):
        return '{"kind":"marketing","domain":["business"]}' if model == "haiku" else FULL_NOTE

    out = summarize_item(p, st, st.get("vid1"), run=fake, force_full=True)
    assert out.parent == p.review and not low.exists()
    assert st.get("vid1")["status"] == "summarized"


def test_summarize_skips_when_another_note_already_covers_the_raw(tmp_path):
    p = _vault(tmp_path)
    st = State.load(p.state)
    st.add(dict(id="vid1", source="tread", medium="video", url=RAW_FM["url"], title=RAW_FM["title"],
                published="2026-08-01", raw=p.rel(p.raw_file("tread", "vid1"))))
    st.set_status("vid1", "fetched")
    p.review.mkdir(exist_ok=True)
    write_note(p.review / "someone-elses-copy.md", dict(type="source", raw="sources/_raw/tread/vid1.md", url="x"), "# c\n")
    out = summarize_item(p, st, st.get("vid1"), run=lambda i, s, m: "should not be called")
    assert out is None
    assert st.get("vid1")["status"] == "duplicate"
    assert st.get("vid1")["duplicate_of"] == "_review/someone-elses-copy.md"
