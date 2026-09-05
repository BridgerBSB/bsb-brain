from pathlib import Path

import pytest

from kb.fetch_video import segments_to_markdown, pick_transcript, NoCaptions
from kb.fetch_blog import extract_article, rewrite_image_links

FX = Path(__file__).parent / "fixtures"


class _Seg:
    def __init__(self, text, start, duration=2.0):
        self.text, self.start, self.duration = text, start, duration


def test_segments_to_markdown_groups_into_paragraphs_with_links():
    segs = [_Seg("hello", 0.0), _Seg("world", 3.0), _Seg("later", 75.0), _Seg("still", 80.0)]
    md = segments_to_markdown(segs, "abc", window_s=60)
    paras = [p for p in md.split("\n\n") if p.strip()]
    assert len(paras) == 2
    assert paras[0].startswith("[00:00](https://youtu.be/abc?t=0) hello world")
    assert paras[1].startswith("[01:15](https://youtu.be/abc?t=75) later still")


def test_segments_to_markdown_hours():
    md = segments_to_markdown([_Seg("x", 3725.0)], "abc")
    assert md.startswith("[1:02:05](https://youtu.be/abc?t=3725) x")


class _Track:
    def __init__(self, lang, generated):
        self.language_code, self.is_generated = lang, generated

    def fetch(self):
        return [_Seg(f"{self.language_code}-{'auto' if self.is_generated else 'manual'}", 0.0)]


def test_pick_transcript_prefers_manual_english():
    tracks = [_Track("es", True), _Track("en", True), _Track("en", False)]
    segs, kind = pick_transcript(tracks)
    assert kind == "manual"
    assert segs[0].text == "en-manual"


def test_pick_transcript_falls_back_to_auto_english():
    segs, kind = pick_transcript([_Track("en-US", True), _Track("fr", False)])
    assert kind == "auto"


def test_pick_transcript_no_english_raises():
    with pytest.raises(NoCaptions):
        pick_transcript([_Track("es", True)])


def test_extract_article_real_driveline_html():
    html = (FX / "driveline_article.html").read_text(encoding="utf-8")
    meta, md, images = extract_article(html, "https://drivelinebaseball.com/blogs/blog/vertical-slider-pitch-design")
    assert meta["title"].startswith("Is the vertical slider")
    assert meta["author"] == "Travis Sawchik"
    assert meta["published"] == "2026-08-21"
    assert "seam-shifted wake" in md
    assert len(md) > 5000
    assert all(u.startswith("http") for u in images)
    assert any("cdn.shopify.com" in u for u in images)


def test_rewrite_image_links_maps_saved_only():
    md = "a ![fig](https://x/1.png) b ![](https://x/2.png?v=1) c"
    out = rewrite_image_links(md, {"https://x/2.png?v=1": "sources/_assets/driveline/slug/02.png"})
    assert "![fig](https://x/1.png)" in out
    assert "![](sources/_assets/driveline/slug/02.png)" in out


def test_best_title_prefers_full_ldjson_headline():
    from kb.fetch_blog import _best_title
    html = ('<script type="application/ld+json">{"@type":"Article","headline":"Full title that Shopify clipped in og"}</script>')
    assert _best_title("Full title that Shopify clipp", html) == "Full title that Shopify clipped in og"
    assert _best_title("Longer meta title wins here ok", "<html></html>") == "Longer meta title wins here ok"


def test_keep_image_url_rejects_gif_and_svg():
    from kb.fetch_blog import keep_image_url
    assert keep_image_url("https://x/chart.png?v=1")
    assert keep_image_url("https://x/photo.webp")
    assert not keep_image_url("https://x/loop.gif?v=2")
    assert not keep_image_url("https://x/icon.svg")


def test_get_transcript_prefers_captions_then_whisper_on_throttle_and_nocaptions(tmp_path):
    from kb.fetch_video import get_transcript, Throttled, NoCaptions
    calls = []

    def caps_ok(vid):
        calls.append("caps"); return [_Seg("c", 0.0)], "auto"

    def caps_throttled(vid):
        calls.append("caps"); raise Throttled("IpBlocked")

    def caps_none(vid):
        calls.append("caps"); raise NoCaptions("x")

    def whisper(vid, workdir):
        calls.append("whisper"); return [_Seg("w", 0.0)]

    segs, ctype, blocked = get_transcript("v", tmp_path, captions=caps_ok, whisper=whisper)
    assert ctype == "auto" and not blocked and calls == ["caps"]
    calls.clear()
    segs, ctype, blocked = get_transcript("v", tmp_path, captions=caps_throttled, whisper=whisper)
    assert ctype.startswith("whisper") and blocked and calls == ["caps", "whisper"]
    calls.clear()
    segs, ctype, blocked = get_transcript("v", tmp_path, captions=caps_none, whisper=whisper)
    assert ctype.startswith("whisper") and not blocked
    calls.clear()
    # once the run knows captions are blocked it must not keep asking
    segs, ctype, blocked = get_transcript("v", tmp_path, captions_blocked=True, captions=caps_ok, whisper=whisper)
    assert calls == ["whisper"] and blocked
