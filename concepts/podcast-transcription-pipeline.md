---
type: concept
domain: ai-tools
source: personal-bsbres/examples/ai-tools
created: '2026-06-15'
---
# Podcast Transcription → GPT Thread Pipeline

An end-to-end audio-to-social-content pipeline built for the **2024 Driveline
"AI Impact Challenge"** (see [[2024-4th-place-ai-comp]] — 4th place finish).
Takes a baseball podcast episode and produces (a) a full transcript, optionally
(b) speaker-labeled segments, and (c) GPT-generated X/Twitter threads grounded
strictly in the episode's content. Three generations of the scripts exist in the
archive, from a single-file MVP to a full diarization workflow.

Source files (`personal-bsbres/examples/ai-tools/`):
- `2024_4th_pl_ai_comp/pod_trans.py` — the **full workflow** (download → convert → transcribe → diarize → combine → thread gen)
- `2024_4th_pl_ai_comp/spot_embed.py` — Spotify-URL audio fetch stub (DRM caveat)
- `podcast_content/pod_trans (1).py` — minimal Whisper-only transcriber
- `podcast_content/pod_combine.py` — Whisper transcribe + GPT-4 thread prompt in one file
- `podcast_content/x_gpt_prompt.py` / `x_gpt_prompt_2.py` — the two GPT-prompting variants

---

## What it does, stage by stage

The canonical full version is `2024_4th_pl_ai_comp/pod_trans.py`. It's a 7-step
linear workflow:

1. **Download podcast audio** — `download_podcast(url)` uses **`yt-dlp`** with an
   `FFmpegExtractAudio` postprocessor to pull `bestaudio/best` and re-encode to
   192 kbps MP3. Triggered on a Spotify episode URL
   (`https://open.spotify.com/episode/0WDvQSqnSb6vwfgGuoT7DZ`).
2. **Convert audio** — `convert_audio()` uses **`pydub`** (`AudioSegment.from_file`)
   to export a `.wav` for downstream tools that prefer WAV.
3. **Transcription** — `transcribe_audio()` loads **OpenAI Whisper** (`whisper.load_model("base")`)
   and runs `model.transcribe(audio_file)`, returning the full result dict
   (`["text"]` plus `["segments"]` with per-segment start/end timestamps).
4. **Speaker diarization** — `diarize_audio()` uses **`pyannote.audio`**
   (`Pipeline.from_pretrained("pyannote/speaker-diarization")`). It iterates
   `diarization.itertracks(yield_label=True)` and collects
   `{"start", "end", "speaker"}` segments — who spoke when.
5. **Combine transcription + diarization** — `combine_transcription_diarization()`
   walks Whisper's `segments` and, for each one, finds the speaker whose
   diarization window contains that segment's start time (falls back to
   `"Unknown"`). Produces unified `{start, end, speaker, text}` records.
6. **Generate Twitter threads** — `generate_twitter_threads(content, thread_count=10)`
   is a **placeholder** in this version: it naively chunks the combined segments
   into N roughly-equal slices and joins them as `[speaker]: text` — i.e. the
   real LLM thread-generation lives in the separate `x_gpt_prompt*` / `pod_combine`
   scripts, not here.
7. **Main workflow** — writes `transcription.txt` (timestamped, speaker-labeled)
   and `twitter_threads.txt`.

### The minimal variant
`podcast_content/pod_trans (1).py` is the 5-line MVP — just
`whisper.load_model("base")` → `model.transcribe("DL_Podcast_EP_15_audio.mp3")`
→ write `result["text"]` to `dlpod.txt`. This is what actually produced the
`dlpod.txt` transcript checked into the archive (the Driveline EP-15 "Training
2.0" episode with Kyle).

### The Spotify-fetch caveat
`spot_embed.py` (`process_spotify_audio`) is the same `yt-dlp` MP3 pull as step 1,
but wrapped in a try/except with an explicit comment:
> "Note: yt-dlp may not work directly with Spotify links due to DRM restrictions"

So the practical input path was a pre-downloaded MP3 (`DL_Podcast_EP_15_audio.mp3`,
~92 MB), not live Spotify ripping.

---

## The GPT prompt-engineering approach

The thread-generation is where the real craft is. Three near-identical scripts
(`pod_combine.py`, `x_gpt_prompt.py`, `x_gpt_prompt_2.py`) all do:
**read `dlpod.txt` → build a domain-specific prompt embedding the full transcript
→ call the OpenAI Chat API → print the result.**

The prompt is a **persona + grounding + few-shot** pattern:

- **Persona:** *"You are an expert at creating engaging social media content
  designed for X. You are also familiar with Driveline Baseball's philosophies
  and their blogs at drivelinebaseball.com/blog."* — domain-grounded role.
- **Task:** Create 10 X "threads" of 4–10 segments each, **detailed and specific
  to ideas discussed in the podcast**, with explicit sub-instructions: summarize
  the transcript first, then generate threads, each with **a hook at the start
  and a call-to-action at the end**, strictly based on podcast concepts.
- **Grounding:** the entire transcript is interpolated into the prompt via an
  f-string (`{transcript_text}` inside triple-quotes). This is naive full-context
  stuffing (no chunking/retrieval) — relies on the model's context window holding
  the whole episode.
- **Few-shot exemplar:** a complete 12-segment reference thread on **mobility /
  ROM training** (Golgi tendon organs, muscle spindles, the stretch reflex,
  contractile vs non-contractile elements, "muscles aren't just dumb pieces of
  meat… software, not just the hardware") is pasted inline as the gold-standard
  format + voice to imitate. This is the load-bearing piece — it teaches tone,
  depth, structure, and the emoji/hook conventions in one shot.
- **Sampling:** `temperature=0.7` (creativity), `max_tokens` 8000–10000 (long
  output). A comment in `x_gpt_prompt.py` notes *"8000-32000 is optimal in 4o
  (apparently)"*.

### Variant differences (API-evolution archaeology)
The three scripts capture the OpenAI SDK transition:
- `x_gpt_prompt_2.py` — **legacy SDK**: `openai.ChatCompletion.create(model="gpt-4o")`,
  reads `response["choices"][0]["message"]["content"]`.
- `pod_combine.py` — **1.0.0+ SDK**: `openai.chat.completions.create(model="gpt-4")`,
  reads `response.choices[0].message.content`.
- `x_gpt_prompt.py` — **1.0.0+ SDK** with `model="gpt-4o"`, the cleanest version:
  reads the key from `os.getenv("OPENAI_API_KEY")` and raises if unset, uses a
  trimmed prompt (drops the verbose disclaimer, keeps the few-shot), and
  `max_tokens=10000`. This is the "production" form.

### Security note (do NOT repeat)
`pod_combine.py` and `x_gpt_prompt_2.py` both **hardcode a plaintext
`sk-proj-...` OpenAI API key** in source (with a self-aware `# WARNING: Storing
the API key in plain text is not secure` comment). `x_gpt_prompt.py` is the
corrected version that reads from the environment. If reusing any of this, take
the `x_gpt_prompt.py` env-var pattern — the hardcoded keys are a liability and
should be considered burned.

---

## Library / stack summary

| Stage | Library | Call |
|---|---|---|
| Audio download | `yt-dlp` | `YoutubeDL(ydl_opts).download([url])` + `FFmpegExtractAudio` |
| Audio convert | `pydub` (+ ffmpeg) | `AudioSegment.from_file().export(fmt="wav")` |
| Transcription | OpenAI **Whisper** (`base` model) | `whisper.load_model("base").transcribe(...)` |
| Diarization | **`pyannote.audio`** | `Pipeline.from_pretrained("pyannote/speaker-diarization")` |
| Thread generation | **OpenAI Chat API** (GPT-4 / GPT-4o) | `chat.completions.create(...)` |

The `ai-tools/README.md` claims of "custom baseball domain embeddings" /
"fine-tuned models" are **aspirational** — the actual archived code is Whisper +
pyannote + GPT-4 prompt stuffing, with no embeddings or fine-tuning present.
(`spot_embed.py`, despite the name, contains no embedding code — it's the
Spotify audio fetcher.)

---

## Lessons / reusable patterns

- **Persona + domain-grounding + one strong few-shot exemplar** is the whole game
  for on-brand content generation. The mobility-science thread does more work than
  any instruction list.
- **Full-context stuffing works** for a single ~72 KB transcript inside a large
  context window — no RAG needed at this scale. Would break on a back-catalog.
- **Whisper `base`** was sufficient for clean podcast audio; diarization is the
  expensive/fragile add-on and was only wired into the full version.
- The naive `generate_twitter_threads()` chunker in `pod_trans.py` is a reminder
  that the *real* summarization is an LLM job, not a string-split — the GPT scripts
  are where the value is.

## Links
- [[MOC-baseball-analytics]]
- [[2024-4th-place-ai-comp]] — the competition entry this pipeline was built for
- [[statcast-pipeline]] — the structured-data sibling spine (this is the
  unstructured-audio counterpart)
- [[driveline]] — the podcast source + the org whose challenge this won placement in
- [[personal-bsbres]] — the repo this lives under
