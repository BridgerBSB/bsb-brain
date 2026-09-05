"""Find new items on each feed. Parsers are pure; network calls are the three
small functions at the bottom, replaced in tests."""
from __future__ import annotations

import re
import subprocess
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from urllib.parse import urljoin, urlsplit, urlunsplit

import requests

from .slug import slugify
from .state import State

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) bsb-brain-kb/0.1"
YTDLP = ["yt-dlp", "--js-runtimes", "node", "--flat-playlist", "--no-warnings"]
_PRINT = "%(id)s\t%(title)s\t%(upload_date)s\t%(duration)s"


# --- parsers (pure) --------------------------------------------------------

def parse_ytdlp_lines(text: str) -> list[dict]:
    out = []
    for line in text.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        vid, title, upload, dur = parts[0], parts[1], parts[2], parts[3]
        published = None
        if re.fullmatch(r"\d{8}", upload):
            published = f"{upload[:4]}-{upload[4:6]}-{upload[6:]}"
        try:
            duration = int(float(dur))
        except ValueError:
            duration = None
        out.append(dict(id=vid, title=title, url=f"https://www.youtube.com/watch?v={vid}",
                        published=published, duration_s=duration))
    return out


def _clean_url(href: str, base: str) -> str:
    u = urlsplit(urljoin(base, href))
    return urlunsplit((u.scheme, u.netloc, u.path.rstrip("/"), "", ""))


def parse_driveline_page(html: str, base: str = "https://drivelinebaseball.com") -> list[dict]:
    """Anchors matching /blogs/blog/<slug>, in page order, deduped, with the
    nearest <time datetime> after the anchor when one exists."""
    items, seen = [], set()
    for m in re.finditer(r'href="(/blogs/blog/[^"]+)"', html):
        url = _clean_url(m.group(1), base)
        if url in seen or url.rstrip("/").endswith("/blogs/blog"):
            continue
        seen.add(url)
        slug = url.rsplit("/", 1)[-1]
        tail = html[m.end(): m.end() + 2500]
        # look for <time datetime> before the next anchor that points at a DIFFERENT post
        limit = len(tail)
        for a in re.finditer(r'href="(/blogs/blog/[^"]+)"', tail):
            if _clean_url(a.group(1), base) != url:
                limit = a.start()
                break
        t = re.search(r'<time[^>]*datetime="(\d{4}-\d{2}-\d{2})', tail[:limit])
        published = t.group(1) if t else None
        items.append(dict(id=f"dl-blog-{slug}", title=None, url=url,
                          published=published, duration_s=None))
    return items


def parse_tread_feed(xml_text: str) -> list[dict]:
    root = ET.fromstring(xml_text)
    items = []
    for it in root.iter("item"):
        link = (it.findtext("link") or "").strip()
        title = (it.findtext("title") or "").strip()
        pub = it.findtext("pubDate")
        published = None
        if pub:
            try:
                published = parsedate_to_datetime(pub).strftime("%Y-%m-%d")
            except (TypeError, ValueError):
                published = None
        slug = urlsplit(link).path.strip("/").rsplit("/", 1)[-1] or slugify(title)
        items.append(dict(id=f"tread-blog-{slug}", title=title, url=link,
                          published=published, duration_s=None))
    return items


def parse_tread_archive_page(html: str) -> list[dict]:
    """Post links on treadathletics.com/posts/page/N/ (WordPress list)."""
    items, seen = [], set()
    for m in re.finditer(r'<h\d[^>]*class="[^"]*entry-title[^"]*"[^>]*>\s*<a[^>]*href="(https://treadathletics\.com/[^"]+)"[^>]*>(.*?)</a>', html, re.S):
        url = _clean_url(m.group(1), "https://treadathletics.com")
        if url in seen:
            continue
        seen.add(url)
        title = re.sub(r"<[^>]+>", "", m.group(2)).strip()
        slug = urlsplit(url).path.strip("/").rsplit("/", 1)[-1]
        items.append(dict(id=f"tread-blog-{slug}", title=title, url=url,
                          published=None, duration_s=None))
    return items


# --- state plumbing ----------------------------------------------------------

def discover_items(state: State, feed: dict, found: list[dict]) -> int:
    medium = "video" if feed["kind"] == "youtube" else "blog"
    n = 0
    for it in found:
        rec = dict(it, source=feed["source"], medium=medium, feed=feed["kind"])
        if state.add(rec):
            n += 1
    return n


# --- network -----------------------------------------------------------------

def yt_dlp_flat(channel_url: str, start: int | None = None, end: int | None = None) -> str:
    cmd = list(YTDLP)
    if start:
        cmd += ["--playlist-start", str(start)]
    if end:
        cmd += ["--playlist-end", str(end)]
    cmd += ["--print", _PRINT, channel_url]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
    if r.returncode != 0 and not r.stdout.strip():
        raise RuntimeError(f"yt-dlp failed: {r.stderr[-400:]}")
    return r.stdout


def fetch_text(url: str, timeout: int = 30) -> str:
    r = requests.get(url, headers={"User-Agent": UA}, timeout=timeout)
    r.raise_for_status()
    r.encoding = r.encoding or "utf-8"
    return r.text
