from kb.sources import feeds_for, paused_media, drop_paused, medium_for

SRC = {
    "tread-yt": {"source": "tread", "kind": "youtube"},
    "tread-blog": {"source": "tread", "kind": "blog-rss"},
    "bpc-yt": {"source": "bpc", "kind": "youtube", "paused": True},
}


def test_feeds_for_drops_paused_unless_asked():
    assert [k for k, _ in feeds_for(SRC, None)] == ["tread-yt", "tread-blog"]
    assert [k for k, _ in feeds_for(SRC, "bpc")] == []
    assert [k for k, _ in feeds_for(SRC, "bpc", include_paused=True)] == ["bpc-yt"]


def test_paused_media_is_source_x_medium():
    assert paused_media(SRC) == {("bpc", "video")}
    assert medium_for("blog-pages") == "blog"


def test_drop_paused_keeps_live_items_and_counts_the_rest():
    items = [
        {"id": "a", "source": "tread", "medium": "video"},
        {"id": "b", "source": "bpc", "medium": "video"},
        {"id": "c", "source": "bpc", "medium": "blog"},   # no bpc blog feed exists, so not paused
    ]
    kept, n = drop_paused(items, SRC)
    assert [r["id"] for r in kept] == ["a", "c"] and n == 1
    assert drop_paused(items, {"x": {"source": "tread", "kind": "youtube"}}) == (items, 0)
