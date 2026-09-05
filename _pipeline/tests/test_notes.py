from kb.notes import read_note, write_note, validate_source_meta, parse_note_text


GOOD = dict(type="source", source="driveline", medium="video", title="T",
            url="https://youtu.be/x", published="2026-08-21", author="Driveline Baseball",
            duration_s=467, domain=["pitching"], kind="instruction", value="high",
            status="pending", raw="sources/_raw/driveline/x.md", cues=[], concepts=[],
            confidence="agent")


def test_write_then_read_round_trip(tmp_path):
    p = tmp_path / "n.md"
    write_note(p, GOOD, "# T\n\nbody\n")
    meta, body = read_note(p)
    assert meta["domain"] == ["pitching"]
    assert meta["duration_s"] == 467
    assert body.strip().startswith("# T")


def test_write_note_uses_lf_and_utf8(tmp_path):
    p = tmp_path / "n.md"
    write_note(p, GOOD, "café ″\n")
    raw = p.read_bytes()
    assert b"\r\n" not in raw
    assert "café".encode("utf-8") in raw


def test_validate_good_is_clean():
    assert validate_source_meta(GOOD) == []


def test_validate_reports_missing_and_bad_values():
    bad = dict(GOOD)
    del bad["url"]
    bad["kind"] = "sermon"
    bad["domain"] = ["pitching", "golf"]
    bad["value"] = "amazing"
    probs = validate_source_meta(bad)
    joined = " ".join(probs)
    assert "url" in joined
    assert "kind" in joined
    assert "golf" in joined
    assert "value" in joined


def test_validate_domain_must_be_list():
    bad = dict(GOOD, domain="pitching")
    assert any("domain" in p for p in validate_source_meta(bad))


def test_validate_scope_forces_skip():
    m = dict(GOOD, source="bpc", domain=["hitting"])
    probs = validate_source_meta(m, exclude_domains=["hitting"])
    assert probs == []  # not an error...
    assert m["value"] == "skip"  # ...but value is forced


def test_parse_note_text_handles_code_fence_wrapper():
    text = "```markdown\n---\ntype: source\ntitle: X\n---\n# X\n```\n"
    meta, body = parse_note_text(text)
    assert meta["title"] == "X"
    assert body.strip() == "# X"


def test_parse_note_text_without_frontmatter_raises():
    import pytest
    with pytest.raises(ValueError):
        parse_note_text("just prose")
