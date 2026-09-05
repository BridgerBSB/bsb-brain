---
type: project
domain: training-knowledge
status: in-progress
created: 2026-09-04
---
# Training Knowledge Base Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A nightly, agent-maintained pipeline that turns Driveline / Tread / BPC videos and blog posts into reviewed, interlinked Obsidian notes (sources, cues, concepts) inside `bsb-brain`, owned by BridgerBSB and mirrored to the Astros account.

**Architecture:** Karpathy three-layer wiki: immutable raw transcripts/articles under `sources/_raw/`, agent-owned notes under `sources/` + `cues/` + `concepts/`, and a schema (`_pipeline/taxonomy.md` + vault `CLAUDE.md` section). A Python CLI (`_pipeline/kb.py`) does discover / fetch / summarize / promote / lint; only summarize calls headless `claude -p`. Zac reviews in Obsidian; his edits become few-shot examples.

**Tech Stack:** Python 3.12, yt-dlp (`--js-runtimes node`), youtube_transcript_api, faster_whisper + imageio_ffmpeg (fallback), trafilatura, python-frontmatter, PyYAML, pytest; `claude -p` (Haiku triage, Sonnet notes); Windows Task Scheduler via PowerShell `Register-ScheduledTask`.

Design: [[projects/training-knowledge/design]]. Research: [[meta/youtube-to-vault-pipeline-research]].

---

## Phase 1: repo re-home, schema, templates, hubs

### Task 1: Protect the vault before touching remotes
**Files:** Modify `bsb-brain/.gitignore`
- Step 1: append `00-inbox/transcripts/`, `sources/_raw/**/*.audio.*`, `_pipeline/__pycache__/`, `_pipeline/.pytest_cache/`, `_pipeline/*.log`.
- Step 2: `git status --short | grep transcripts` -> expect nothing.
- Step 3: commit `chore(vault): ignore session transcripts and pipeline scratch`.

### Task 2: Re-home origin to BridgerBSB, keep Astros as mirror
- Step 1: `git ls-remote git@github-personal:BridgerBSB/bsb-brain.git` -> if it 404s, create the private repo (browser as BridgerBSB, or ask Zac). Do NOT push to any org.
- Step 2: `git remote rename origin astros`; `git remote add origin git@github-personal:BridgerBSB/bsb-brain.git`.
- Step 3: `git push -u origin main`; `git push astros main`. Verify `git remote -v` shows both.
- Step 4: record the arrangement in `meta/README-dual-run.md` (one paragraph) and in the vault `CLAUDE.md` folder map.

### Task 3: Schema files
**Files:** Create `_pipeline/sources.yml`, `_pipeline/taxonomy.md`, `templates/source.md`, `templates/cue.md`, `_pipeline/prompts/summarize.md`, `_pipeline/prompts/triage.md`, `_pipeline/log.md`, `_pipeline/examples/README.md`
- `sources.yml` holds the five sources from the design with `scope: {exclude_domains: [hitting]}` on bpc.
- `taxonomy.md` = design section 5 verbatim plus an empty `## Worked examples` section the promote step appends to.
- Templates mirror design section 4.
- Commit `feat(kb): schema, taxonomy, templates`.

### Task 4: Hubs and vault CLAUDE.md section
**Files:** Create `MOC-training-knowledge.md`, `MOC-pitching.md`, `MOC-strength.md`, `MOC-anatomy.md`; Modify `CLAUDE.md` (folder map rows for `sources/ cues/ _review/ _pipeline/`; a "Training knowledge" section with the review contract); Modify `MOC-hitting.md` (link up to the new hub).
- `MOC-pitching` seeds from existing concept notes: grep `domain: pitching` in `concepts/` and list them.
- Commit `feat(kb): training-knowledge hubs + CLAUDE.md contract`.

## Phase 2: the CLI

Package layout: `_pipeline/kb.py` (argparse entry) + `_pipeline/kb/` modules + `_pipeline/tests/`. Run tests with `cd _pipeline && python -m pytest -q`. Every network call lives behind a function that tests replace with a fixture.

### Task 5: state + slugs + note I/O (pure, TDD)
**Files:** Create `kb/__init__.py`, `kb/paths.py`, `kb/state.py`, `kb/slug.py`, `kb/notes.py`; Test `tests/test_state.py`, `tests/test_slug.py`, `tests/test_notes.py`
- `state.py`: `State.load(path)`, `.add(item)`, `.get(id)`, `.set_status(id, status, error=None)` (bumps `retries` on `failed`), `.by_status(status, source=None)`, `.save()` (atomic write via temp + replace). Item keys: `id source medium url title published status retries error raw note added`.
- `slug.py`: `slugify("Is the vertical slider the next big thing?") == "is-the-vertical-slider-the-next-big-thing"`, capped at 60 chars, ascii only; `note_name(published, slug)` -> `2026-08-21-is-the-vertical-slider...`.
- `notes.py`: `read_note(path)` / `write_note(path, meta, body)` with python-frontmatter; `validate_source_meta(meta)` returns list of problems (required keys, allowed values for domain/kind/value/status, bpc+hitting => value skip).
- Tests first, watch them fail, implement, pass, commit `feat(kb): state, slug, note schema`.

### Task 6: discover
**Files:** Create `kb/discover.py`; Test `tests/test_discover.py` with fixtures `tests/fixtures/driveline_page1.html`, `tests/fixtures/tread_feed.xml`, `tests/fixtures/ytdlp_flat.txt`
- `parse_driveline_page(html) -> [(url, slug)]`, `parse_tread_feed(xml) -> [(url, title, published)]`, `parse_ytdlp_lines(text) -> [(id, title, upload_date, duration)]` are pure and tested.
- `discover(state, sources, mode="new"|"backfill", page=None)` calls `yt_dlp_flat(channel_url)` (subprocess `yt-dlp --js-runtimes node --flat-playlist --print "%(id)s\t%(title)s\t%(upload_date)s\t%(duration)s"`), `fetch_html(url)`, `fetch_feed(url)`; adds unseen ids with status `new`.
- Commit `feat(kb): discover new videos and posts`.

### Task 7: fetch (video captions, blog article, images)
**Files:** Create `kb/fetch_video.py`, `kb/fetch_blog.py`; Test `tests/test_fetch_blog.py` (fixture `tests/fixtures/driveline_article.html`), `tests/test_fetch_video.py` (fixture transcript segments)
- `segments_to_markdown(segments, video_id)` groups caption segments into ~60 s paragraphs each prefixed with a `[mm:ss](https://youtu.be/<id>?t=<s>)` link.
- `fetch_captions(video_id)` prefers manual `en`, then auto `en`, raises `NoCaptions`. `fetch_video_meta(id)` via `yt-dlp -j` (title, upload_date, duration, description). Whisper fallback `transcribe_audio(id)` behind a flag `--whisper`.
- `extract_article(html, url) -> (meta, markdown, image_urls)` via trafilatura; `save_images(urls, dest, min_width=300)` skips the first (hero) image and anything under 300 px; rewrites image links in the markdown to the local `_assets` path.
- Raw file = frontmatter (`type: raw`, source, medium, url, title, published, author, duration_s, fetched, caption_type) + body. Status -> `fetched`; on exception -> `failed` with the message; fewer than 500 chars -> failed `too-short`.
- Commit `feat(kb): fetch captions and articles`.

### Task 8: summarize (headless claude)
**Files:** Create `kb/summarize.py`, `prompts/triage.md`, `prompts/summarize.md`; Test `tests/test_summarize.py` (fake `run_claude` returning canned text; tests cover prompt assembly, frontmatter validation, retry-once, examples inclusion)
- `run_claude(instruction, stdin_text, model)` = `subprocess.run(["claude","-p",instruction,"--model",model,"--output-format","text"], input=..., text=True, encoding="utf-8")`. Verify the exact flags with `claude --help` before coding.
- Triage (Haiku): input = title + description + first 2000 chars; output one JSON line `{"kind":..., "domain":[...]}`.
- Full (Sonnet) only when kind != marketing: input = taxonomy + last 15 examples for the source + raw; output = a complete source note. Parse, `validate_source_meta`, force `status: pending`, `confidence: agent`, `raw:` path; write to `_review/<note_name>.md`. Marketing items get a 3-line note written the same way with `value: low`.
- Status -> `summarized`. Commit `feat(kb): triage + summarize via claude -p`.

### Task 9: promote + examples
**Files:** Create `kb/promote.py`; Test `tests/test_promote.py` against a temp vault
- For each `_review/*.md` with status in {approved, edited, rejected}: diff frontmatter + cue list against the agent's original (kept in `state` as `proposal`), write `_pipeline/examples/<note>.md` if anything changed, move note to `sources/<source>/`, upsert cue notes (`cues/<slug>.md`, append source link), append `## From sources` bullet to any concept it links, append one line to `_pipeline/log.md`. Rejected -> `sources/<source>/_rejected/`.
- `git_commit_and_push(paths)`: add by explicit path only, commit, push origin then astros; push failure logged, not raised.
- Commit `feat(kb): promote reviewed notes, record corrections`.

### Task 10: lint + CLI wiring + run verb
**Files:** Create `kb/lint.py`, `kb.py`; Test `tests/test_lint.py`
- Lint rules: orphan cue (no `sources:`), source note with no concept links, unresolved `[[link]]` outside `_review`, items `failed` with retries >= 3 -> `_pipeline/failed.md`, contradictions placeholder (two sources with opposite `claim` polarity on the same concept; v0 only flags concepts touched by 5+ sources for a manual look).
- `kb.py` verbs: `discover fetch summarize promote lint backfill candidates run` with `--source`, `--limit`, `--dry-run`, `--whisper`. `run` = discover -> fetch -> summarize -> promote -> lint -> one backfill batch per source when pending < 40.
- Commit `feat(kb): lint + CLI`.

## Phase 3: calibration batch (real network)

### Task 11: calibration
- `python kb.py backfill --source tread --from newest --limit 10` and the same for driveline and bpc; then `fetch` and `summarize`.
- Read three notes by hand; fix prompt wording; re-run those three with `--force`.
- Commit the raw files + `_review/` notes. Push both remotes. Tell Zac: 30 notes waiting in `_review/`.

## Phase 4: scheduling

### Task 12: nightly task
**Files:** Create `_pipeline/run_nightly.ps1`, `_pipeline/install_task.ps1`
- `run_nightly.ps1`: `$env:PYTHONIOENCODING='utf-8'`; `cd C:\Users\Owner\bsb-brain\_pipeline`; `python kb.py run *>> nightly.log`.
- `install_task.ps1`: `Register-ScheduledTask -TaskName "BSB Knowledge Nightly" -Trigger (New-ScheduledTaskTrigger -Daily -At 4:30am) -Action (New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -ExecutionPolicy Bypass -File ...run_nightly.ps1") -Settings (New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3))`.
- Run it, `Get-ScheduledTask -TaskName "BSB Knowledge Nightly"` -> Ready. Run once by hand with `Start-ScheduledTask`, check `nightly.log`.
- Commit `feat(kb): nightly scheduled run`.

## Phase 5: candidates + cleanup (later)
- Task 13: `candidates` verb (yt-dlp `ytsearch20:` per taxonomy keyword, channel roll-up, write `_review/candidates.md`) on a weekly trigger.
- Task 14: separate `/tidy` pass on the rest of the vault (Zac's item a). Not part of this branch of work.
