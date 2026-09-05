from kb.slug import slugify, note_name, cue_slug


def test_slugify_basic():
    assert slugify("Is the vertical slider the next big thing?") == \
        "is-the-vertical-slider-the-next-big-thing"


def test_slugify_strips_non_ascii_and_punctuation():
    assert slugify("Tatis Jr.’s “no home runs” swing | Part II") == \
        "tatis-jr-s-no-home-runs-swing-part-ii"


def test_slugify_caps_length_at_word_boundary():
    long = "word " * 40
    s = slugify(long)
    assert len(s) <= 60
    assert not s.endswith("-")


def test_slugify_empty_falls_back():
    assert slugify("???") == "untitled"


def test_note_name_prefixes_date():
    assert note_name("2026-08-21", "Vertical Slider") == "2026-08-21-vertical-slider"


def test_note_name_without_date():
    assert note_name(None, "Vertical Slider") == "undated-vertical-slider"


def test_cue_slug_has_prefix():
    assert cue_slug("Get the ball out of the glove early") == \
        "cue-get-the-ball-out-of-the-glove-early"
