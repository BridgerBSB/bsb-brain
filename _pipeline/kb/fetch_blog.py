"""Blog post -> raw article markdown (+ figures saved to _assets)."""
from __future__ import annotations

import re
from pathlib import Path

import requests
import trafilatura

from .notes import write_note

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) bsb-brain-kb/0.1"
_IMG = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)\)")
MIN_CHARS = 500


def extract_article(html: str, url: str) -> tuple[dict, str, list[str]]:
    md = trafilatura.extract(html, url=url, output_format="markdown", include_images=True,
                            include_links=True, include_tables=True, favor_recall=True) or ""
    m = trafilatura.extract_metadata(html, default_url=url)
    meta = dict(
        title=_best_title((m.title if m else None), html),
        author=(m.author if m else None) or None,
        published=(m.date if m else None) or None,
        description=(m.description if m else None) or None,
        tags=list(m.tags) if m and m.tags else [],
    )
    images = []
    for _, src in _IMG.findall(md):
        if src.startswith("http") and src not in images:
            images.append(src)
    return meta, md, images


def _ldjson_headline(html: str) -> str | None:
    """Shopify truncates <title>/og:title at ~70 chars; the JSON-LD headline is full."""
    import json
    for m in re.finditer(r'<script type="application/ld\+json">(.*?)</script>', html, re.S):
        try:
            d = json.loads(m.group(1))
        except (json.JSONDecodeError, ValueError):
            continue
        for node in (d if isinstance(d, list) else [d]):
            if isinstance(node, dict) and node.get("headline"):
                return str(node["headline"]).strip()
    return None


def _best_title(meta_title: str | None, html: str) -> str | None:
    ld = _ldjson_headline(html)
    if ld and (not meta_title or len(ld) > len(meta_title)):
        return ld
    return meta_title or None


def _ext(url: str) -> str:
    path = url.split("?")[0].lower()
    for e in (".png", ".jpg", ".jpeg", ".gif", ".webp"):
        if path.endswith(e):
            return ".jpg" if e == ".jpeg" else e
    return ".png"


def save_images(urls: list[str], dest: Path, skip_first: bool = True, min_bytes: int = 15_000,
                max_bytes: int = 2_000_000) -> dict[str, Path]:
    """Download body figures. The first image on a Driveline post is the hero;
    tiny files are icons/avatars. Returns {url: local_path} for the kept ones."""
    saved = {}
    for i, u in enumerate(urls):
        if skip_first and i == 0:
            continue
        if not keep_image_url(u):
            continue
        try:
            r = requests.get(u, headers={"User-Agent": UA}, timeout=30)
            if r.status_code != 200 or not (min_bytes <= len(r.content) <= max_bytes):
                continue
            dest.mkdir(parents=True, exist_ok=True)
            p = dest / f"{i:02d}{_ext(u)}"
            p.write_bytes(r.content)
            saved[u] = p
        except requests.RequestException:
            continue
    return saved


def keep_image_url(url: str) -> bool:
    """Figures are png/jpg/webp screenshots and charts. Animated GIFs (a 7 MB
    highlight loop on one Tread post) and SVG icons are never figures."""
    path = url.split("?")[0].lower()
    return not path.endswith((".gif", ".svg", ".ico"))


def rewrite_image_links(md: str, mapping: dict[str, str]) -> str:
    def _sub(m):
        alt, src = m.group(1), m.group(2)
        return f"![{alt}]({mapping[src]})" if src in mapping else m.group(0)
    return _IMG.sub(_sub, md)


def write_raw_blog(path: Path, item: dict, meta: dict, md: str, images_saved: dict[str, str]) -> None:
    fm = dict(
        type="raw", source=item["source"], medium="blog", id=item["id"],
        title=meta.get("title") or item.get("title"), url=item["url"],
        published=meta.get("published") or item.get("published"),
        author=meta.get("author"), tags=meta.get("tags") or [],
        figures=sorted(images_saved.values()),
    )
    body = f"# {fm['title']}\n\n{rewrite_image_links(md, images_saved)}"
    write_note(path, fm, body)
