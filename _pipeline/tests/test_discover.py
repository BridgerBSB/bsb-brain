from pathlib import Path

from kb.discover import (parse_driveline_page, parse_tread_feed, parse_ytdlp_lines,
                         discover_items)
from kb.state import State

FX = Path(__file__).parent / "fixtures"


def test_parse_driveline_page_dedups_and_strips_query_and_fragment():
    html = (FX / "driveline_page1.html").read_text(encoding="utf-8")
    items = parse_driveline_page(html, base="https://drivelinebaseball.com")
    urls = [i["url"] for i in items]
    assert urls == [
        "https://drivelinebaseball.com/blogs/blog/michael-clarkson-juco-to-division-1",
        "https://drivelinebaseball.com/blogs/blog/vertical-slider-pitch-design",
        "https://drivelinebaseball.com/blogs/blog/bluffton-high-school-hitting-development",
    ]
    assert items[0]["id"] == "dl-blog-michael-clarkson-juco-to-division-1"
    assert items[0]["published"] == "2026-09-04"
    assert items[2]["published"] is None  # no <time> for that one


def test_parse_tread_feed_real_fixture():
    xml = (FX / "tread_feed.xml").read_text(encoding="utf-8")
    items = parse_tread_feed(xml)
    assert len(items) >= 5
    first = items[0]
    assert first["url"].startswith("https://treadathletics.com/")
    assert first["title"]
    assert len(first["published"]) == 10 and first["published"][4] == "-"
    assert first["id"].startswith("tread-blog-")


def test_parse_ytdlp_lines_handles_NA():
    text = (FX / "ytdlp_flat.txt").read_text(encoding="utf-8")
    items = parse_ytdlp_lines(text)
    assert [i["id"] for i in items] == ["jGwwwoAaRRs", "irF0epAy26k", "DRGDN8u1EKA"]
    assert items[0]["published"] == "2026-09-05"
    assert items[0]["duration_s"] == 467
    assert items[1]["published"] is None
    assert items[2]["duration_s"] is None
    assert items[0]["url"] == "https://www.youtube.com/watch?v=jGwwwoAaRRs"


def test_discover_items_adds_only_unseen(tmp_path):
    st = State.load(tmp_path / "s.json")
    feed = {"source": "driveline", "kind": "youtube"}
    found = [dict(id="a", title="A", url="u", published=None, duration_s=None),
             dict(id="b", title="B", url="u", published=None, duration_s=None)]
    n = discover_items(st, feed, found)
    assert n == 2
    n = discover_items(st, feed, found)
    assert n == 0
    assert st.get("a")["source"] == "driveline"
    assert st.get("a")["medium"] == "video"
    assert st.get("a")["feed"] == "youtube"


def test_parse_tread_archive_page_real_markup():
    from kb.discover import parse_tread_archive_page
    html = (FX / "tread_archive.html").read_text(encoding="utf-8")
    items = parse_tread_archive_page(html)
    assert [i["url"] for i in items] == ["https://treadathletics.com/2024-year-in-review",
                                         "https://treadathletics.com/2024-pro-day"]
    assert items[0]["title"] == "2024 Year In Review"
    assert items[0]["published"] == "2024-12-11"
    assert items[1]["title"] == "Tread HQ: Pro Day ’24 Recap"
    assert items[1]["id"] == "tread-blog-2024-pro-day"
