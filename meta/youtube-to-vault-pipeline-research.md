---
type: reference
domain: meta
source: web research 2026-09-04 for the training knowledge base build
created: 2026-09-04
updated: 2026-09-04
---
# YouTube / blog -> Obsidian pipeline: what people do (research capture)

Captured 2026-09-04 while designing [[projects/training-knowledge/design]].
Per [[rules/external-resource-capture]]: summary + link for every source, so
none of this has to be re-fetched.

## What Zac fed in

- **Andy Tran, "Claude Code + Obsidian: Turn YouTube Videos Into Notes"**
  (YouTube `x74VtvCj7as`, Jun 23 2026, 7 min). The recipe: install `yt-dlp`,
  give Claude a link, it pulls the transcript, summarizes, writes an `.md`
  into the vault; run several sessions in parallel; extend to "build me a
  plan from this video". Nothing about monitoring channels or taxonomy.
  <https://www.youtube.com/watch?v=x74VtvCj7as>
- **Productive Dude, "Claude Code + Obsidian is INSANE!"** (YouTube
  `DoRQo3aGaPY`, Apr 16 2026, 9 min). Ingests iMessage, ChatGPT, Claude
  history and tracked YouTube channels into one graph; tags videos hot / fire
  / warm / cold by view velocity; has Claude write Obsidian graph-view color
  configs by tag. The useful idea for us: **channels as nodes, keywords as
  nodes, videos link both**, and tag-driven graph coloring for review.
  <https://www.youtube.com/watch?v=DoRQo3aGaPY>
- **Ray Fu newsletter, "6 GitHub repos that make money"** (email PDF, Sep 3
  2026). autoclip_mvp, Remotion, OpenHands, PersonaLive, RedInk, MuMuAINovel.
  None is a YouTube reader; not relevant to this build beyond "read the
  LICENSE first".
- Reddit r/ObsidianMD "how do you handle learning from YouTube videos" -
  **not fetched** (reddit blocks the fetcher). Bare link kept:
  <https://www.reddit.com/r/ObsidianMD/comments/1ui698v/how_do_you_handle_learning_from_youtube_videos_in/>

## Existing tools worth stealing from

| Tool | What it does | What we took |
|---|---|---|
| [JimmySadek/youtube-fetcher-to-markdown](https://github.com/JimmySadek/youtube-fetcher-to-markdown) | Claude skill; captions direct from YouTube, yt-dlp for metadata/chapters, frontmatter (`title channel url video_id fetched language caption_type duration upload_date tags`), dedup by scanning existing frontmatter, exit code 3 on duplicate | the frontmatter field set and "truthful fallback to English" |
| [BayramAnnakov/youtube-playlist-to-markdown](https://github.com/BayramAnnakov/youtube-playlist-to-markdown) | whole-playlist batch, `--start/--end`, `--skip-existing`, fallback chain captions -> Gemini -> chunked audio | the batch + resume shape |
| [taoufik123-collab/claude-watch](https://github.com/taoufik123-collab/claude-watch) | scene-change frames + transcript + structured report | the future "watch the demo" layer (frames), deferred |
| [Astro-Han/karpathy-llm-wiki](https://github.com/Astro-Han/karpathy-llm-wiki) and the [StarMorph guide](https://blog.starmorph.com/blog/karpathy-llm-wiki-knowledge-base-guide) | Karpathy's Apr 2026 pattern: `raw/` immutable, `wiki/` agent-owned, `CLAUDE.md` schema; ops = ingest / query / lint; `index.md` + append-only `log.md`; lint = contradictions, orphans, missing concepts, stale claims | **the whole architecture** (sections 2 and 6 of the design) |
| [eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) | `/x-read` for X threads, scheduled agents that maintain the vault overnight | the X slot in `sources.yml`; confirms fxtwitter path |
| [Tapestry youtube-transcript skill](https://claudemarketplaces.com/skills/michalparkola/tapestry-skills-for-claude-code/youtube-transcript) | yt-dlp subtitle ladder: manual -> auto, list tracks first | the caption preference order |

## Facts that decided things

- **Captions are nearly universal on our three channels.** 12 of 12 newest
  videos (Tread, Driveline) have English auto-captions; `youtube_transcript_api`
  returned them in under a second each with no download. Whisper
  (`faster_whisper`, already installed) is the fallback, using the ffmpeg
  binary bundled in `imageio_ffmpeg` (fine on the personal laptop).
- **The home IP gets rate-limited too, just later.** First calibration run,
  2026-09-04: about 15 caption pulls in quick succession, then every further
  request came back `IpBlocked`, and yt-dlp's own subtitle download hit HTTP
  429 on the same endpoint (video/audio downloads still worked). The block
  lasted over an hour. The pipeline now treats a block as "throttled, retry
  next run" rather than a failure, spaces caption fetches 12 s apart, and
  backfills 8 videos per source per night. Whisper on downloaded audio is the
  escape hatch if the limit ever tightens further.
- **Shopify truncates `<title>` and `og:title` at ~70 characters** on the
  Driveline blog ("...built a modern hitti"); the JSON-LD `headline` is
  complete. **Tread posts carry animated GIF highlight loops** (7 MB) that a
  naive figure saver keeps; skip gif/svg and cap at 2 MB.
- **Cloud IPs are blocked by YouTube** for the transcript API in 2026
  ([issue #593](https://github.com/jdepoix/youtube-transcript-api/issues/593)),
  so the fetch step runs on the home laptop, not in a cloud routine.
- **Claude Code scheduling options** ([docs](https://code.claude.com/docs/en/desktop-scheduled-tasks)):
  cloud routines = no local files; Desktop local tasks = need the app open and
  the machine awake, one catch-up run after a missed night; `/loop` = session
  only. Windows Task Scheduler + `claude -p` is the choice: no app dependency,
  and `claude -p` verified working headless here (bills the API key set on
  this box, not the claude.ai plan).
- `yt-dlp` on this box needs `--js-runtimes node` (no deno). It lists a 510
  video channel in ~20 s.
- Blog extraction: `trafilatura` returns markdown + images + author/date for
  both Driveline (Shopify) and Tread (WordPress). Tread has RSS at
  `treadathletics.com/feed/`; Driveline has none, so page 1 is scraped.
  Driveline blog = 140 pages x 6 posts, oldest is "Welcome to Driveline
  Baseball" on page 140.
- Console output must be UTF-8 (`PYTHONIOENCODING=utf-8`) or a curly quote in
  an article crashes the run (hit it on the first Tread post).

## Obsidian-side plugins considered (none adopted yet)

YTranscript (transcript side pane with clickable timestamps), Media Extended
(inline player, timestamp links), Obsidian Timestamp Notes. Useful if Zac
starts watching inside Obsidian; the pipeline writes `[mm:ss]` anchors as
plain YouTube `?t=` links so they work with or without a plugin.

## Links
[[projects/training-knowledge/design]] · [[claude-code-obsidian]] ·
[[obsidian-optimization]] · [[loop-engineering]] · [[context-library]]
