---
type: project
domain: ai-tools
source: personal-bsbres/examples/ai-tools/2024_4th_pl_ai_comp
created: '2026-06-15'
---
# 2024 — 4th Place AI Competition (Driveline AI Impact Challenge)

A competition entry by **Zac Bridger** that placed **4th** in the
**Driveline Baseball "AI Impact Challenge."** The submission: an AI pipeline that
turns a baseball podcast episode into ready-to-post X/Twitter content — automated
transcription, speaker diarization, and GPT-generated threads grounded in the
episode. The full writeup is archived as
`AI Driveline Baseball Impact Challenge - Zac Bridger.pdf` (~4.2 MB).

Location: `personal-bsbres/examples/ai-tools/2024_4th_pl_ai_comp/` (the cleaned
competition code) and `personal-bsbres/examples/ai-tools/podcast_content/` (the
working transcripts, episode MP3, and prompt iterations).

---

## What it was

The challenge was a [[driveline]]-run contest to build something useful for
baseball using AI. Zac's angle: **content automation** — take Driveline's own
podcast and produce on-brand social threads from it with minimal human effort.
The judged artifact combined a working multi-stage pipeline with a documented
methodology and example output.

The headline files:
- `pod_trans.py` — the full workflow: yt-dlp download → pydub convert → Whisper
  transcribe → pyannote diarize → combine → (placeholder) thread chunking.
- `spot_embed.py` — Spotify-URL audio fetcher (with a DRM caveat; despite the
  name, contains no embedding code).
- `transcribe_zap.png` — a workflow/automation diagram (likely a Zapier-style
  "transcribe" automation visual).
- The companion `podcast_content/` scripts (`pod_combine.py`, `x_gpt_prompt.py`,
  `x_gpt_prompt_2.py`) do the actual GPT thread generation.

---

## The approach

The technical heart is documented fully in [[podcast-transcription-pipeline]].
In brief:

- **Transcription** — OpenAI **Whisper** (`base` model) for audio → text.
- **Diarization** — **`pyannote.audio`** `speaker-diarization` pipeline to label
  who-spoke-when, merged back onto Whisper segments by timestamp overlap.
- **Content generation** — the transcript is stuffed wholesale into a GPT-4 / GPT-4o
  prompt that uses a **persona** ("expert at X content, familiar with Driveline's
  philosophies + blog"), an explicit **task spec** (10 threads, 4–10 segments
  each, hook at start + CTA at end, strictly from the podcast), and a strong
  inline **few-shot exemplar** (a 12-tweet mobility-science thread on Golgi tendon
  organs / muscle spindles / the stretch reflex). `temperature=0.7`,
  `max_tokens` 8000–10000.

The demonstrated subject material was Driveline EP-15 ("Training 2.0," Kyle + host)
— its full Whisper transcript is checked in as `dlpod.txt`.

The README's "multi-modal / custom embeddings / fine-tuned models" framing is
aspirational marketing — the actual placed entry is Whisper + pyannote + GPT-4
prompt engineering, which is itself a tight, well-executed pipeline.

---

## Why it placed

- **Clear, useful application** — content automation is an immediate win for a
  media-producing org like Driveline.
- **Domain grounding** — the persona + few-shot exemplar made output sound like
  Driveline, not generic AI slop. That on-brand voice is the differentiator.
- **End-to-end working pipeline** — audio in, post-ready threads out, with
  diarization as a polish layer.

## Status
**Closed / archived.** 4th place, 2024. The code lives in the personal-bsbres
examples as a reference implementation of the AI content pipeline; the durable
technical writeup is [[podcast-transcription-pipeline]].

## Links
- [[MOC-baseball-analytics]]
- [[podcast-transcription-pipeline]] — the full technical breakdown of the pipeline
- [[driveline]] — the org that ran the challenge + the podcast source
- [[statcast-pipeline]] — the structured-data side of Zac's analytics work (sibling spine)
- [[stuff-plus-4s-pitching]] — the modeling work that lives alongside this in the repo
- [[personal-bsbres]] — the repo this archive lives under
