import json
from pathlib import Path

from kb.state import State


def _item(i="abc123", source="driveline", **kw):
    d = dict(id=i, source=source, medium="video", url=f"https://youtu.be/{i}",
             title="A video", published="2026-08-21")
    d.update(kw)
    return d


def test_add_and_get_sets_defaults(tmp_path):
    st = State.load(tmp_path / "state.json")
    st.add(_item())
    got = st.get("abc123")
    assert got["status"] == "new"
    assert got["retries"] == 0
    assert got["error"] is None
    assert got["added"]  # timestamp present


def test_add_is_idempotent(tmp_path):
    st = State.load(tmp_path / "state.json")
    st.add(_item())
    st.set_status("abc123", "fetched")
    st.add(_item(title="changed title"))  # second discover of the same id
    assert st.get("abc123")["status"] == "fetched"
    assert st.get("abc123")["title"] == "A video"


def test_failed_bumps_retries_and_keeps_error(tmp_path):
    st = State.load(tmp_path / "state.json")
    st.add(_item())
    st.set_status("abc123", "failed", error="NoCaptions")
    st.set_status("abc123", "failed", error="NoCaptions")
    got = st.get("abc123")
    assert got["retries"] == 2
    assert got["error"] == "NoCaptions"


def test_success_clears_error(tmp_path):
    st = State.load(tmp_path / "state.json")
    st.add(_item())
    st.set_status("abc123", "failed", error="boom")
    st.set_status("abc123", "fetched")
    assert st.get("abc123")["error"] is None


def test_by_status_filters_by_source(tmp_path):
    st = State.load(tmp_path / "state.json")
    st.add(_item("a1", "driveline"))
    st.add(_item("b2", "tread"))
    st.add(_item("c3", "driveline"))
    st.set_status("c3", "fetched")
    assert {i["id"] for i in st.by_status("new")} == {"a1", "b2"}
    assert {i["id"] for i in st.by_status("new", source="driveline")} == {"a1"}


def test_save_round_trips_and_is_atomic(tmp_path):
    p = tmp_path / "state.json"
    st = State.load(p)
    st.add(_item())
    st.save()
    assert p.exists()
    assert not list(tmp_path.glob("*.tmp"))
    again = State.load(p)
    assert again.get("abc123")["url"] == "https://youtu.be/abc123"
    raw = json.loads(p.read_text(encoding="utf-8"))
    assert "items" in raw and "abc123" in raw["items"]


def test_load_missing_file_is_empty(tmp_path):
    st = State.load(tmp_path / "nope.json")
    assert st.by_status("new") == []
