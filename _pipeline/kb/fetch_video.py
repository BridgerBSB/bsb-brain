"""Video -> raw transcript markdown. Captions first (free, fast); Whisper only
when asked and only when no English track exists."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

from .notes import write_note


class NoCaptions(Exception):
    pass


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
    return pick_transcript(api.list(video_id))


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


def transcribe_audio(video_id: str, workdir: Path) -> list:
    """Whisper fallback. Downloads audio with yt-dlp (ffmpeg from imageio_ffmpeg)
    and returns segment-like objects. Slow; opt-in via --whisper."""
    import imageio_ffmpeg
    from faster_whisper import WhisperModel

    ff = Path(imageio_ffmpeg.get_ffmpeg_exe())
    workdir.mkdir(parents=True, exist_ok=True)
    out = workdir / f"{video_id}.audio.m4a"
    cmd = ["yt-dlp", "--js-runtimes", "node", "--no-warnings", "-f", "bestaudio[ext=m4a]/bestaudio",
           "--ffmpeg-location", str(ff.parent), "-o", str(out),
           f"https://www.youtube.com/watch?v={video_id}"]
    subprocess.run(cmd, check=True, capture_output=True, timeout=1800)
    model = WhisperModel("base", device="cpu", compute_type="int8")
    segs, _ = model.transcribe(str(out), vad_filter=True)

    class _S:
        def __init__(self, s):
            self.text, self.start, self.duration = s.text, s.start, s.end - s.start

    result = [_S(s) for s in segs]
    out.unlink(missing_ok=True)
    return result


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
