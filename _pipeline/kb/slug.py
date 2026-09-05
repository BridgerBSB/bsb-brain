"""Filenames and wikilink slugs. ASCII, lowercase, hyphenated, bounded."""
import re
import unicodedata

MAX_LEN = 60


def slugify(text: str, max_len: int = MAX_LEN) -> str:
    text = unicodedata.normalize("NFKD", text or "")
    text = text.encode("ascii", "ignore").decode("ascii").lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    if not text:
        return "untitled"
    if len(text) > max_len:
        cut = text[:max_len]
        if "-" in cut:
            cut = cut[: cut.rfind("-")]
        text = cut.strip("-") or text[:max_len].strip("-")
    return text


def note_name(published: str | None, title: str) -> str:
    prefix = published if published else "undated"
    return f"{prefix}-{slugify(title)}"


def cue_slug(phrase: str) -> str:
    return "cue-" + slugify(phrase, max_len=MAX_LEN - 4)
