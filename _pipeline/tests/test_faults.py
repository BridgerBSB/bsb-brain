from kb.faults import collect, render_input, KNOWN_DOMAINS, write_proposal
from kb.notes import write_note
from kb.paths import VaultPaths


def _vault(tmp_path):
    p = VaultPaths(tmp_path)
    for d in (p.cues, p.drills, p.review):
        d.mkdir(parents=True, exist_ok=True)
    write_note(p.cues / "cue-stay-back.md",
               dict(type="cue", domain="hitting", phrase="stay back",
                    fixes="drifting onto the front side", sources=["[[s1]]"]), "# c\n")
    write_note(p.cues / "cue-get-the-ball-out.md",
               dict(type="cue", domain="pitching", phrase="get the ball out early",
                    fixes="late arm", sources=["[[s2]]"]), "# c\n")
    write_note(p.drills / "drill-step-behind.md",
               dict(type="drill", domain="hitting", name="Step behind",
                    builds="hinge and space to turn", sources=["[[s1]]"]), "# d\n")
    write_note(p.drills / "drill-rollings.md",
               dict(type="drill", domain="pitching", name="Rollings",
                    builds="identifies arm-path bias", sources=["[[s2]]"]), "# d\n")
    return p


def test_collect_partitions_by_domain(tmp_path):
    g = collect(_vault(tmp_path))
    assert set(g) == {"hitting", "pitching"}
    assert {i["slug"] for i in g["hitting"]} == {"cue-stay-back", "drill-step-behind"}
    assert {i["slug"] for i in g["pitching"]} == {"cue-get-the-ball-out", "drill-rollings"}
    assert {i["kind"] for i in g["hitting"]} == {"cue", "drill"}


def test_a_domains_model_input_cannot_contain_another_domain(tmp_path):
    """Zac, 2026-09-08: hitting and pitching faults are separate things. The
    model is called once per domain and is handed one domain's strings, so a
    cross-domain merge is not something it is asked to avoid -- it cannot see it."""
    g = collect(_vault(tmp_path))
    # without this the loop below has nothing to compare against and the test
    # passes vacuously -- which is exactly what a one-bucket regression looks like
    assert len(g) >= 2, f"expected a partition, got {list(g)}"
    for domain, items in g.items():
        block = render_input(items)
        for other, other_items in g.items():
            if other == domain:
                continue
            for it in other_items:
                assert it["slug"] not in block, f"{other} leaked into the {domain} call"
                assert it["fault"] not in block


def test_render_input_is_one_line_per_item_with_the_slug_verbatim(tmp_path):
    items = collect(_vault(tmp_path))["hitting"]
    lines = render_input(items).splitlines()
    assert len(lines) == 2
    for line in lines:
        assert line.count("\t") == 3
        assert line.split("\t")[0] in ("cue", "drill")


def test_proposal_is_written_only_into_review_and_names_its_domain(tmp_path):
    p = _vault(tmp_path)
    before = {f.name for f in p.cues.glob("*")} | {f.name for f in p.drills.glob("*")}
    out = write_proposal(p, "hitting", "## Drifting\n- `cue-stay-back` - stay back\n", 2)
    assert out.parent == p.review and "hitting" in out.name
    body = out.read_text(encoding="utf-8")
    assert "domain: hitting" in body and "Nothing has been filed" in body
    # the cue/drill layers are untouched
    assert before == {f.name for f in p.cues.glob("*")} | {f.name for f in p.drills.glob("*")}


def test_every_known_domain_is_a_taxonomy_value():
    assert "hitting" in KNOWN_DOMAINS and "pitching" in KNOWN_DOMAINS
