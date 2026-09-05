---
type: project
domain: training-knowledge
status: approved-design
created: 2026-09-04
updated: 2026-09-04
---
# Training Knowledge Base - Design

A personally owned, agent-maintained knowledge base of baseball training
philosophy: throwing, hitting, strength, anatomy and movement, research. Built
from the public output of coaching organizations (video + blog), kept current
by a nightly job, audited by Zac in Obsidian, and independent of any Astros
system so it survives a job change.

Decisions taken 2026-09-04 (Zac):
- Lives INSIDE the existing vault `bsb-brain`. The vault's git origin moves to
  `BridgerBSB/bsb-brain` (personal); the Astros account becomes a second push
  remote (mirror), not the owner.
- Review happens IN OBSIDIAN, asynchronously. Every capture lands in a queue
  with my proposed tags; Zac edits whenever he gets to it; his edits become the
  training examples that tune the tagger.
- Backfill the full archives, oldest to newest, until the archive meets today.

## 1. Sources (v0)

| Source | Medium | Size | Scope rule |
|---|---|---|---|
| Driveline Baseball (YouTube `@drivelinebaseball`) | video | 510 | all |
| Tread Athletics (YouTube `user/treadathletics`) | video | 755 | all |
| Baseball Performance Center (YouTube `@baseballperformancecenter`) | video | 42 | **no hitting** |
| Driveline blog (`drivelinebaseball.com/blogs/blog`, 140 pages x 6) | blog | ~835 | all, save figures |
| Tread blog (`treadathletics.com/posts/`, RSS at `/feed/`) | blog | ~54 | all |

Future, same pipeline: X accounts (via `api.fxtwitter.com`), Baseball America
and similar for context-only, and channels the weekly discovery pass surfaces.

Facts that shaped the design: all 12 newest videos sampled carry English
auto-captions, so transcripts are free and Whisper is a rare fallback. Neither
Driveline page has RSS; Tread does. Driveline article images are Shopify CDN
screenshots (charts, tables) and are worth saving; hero photos are not.

## 2. Three layers (Karpathy LLM-wiki pattern, mapped onto this vault)

| Layer | Role | Where |
|---|---|---|
| Raw, immutable | what the source actually said | `sources/_raw/<source>/<id>.md` transcript or article markdown; `sources/_assets/<source>/<slug>/` images |
| Compiled, agent-owned | the knowledge | `sources/<source>/<date>-<slug>.md` (one per item), `cues/<slug>.md` (atomic), `concepts/<slug>.md` (existing topic layer, enriched), `MOC-*.md` hubs |
| Schema | the rules the agent follows | `_pipeline/taxonomy.md` (definitions + Zac's worked examples), a "Training knowledge" section in the vault `CLAUDE.md`, `templates/source.md`, `templates/cue.md` |

Every claim in a source note cites its raw file and, for video, a timestamp.
The raw layer is never edited. `_pipeline/log.md` is append-only.

## 3. Folder layout (additions only; existing folders untouched)

```
bsb-brain/
  sources/
    driveline/  tread/  bpc/        one note per video or post
    _raw/<source>/<id>.md            transcript (timestamped) or article markdown
    _assets/<source>/<slug>/*.png    article figures
  cues/                              one note per training cue
  _review/                           pending queue (notes move OUT when approved)
    contradictions.md                lint output: sources that disagree
    candidates.md                    weekly discovery: channels/accounts to consider
  _pipeline/
    sources.yml                      the source list + scope rules
    taxonomy.md                      domain/kind/value definitions + worked examples
    examples/                        one file per Zac correction (before/after)
    state.json                       seen ids, per-item status, retry counts
    log.md                           append-only run log
    failed.md                        items that need a human
    kb.py                            the CLI
    prompts/summarize.md             the summarizer instructions
  MOC-training-knowledge.md          hub: pitching / hitting / strength / anatomy / research
  MOC-pitching.md  MOC-strength.md  MOC-anatomy.md   (MOC-hitting exists)
```

Gitignore adds `00-inbox/transcripts/` (1.4 GB of Claude session logs, must
never reach GitHub) and `sources/_raw/**/*.audio.*` (Whisper scratch).

## 4. Note schemas

### Source note (`sources/<source>/<date>-<slug>.md`)
```yaml
type: source
source: driveline | tread | bpc
medium: video | blog
title:
url:
published: YYYY-MM-DD
author:              # blog; channel for video
duration_s:          # video
domain: [pitching]   # one or more of: pitching, hitting, strength, anatomy-movement, mental, business
kind: instruction | philosophy | research | athlete-story | interview | marketing
value: high | med | low | skip
status: pending | approved | edited | rejected
raw: sources/_raw/driveline/<id>.md
cues: []             # [[cue-...]] wikilinks
concepts: []         # [[concept]] wikilinks into concepts/
confidence: agent    # becomes "zac" once he has touched it
```
Body sections, in order: **TL;DR** (3 lines) · **Claims** (each with `[mm:ss]`
or section anchor, and any numbers the source gives) · **Cues** (verbatim
phrasing, the problem it fixes, who it is for) · **Evidence cited** · **Open
questions / disagreements with other sources** · **Links**.

### Cue note (`cues/<slug>.md`)
```yaml
type: cue
domain: pitching
phrase: "..."            # the words a coach would actually say
fixes: "..."             # the fault it targets
population: "..."        # youth / pro / lefties / etc, if the source says
sources: []              # every source note that uses it
status: pending | approved
```
One cue per note. A cue that two sources phrase differently is ONE note with
both phrasings and both citations. Contradictions are recorded, not resolved.

### Concept notes
Existing `concepts/` convention holds (the `/ingest` command's rules: atomic,
under ~150 words, `type` / `domain` / `source` frontmatter, `## Links`). The
pipeline appends a `## From sources` list to a concept when a source note
supports it; it never rewrites a concept's definition without review.

## 5. Taxonomy v0 (the thing Zac's audits will reshape)

- **domain**: pitching · hitting · strength · anatomy-movement · mental · business.
  Multi-valued. BPC + hitting = `value: skip` automatically.
- **kind**: instruction (teaches how) · philosophy (why / what to believe) ·
  research (data, study, method) · athlete-story (a player's arc, usually
  marketing-adjacent) · interview · marketing (program sales, recruiting).
- **value**: high (would change how we coach or evaluate) · med (useful
  context) · low (one-line record only) · skip (not filed as knowledge; the
  raw file is still kept).
- Default routing: `marketing` -> low, `athlete-story` -> med unless it
  carries numbers, `instruction` / `research` / `philosophy` -> high.

## 6. The pipeline (`_pipeline/kb.py`)

Pure Python for everything that touches the network; headless Claude only for
the summarize step. One CLI, five verbs, all idempotent against `state.json`.

1. **discover** - yt-dlp flat playlist per channel (`--js-runtimes node`), page
   scrape for Driveline blog, RSS for Tread. New ids go into state as `new`.
2. **fetch** - captions via `youtube_transcript_api` (manual English first,
   then auto); fallback `yt-dlp` audio + `faster_whisper` with the bundled
   `imageio_ffmpeg` binary. Blogs through `trafilatura` (markdown, images,
   metadata). Writes the raw file with a frontmatter header. Status `fetched`.
   Article images: download body figures over 300 px wide into `_assets/`,
   skip the hero.
3. **summarize** - `claude -p` with `prompts/summarize.md` + `taxonomy.md` +
   the last N correction examples for that source + the raw file. Output is
   the source note written to `_review/`. A cheap triage pass (Haiku) first
   assigns `kind`; only non-marketing items get the full Sonnet pass. Status
   `summarized`.
4. **promote** - for every `_review/` note whose status is no longer
   `pending`: move it to `sources/<source>/`, create or update cue notes,
   append to concepts' `## From sources`, update MOCs, and if Zac changed
   anything, write the before/after diff to `_pipeline/examples/`. Then
   `git add` by explicit path, commit, push to both remotes.
5. **lint** - orphan cues, source notes with no concept links, `[[links]]` that
   resolve nowhere, two sources making opposite claims on one concept
   (written to `_review/contradictions.md`), items stuck in `failed` for more
   than 3 runs.

Plus **candidates** (weekly): yt-dlp search on taxonomy keywords, list channels
not in `sources.yml` with subscriber count and a sample of titles into
`_review/candidates.md`. Zac marks the ones to add.

### Backfill
`kb.py backfill --source driveline --batch 25` walks the archive oldest to
newest. The first run of each source is a 10-item calibration batch from the
NEWEST end (most representative of what they believe now); Zac audits those
before the archive walk starts. Throttled with a 2-3 s sleep per network call.

### Scheduling
Windows Task Scheduler, nightly 04:30 local, on this laptop:
`discover` -> `fetch` -> `summarize` -> `promote` -> `lint`, then one backfill
batch per source if the queue holds fewer than 40 pending notes (so the queue
never outruns Zac). Claude Desktop local tasks were considered; they need the
app open. Cloud routines cannot reach YouTube or the vault. Missed nights are
harmless because every step is idempotent.

Headless runs bill the `ANTHROPIC_API_KEY` set on this machine, not the
claude.ai plan. Estimated full backfill: ~2,200 items, Haiku triage on all,
Sonnet on roughly half. Order of $100-200 total, spread over weeks.

## 7. The audit loop (how Zac trains the tagger)

- A pending note shows my `domain`, `kind`, `value`, and the cue list.
- Zac changes any field, edits or deletes cues, or writes a line under
  `## Zac` and sets `status: approved | edited | rejected`.
- `promote` records each change as an example: the raw excerpt, my proposal,
  his correction, and his note if any. The summarize prompt loads the most
  recent 15 examples for that source plus any marked `pin: true`.
- After 30 audited items per source, the run log reports agreement rate per
  field. When `kind` agreement is above 90 percent, `marketing` and `low`
  items stop entering the queue and are filed directly (still visible under
  `sources/`, still reversible).

## 8. Error handling

- Every item has a status and a retry count in `state.json`; nothing is ever
  dropped. Three failures moves it to `failed.md` with the reason.
- A caption fetch that returns a non-English track falls back to Whisper.
- A blog fetch that returns under 500 characters is treated as a failure, not
  a short post.
- Network throttling: exponential backoff on HTTP 429 / yt-dlp errors.
- The summarizer must return valid frontmatter; a note that fails the schema
  check is retried once, then failed.
- Git push failure never blocks the run; the next run pushes.

## 9. Testing

- Unit tests (no network): frontmatter schema validation, state transitions,
  slug generation, the promote diff-to-example writer, the lint rules against
  a fixture vault.
- Recorded fixtures: one transcript, one Driveline article, one Tread article.
- A `--dry-run` on every verb that prints what it would do.
- The first real run is the 10-item calibration batch, inspected by hand.

## 10. Out of scope for this build

- Vault-wide dedupe and cleanup of `bsb-brain` (Zac's item a). That is a
  separate `/tidy` pass after the pipeline lands, so the two changes do not
  tangle in one commit history.
- Video frame extraction (a "watch the demo" layer). Transcripts first.
- Twitter/X monitoring. The source list has the slot; the fetcher is a later
  verb.

## 11. Phases

1. Repo re-home + gitignore + schema files + templates + MOCs. Commit.
2. `kb.py` discover / fetch / summarize with tests. Calibration batch: 10 per
   source into `_review/`. Commit.
3. `promote` + `lint` + examples loop. Zac audits the calibration batch.
4. Scheduler task + backfill throttle. Nightly runs begin.
5. Weekly candidates pass. Then the separate `/tidy` cleanup.

## Links
[[MOC-training-knowledge]] · [[MOC-hitting]] · [[MOC-pitching]] ·
[[meta/youtube-to-vault-pipeline-research]] · [[meta/claude-code-obsidian]] ·
[[meta/obsidian-optimization]] · [[concepts/podcast-transcription-pipeline]] ·
[[rules/external-resource-capture]]
