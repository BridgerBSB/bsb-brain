"""Video -> raw transcript markdown.

Order of preference per video:
  1. YouTube captions (manual English, then auto English) - free, ~1 s.
  2. Whisper (faster_whisper base, int8, CPU ~19x realtime here) on downloaded
     audio - used automatically when captions are throttled or absent.

YouTube rate-limits the caption endpoint after a short burst from one IP and
the block has lasted a day; audio downloads keep working (after a yt-dlp
update). So a Throttled caption fetch is not a failure: the run stops asking
for captions and transcribes instead, within a per-run time budget.
"""
from __future__ import annotations

import glob
import json
import os
import subprocess
import time
from pathlib import Path

from .notes import write_note

WHISPER_MODEL = "base"


class NoCaptions(Exception):
    pass


class Throttled(Exception):
    """YouTube rate-limited the caption endpoint (IpBlocked / HTTP 429).
    Not the item's fault."""


def _is_throttle(exc: Exception) -> bool:
    s = f"{type(exc).__name__}: {exc}"
    return any(k in s for k in ("IpBlocked", "RequestBlocked", "429", "Too Many Requests"))


def _ts(seconds: float) -> str:
    s = int(seconds)
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    return f"{h}:{m:02d}:{sec:02d}" if h else f"{m:02d}:{sec:02d}"


def segments_to_markdown(segments, video_id: str, window_s: int = 60) -> str:
    """Group caption segments into paragraphs of ~window_s seconds, each led by
    a clickable timestamp. The link form is what the summarizer must reuse."""
    paras, cur, cur_start = [], [], None
    for seg in segments:
        start = float(seg.start)
        text = " ".join(str(seg.text).replace("\n", " ").split())
        if not text:
            continue
        if cur_start is None:
            cur_start = start
        if start - cur_start >= window_s and cur:
            paras.append((cur_start, " ".join(cur)))
            cur, cur_start = [], start
        cur.append(text)
    if cur:
        paras.append((cur_start, " ".join(cur)))
    return "\n\n".join(
        f"[{_ts(s)}](https://youtu.be/{video_id}?t={int(s)}) {t}" for s, t in paras
    ) + "\n"


def pick_transcript(tracks) -> tuple[list, str]:
    """tracks: iterable with .language_code, .is_generated, .fetch(). Manual
    English beats auto English; anything else is NoCaptions."""
    manual = [t for t in tracks if t.language_code.lower().startswith("en") and not t.is_generated]
    auto = [t for t in tracks if t.language_code.lower().startswith("en") and t.is_generated]
    if manual:
        return list(manual[0].fetch()), "manual"
    if auto:
        return list(auto[0].fetch()), "auto"
    raise NoCaptions("no English caption track")


def fetch_captions(video_id: str) -> tuple[list, str]:
    from youtube_transcript_api import YouTubeTranscriptApi
    api = YouTubeTranscriptApi()
    try:
        return pick_transcript(api.list(video_id))
    except NoCaptions:
        raise
    except Exception as e:  # the library raises many classes; classify by message
        if _is_throttle(e):
            raise Throttled(type(e).__name__) from e
        raise


def fetch_video_meta(video_id: str) -> dict:
    cmd = ["yt-dlp", "--js-runtimes", "node", "--no-warnings", "--skip-download", "-j",
           f"https://www.youtube.com/watch?v={video_id}"]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    if r.returncode != 0 or not r.stdout.strip():
        raise RuntimeError(f"yt-dlp -j failed: {r.stderr[-300:]}")
    d = json.loads(r.stdout.splitlines()[0])
    up = d.get("upload_date")
    return dict(
        title=d.get("title"),
        channel=d.get("channel"),
        published=f"{up[:4]}-{up[4:6]}-{up[6:]}" if up else None,
        duration_s=d.get("duration"),
        description=(d.get("description") or "").strip(),
        chapters=[(c.get("start_time"), c.get("title")) for c in (d.get("chapters") or [])],
        view_count=d.get("view_count"),
    )


class _Seg:
    def __init__(self, text, start, end):
        self.text, self.start, self.duration = text, start, end - start


_model = None


def _whisper():
    global _model
    if _model is None:
        from faster_whisper import WhisperModel
        _model = WhisperModel(WHISPER_MODEL, device="cpu", compute_type="int8")
    return _model


def download_audio(video_id: str, workdir: Path) -> Path:
    import imageio_ffmpeg
    ff = Path(imageio_ffmpeg.get_ffmpeg_exe())
    workdir.mkdir(parents=True, exist_ok=True)
    for old in glob.glob(str(workdir / f"{video_id}.audio.*")):
        os.unlink(old)
    tmpl = str(workdir / f"{video_id}.audio.%(ext)s")
    cmd = ["yt-dlp", "--js-runtimes", "node", "--no-warnings", "-f", "bestaudio[ext=m4a]/bestaudio",
           "--ffmpeg-location", str(ff.parent), "-o", tmpl,
           f"https://www.youtube.com/watch?v={video_id}"]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=1800)
    files = glob.glob(str(workdir / f"{video_id}.audio.*"))
    if r.returncode != 0 or not files:
        raise RuntimeError(f"audio download failed: {r.stderr[-300:]}")
    return Path(files[0])


def transcribe_audio(video_id: str, workdir: Path) -> list:
    """Whisper fallback: download audio, transcribe, delete the audio."""
    audio = download_audio(video_id, workdir)
    try:
        segs, _info = _whisper().transcribe(str(audio), vad_filter=True, beam_size=1)
        return [_Seg(s.text, s.start, s.end) for s in segs]
    finally:
        audio.unlink(missing_ok=True)


def get_transcript(video_id: str, workdir: Path, captions_blocked: bool = False,
                   captions=fetch_captions, whisper=transcribe_audio) -> tuple[list, str, bool]:
    """-> (segments, caption_type, captions_blocked_now).

    Tries captions unless the run already knows they are blocked; falls to
    Whisper on Throttled or NoCaptions. caption_type is 'manual' | 'auto' |
    'whisper-<model>'."""
    if not captions_blocked:
        try:
            segs, ctype = captions(video_id)
            return segs, ctype, False
        except Throttled:
            captions_blocked = True
        except NoCaptions:
            pass
    segs = whisper(video_id, workdir)
    return segs, f"whisper-{WHISPER_MODEL}", captions_blocked


def write_raw_video(path: Path, item: dict, meta: dict, transcript_md: str, caption_type: str) -> None:
    fm = dict(
        type="raw", source=item["source"], medium="video", id=item["id"],
        title=meta.get("title") or item.get("title"), url=item["url"],
        published=meta.get("published") or item.get("published"),
        author=meta.get("channel"), duration_s=meta.get("duration_s") or item.get("duration_s"),
        caption_type=caption_type, view_count=meta.get("view_count"),
    )
    body = [f"# {fm['title']}", ""]
    if meta.get("description"):
        body += ["## Description", "", meta["description"], ""]
    if meta.get("chapters"):
        body += ["## Chapters", ""] + [f"- {_ts(s or 0)} {t}" for s, t in meta["chapters"]] + [""]
    body += ["## Transcript", "", transcript_md]
    write_note(path, fm, "\n".join(body))
