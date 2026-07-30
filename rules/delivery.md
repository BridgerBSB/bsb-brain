---
paths:
  - "**/deliver.py"
  - "**/scripts/generate_*.py"
---

# Report Delivery Pipeline

## Architecture
Python → base64 PDF → POST to Azure Logic App HTTP trigger → Slack file upload
```
Python generates PDF
  → parses groundcontrol_id from filename (or uses explicit channel)
  → looks up channel_id in slack_channels.csv
  → requests.post(LOGIC_APP_URL, json={"channel": "C...", "filename": "...", "pdf": "<base64>"})
  → pd-report-delivery → astros-file-uploader → Slack channel
```
**Python handles ALL routing — Azure is a dumb pipe.**

## Payload Shape — BLOCKING

The Logic App expects **exactly three fields** with these exact names:

```python
payload = {
    "channel": channel_id,   # "C..." Slack channel ID
    "filename": filename,    # os.path.basename(pdf_path)
    "pdf": pdf_b64,          # base64.b64encode(pdf_bytes).decode("utf-8")
}
requests.post(logic_app_url, json=payload, timeout=60)
```

**SILENT FAILURE MODE:** The Logic App returns HTTP 200/202 for any JSON body, even if the fields are wrong. If you name the base64 field `content_base64`, `file`, `data`, `body`, etc., the HTTP call succeeds, the script prints "Delivered to C...", but **nothing appears in Slack**. There is no error. Only missing files are the signal.

**Rules:**
1. **NEVER write a `_deliver_pdf` function from scratch.** Copy from any working script: `generate_of_report.py`, `generate_br_daily_report.py`, `generate_if_report.py`, `generate_catcher_report.py`.
2. **Field name for base64 is `pdf`**, not `content_base64`, not `file`, not `attachment`. No exceptions.
3. **Do NOT add extra fields** (`message`, `text`, `caption`, etc.) — the Logic App ignores them but their presence suggests the original author didn't read a reference.
4. **If you see "Delivered to C..." but nothing in Slack**, the first thing to check is payload field names, not Slack bot membership.

**Historical incident (Apr 17, 2026):** `mazzo_special.py` was written with `"content_base64"` instead of `"pdf"`. Delivered successfully with HTTP 200 for a day before user noticed the channel was empty. Fix: rename field. Root cause: payload written from memory instead of copied from a sibling script. Violates CLAUDE.md blocking rule #1 (read existing sibling implementations first).

## Two Channel Types (zzz_ vs z_) — BLOCKING

| Channel Type | Column in CSV | Purpose | Example |
|---|---|---|---|
| **zzz_** (coach) | `channel_id` | Coach-facing reports (postgame, KPI, analysis) | `zzz_john_smith` |
| **z_** (athlete) | `z_channel_id` | Player-facing reports (goals, development) | `z_john_smith` |

**NEVER rename a zzz_ row to z_.** They are DIFFERENT channels. When adding a z_ channel for a player, ALWAYS add a NEW row. The zzz_ row must remain untouched. Both rows must exist in the CSV.

**`pd-goals/data/slack_channels.csv`** has BOTH columns:
- `groundcontrol_id` — player's GC ID (join key)
- `channel_id` — zzz_ coach channel ID (primary for most reports)
- `z_channel_id` — z_ athlete channel ID (for player-facing delivery)

## Two Delivery Functions

### `send_reports_via_logic_app()` — Per-Player Routing
Used by: postgame (Arm Farm, Barrelsville), BR, OF/IF daily
```python
send_reports_via_logic_app(
    pdf_dir,
    logic_app_url,
    channel_col='channel_id',    # 'channel_id' (zzz_) or 'z_channel_id' (z_)
)
```
**Routing:** Filename → parse groundcontrol_id → CSV lookup → channel_id → POST
**Fallback chain:** z_channel_id → zzz_channel_id (fallback) → overflow channel
**Overflow:** `pd-automation-test` channel (`C0ABHSF6SCA`) — catches players without a mapping

### `send_to_channel()` — Explicit Channel Routing
Used by: advance batch (Barrelsville), IF per-affiliate, KPI reports
```python
send_to_channel(
    pdf_paths,
    channel_id='C0ABC123DEF',   # explicit channel, no CSV lookup
    logic_app_url=url,
)
```
**No routing logic** — caller provides the channel directly. Used when delivering to team/level channels instead of per-player channels.

## deliver.py — Three Copies (Same Pattern)

| Project | File | Notes |
|---------|------|-------|
| Arm Farm | `bullpen-report/src/deliver.py` | Original, both functions |
| Barrelsville | `barrelsville/src/deliver.py` | Copy, both functions |
| Intangibles | `intangibles/src/deliver.py` | Copy, both functions |

All three are functionally identical. They read from the same `pd-goals/data/slack_channels.csv`.

## Combined Weekly KPI Stapler — Affiliate Channels (Apr 28 2026)

The 6 weekly KPI reports (Hitter, Pitcher, OF, IF, BR, Catcher) each
deliver to their per-domain Slack channel via this `delivery.md` pipeline.
But the affiliate-channel deliveries (`z1_sugar_land`,
`z2_corpus_christi`, etc.) are NOT done by the 6 individual scripts —
they're owned exclusively by `pd-goals/scripts/generate_combined_kpi.py`,
which runs after the 6 finish, staples the per-level PDFs into ONE
combined PDF per level, and POSTs once to each affiliate channel.

**Full pattern + BLOCKING rules + channel routing live in
`combined-kpi-stapler.md`.** Read that before touching any KPI weekly
script or the stapler. Key consequence: never re-add affiliate-channel
delivery to any of the 6 individual KPI scripts.

## Intangibles Per-Affiliate Channel Routing

IF/OF daily and KPI reports deliver to **team-level channels** (not per-player), using `send_to_channel()` with hardcoded channel IDs:

| Route Key | Channel | Channel ID | Used By |
|-----------|---------|------------|---------|
| mlb | pd-automation-test | `C0ABHSF6SCA` | Placeholder/overflow |
| aaa | sugarland_intangibles | `C0AKNKW1UKU` | IF/OF daily, KPI |
| aax | corpus_intangibles | `C0AL1HM1CDP` | IF/OF daily, KPI |
| afa | asheville_intangibles | `C0AK76YS1NK` | IF/OF daily, KPI |
| afx | fayetteville_intangibles | `C0AKNL9BGN6` | IF/OF daily, KPI |
| rok | fcl_intangibles | `C0AKG8WA267` | FCL/ACL games |
| dsl | dsl_intangibles | `C0AK777QM47` | DSL games |

### Weekly OF/IF Delivery — No-Play Gate (Jun 22 2026)

The OF/IF **weekly** batch scripts (`generate_of_weekly_batch.py` /
`generate_if_weekly_batch.py`) gate **delivery** on whether the player
actually made a play that week — but keep **generation** multipurpose.

- **Two distinct filters, don't conflate them:**
  1. **Played the position?** The player-finder + games query require
     `pg.pos_id IN (7,8,9)` (OF) / infield positions (IF). A pure DH who
     never took the field never enters the batch at all — not generated,
     not delivered.
  2. **Had a play happen to him?** NEW gate: each generated report carries
     `n_plays = len(plays_df)`. At the delivery step, `deliver_reports`
     keeps only `n_plays > 0`; `n_plays == 0` (appeared at the position but
     no ball/play) is skipped and printed. Applies to **all three** modes
     (`--deliver`, `--deliver-z`, `--deliver-level`). If nobody made a
     play, nothing is delivered and the script exits cleanly.
- **No new CLI flag** — the gate is automatic on the existing deliver
  flags, so the weekly cascade command is unchanged. (A future
  `--deliver-empty` opt-out would be the place to re-enable no-play
  delivery if ever wanted.)
- **Gate metric is `plays_df` (any play), NOT `n_comp_plays`** (Tier-1
  competitive plays). If a stricter "no competitive play" gate is ever
  wanted, swap the `n_plays` source — one-line change in both scripts.
- **Latent bug fixed same change:** OF stored `"level": level` (a stale
  loop leftover = last player's level) in the generated dict, mis-routing
  every OF `--deliver-level` post to one channel. Now `roster_level`,
  matching IF. Commit `f43b0db1` on `feature/astros-intangibles`.

### Barrelsville + Arm Farm Fixed Channels

| Channel | Channel ID | Used By |
|---------|------------|---------|
| milb_boxscores | `C0APYUYFYMP` | All boxscore PDFs (Barrelsville, single channel, all levels) |
| weekly-player-updates | `C0AVBKPEG8H` | Org-wide analysis + KPI snapshot PDFs (Zac + Sam). See "Analysis + Snapshot Delivery" below. |

## Analysis + Snapshot Delivery (Org-Wide, Single Channel)

Org-wide PDFs (one PDF per run, not per-player) ship via `send_to_channel()`
with the channel ID hardcoded in the script. Currently routed to
**weekly-player-updates** (`C0AVBKPEG8H`). All scripts use the same
`--deliver` + `--logic-app-url` CLI pattern.

### Wired (Apr 24-25, 2026)

| Script | Branch | Audit Status | Delivery Mode |
|---|---|---|---|
| `barrelsville/scripts/hitter_analysis.py` | `feature/barrelsville` | ✓ Clean — matches postgame_data + hitter_kpi_data | Single PDF |
| `barrelsville/scripts/kpi_snapshot_3.py` | `feature/barrelsville` | ✓ Clean — imports canonical helpers, all 7 hitting traps pass | Single PDF |
| `bullpen-report/scripts/pitcher_analysis.py` | `feature/bullpen-reports` | ✓ Clean — matches pitcher_kpi_data + canonical pitch-codes.md | **Auto-split** (3 level groups) |
| `bullpen-report/scripts/pitcher_kpi_snapshot.py` | `feature/bullpen-reports` | ✓ Clean — uses correct (broader) WHIFF_CODES + BIP_CODES | Single PDF |
| `bullpen-report/scripts/spring_comparison.py` | `feature/bullpen-reports` | Not metric-audited (comparison report, not a metric source) | Single PDF |

### Pitcher Analysis — Auto-Split Delivery (HTTP 413 Mitigation)

**Pitcher analysis is the ONLY org-wide script that auto-splits today.** The
6-pages-per-pitcher output (4 KDE density pages + 2 table pages) at full org
size (~120 pitchers) exceeds the Logic App HTTP trigger payload limit (~100MB
after base64 encoding). First Apr 25 delivery returned `HTTP 413 Request
Entity Too Large`.

**Split shape: 50/50 over the pitcher list.** NOT by level-group. A
pitcher who moved from A+ to AAA mid-season needs his entire pitch
picture in one report, not split by primary level. We halve the
`player_data` list (which already contains each pitcher's full
multi-level data) and emit one PDF per half:

| Half | Filename suffix |
|---|---|
| First ⌈N/2⌉ pitchers | `_Part1.pdf` |
| Remaining ⌊N/2⌋ | `_Part2.pdf` |

Each pitcher's report is COMPLETE — all levels, all sched_types within
the run's filters. We only split the *list*, not the *data per pitcher*.

**Trigger:** explicit `--split` flag — user opts in. Default behavior is
a single full-org PDF (will return HTTP 413 if file is too large; that's
the user's signal to retry with `--split`).

```bash
# Default: one PDF (may 413 on full org)
python scripts/pitcher_analysis.py --season 2026 --deliver --logic-app-url "..."

# Two-PDF split when needed
python scripts/pitcher_analysis.py --season 2026 --deliver --split --logic-app-url "..."

# Single-level runs always one PDF, --split is irrelevant
python scripts/pitcher_analysis.py --season 2026 --levels aaa --deliver --logic-app-url "..."
```

**Implementation:** `--split` argparse flag + `filename_suffix` kwarg on
`generate_report()` + `do_split = args.deliver and args.split` branch in
`main()`. Original implicit-auto-split (no `--levels` → split) was
removed Apr 25 after user feedback — they want explicit control over
when delivery splits.

### Why hitter_analysis.py does NOT auto-split

Hitter analysis pages per player are lighter (no per-pitch-type KDE quartet)
so the full org PDF fits comfortably under the 100MB trigger limit. If
hitter ever 413s (e.g. roster grows, pages get heavier), copy the
auto-split block from `pitcher_analysis.py` — same shape applies. Note
left at the deliver block in `hitter_analysis.py` for future agents.

### Advance Batches — Auto-Chunk the Series ZIP (HTTP 413 Mitigation)

**Different delivery shape, different fix.** The org-wide analysis scripts
above POST ONE big PDF and split it 50/50 via `--split`. The **advance
batch** scripts instead build **per-pitcher PDFs → one ZIP per upcoming
series → POST the ZIP**. When a series has enough heavy PDFs, that single
ZIP crosses the Logic App ~100 MB base64 cap → `HTTP 413 Request Entity
Too Large` → **0 ZIPs delivered** (reports generate fine; only the POST is
rejected).

**Fix: auto-chunk the ZIP** (NO flag — automatic, scales with the roster).
Any batch script that ZIPs PDFs and POSTs must split a too-big series into
`_part1ofN` ZIPs, each kept under a base64 budget:

```python
MAX_PAYLOAD_B64_BYTES = 40 * 1024 * 1024  # 40 MB base64 (proven-safe; cap is ~100 MB)

def _b64_len(raw: bytes) -> int:
    return ((len(raw) + 2) // 3) * 4   # base64 length without allocating the string

def _build_series_zip_chunks(pdf_paths, series_folder_name) -> list:
    """Greedily pack PDFs into ZIPs, each under the payload budget.
    Returns [(zip_bytes, n_pdfs), ...] -- one chunk if it fits, _partNofM otherwise."""
    chunks, current = [], []
    for p in pdf_paths:
        trial = current + [p]
        if _b64_len(_build_series_zip(trial, series_folder_name)) > MAX_PAYLOAD_B64_BYTES and current:
            chunks.append((_build_series_zip(current, series_folder_name), len(current)))
            current = [p]
        else:
            current = trial
    if current:
        chunks.append((_build_series_zip(current, series_folder_name), len(current)))
    return chunks
```

Filename: single chunk keeps `<aff>_<series>.zip`; multi-chunk becomes
`<aff>_<series>_part{ci}of{n}.zip`. The existing per-level delivery loop
POSTs each chunk unchanged. PDFs are already-compressed, so `ZIP_DEFLATED`
barely shrinks them — rebuild-and-measure per PDF is fine (n is small, ~21).

| Script | Worktree | Delivery shape | 413 fix |
|---|---|---|---|
| `bullpen-report/scripts/generate_advance_pitching_batch.py` | `feature/bullpen-reports` | per-pitcher PDFs → ZIP/series | **auto-chunk** (Jun 2026) |
| `barrelsville/scripts/generate_advance_batch.py` (hitting advance) | `feature/barrelsville` | per-opposing-pitcher PDFs → ZIP/series | **auto-chunk** (Jun 2026, mirrored) |
| `intangibles/scripts/generate_hitter_advance.py` (fielding advance) | `feature/astros-intangibles` | **individual PDFs** via `send_to_channel` | none needed — no ZIP, each PDF is small |

**`--series` default = 1 (upcoming series only)** on all three advance
scripts (Jun 2026 user direction). Each series is its own ZIP/post anyway;
the default just stops building the series-after. `--series 2` is the
opt-in CLI override (hitting advance: `--series 0` falls back to the
`--days` window). The Monday cascade passes `--series 1` explicitly too
(redundant with the default, kept self-documenting).

**Pitfall:** raising `MAX_PAYLOAD_B64_BYTES` toward 100 MB cuts the number
of parts but flirts with the 413 line — the exact cap is unknown (the
original failing single ZIP 413'd at a size below ~100 MB). 40 MB is
proven-safe. Don't bump it without a known-good MB reading from a real run.

**Bug history (Jun 16 2026):** AAA pitching advance (`--level aaa`, 21
Sugar Land pitchers × 14-page heatmap PDFs) 413'd on the Monday run →
exit 90 in the cascade summary (delivery-failure sentinel) → 0 ZIPs
delivered. Fixed with auto-chunking on the pitching batch (`b660b082`),
mirrored to hitting (`de0cb0f8`); `--series 1` made the default across all
three (`986e2cd6` / `f99ac7b5` / `5ece2c90`) + cascade (`63533df2`).

### TBD — needs same `--deliver` wiring + audit

| Script | Notes |
|---|---|
| `intangibles/scripts/generate_kpi_snapshot.py` | Fielding (OF/IF/BR/C) KPI snapshot. Same shape as Barrelsville/Arm Farm snapshots — needs `--deliver` flag added + metric-audit run before shipping. Will be replicated to weekly-player-updates next. |

### Single-player analysis to per-player Slack channels — pending

User-prompted future work: replicate the analysis-script pattern but route
**per-player PDFs to each player's own zzz_/z_ Slack channel** (not the
org-wide weekly-player-updates channel). Will use `send_reports_via_logic_app()`
instead of `send_to_channel()` because filenames will encode `groundcontrol_id`.
See "send_reports_via_logic_app()" section above for the routing logic.

### Audit summary (Apr 25, 2026)

The 4 metric-audited scripts above were diffed against canonical references
(`postgame_data.py`, `hitter_kpi_data.py` / `pitcher_kpi_data.py`,
`pitch-codes.md`) and against the 7 known hitting parity traps in
`three-surface-parity.md`. All clean.

ONE incidental finding: `bullpen-report/src/postgame_data.py` uses narrower
WHIFF_CODES `(10,16,21,22,23)` and BIP_CODES `(12,13,14)` than the canonical
`pitch-codes.md` table (which includes `25` for bunt foul tip and `18,19,20`
for pitchout-hit-in-play). All other scripts (analysis + KPI snapshots + KPI
weekly) use the canonical broader sets. Real-world impact is tiny (rare
codes), but postgame's whiff% / Avg EV / pBrl% will drift fractionally
vs every other Arm Farm surface. Low-priority cleanup — fix when convenient.

## Setup Per Channel
Each channel needs:
1. `channel_id` in slack_channels.csv (for per-player routing) OR hardcoded in script (for team channels)
2. "Astros File Uploader" app added to channel via Slack Integrations

## CLI Pattern
```bash
# Per-player delivery (uses CSV lookup)
python scripts/generate_postgame.py --date 2026-03-15 --deliver --logic-app-url "https://..."

# Explicit channel delivery (advance batch, KPI)
# Channel is determined inside the script, not from CSV
python scripts/generate_advance_batch.py --level aaa --deliver --logic-app-url "https://..."
```

## In-App Delivery (Live Streamlit apps, NOT CLIs)

The Logic App is a dumb HTTPS endpoint. It doesn't care who's calling —
a CLI, a cron job, or a live Streamlit request handler all work.

For **user-triggered submissions** (forms inside a running app on Posit),
skip the CLI pattern entirely and POST directly from the Streamlit
submit handler. Full pattern in `in-app-submission.md`. Key points:

- Set `LOGIC_APP_URL` as an env var in the deployed app's Vars tab
  (Connect → Content → <app> → Vars). Same URL as CLIs use.
- Import `urllib.request` (or `requests`) and POST the SAME payload
  shape: `{"channel": cid, "filename": fn, "pdf": b64}`. Field names
  are still BLOCKING.
- Save to pin FIRST, then attempt delivery. If the POST fails the
  submission is still captured; delivery can be retried or logged.

First live deployment of this pattern: **Transition Report** (PD Engine,
Apr 24, 2026). See `pd-goals/src/transition_slack.py` for a clean wrapper.

## Logic App URL
From `--logic-app-url` CLI arg or `LOGIC_APP_URL` env var.

**Production URL:**
```
https://prod-23.southcentralus.logic.azure.com:443/workflows/3292e67eb848406cb462ebccc1e90974/triggers/When_an_HTTP_request_is_received/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FWhen_an_HTTP_request_is_received%2Frun&sv=1.0&sig=jWC_Z81adrGeLEEQ4WQBH0VSla1l7qDrP6IFpQAdnas
```

**Work laptop setup** — add to PowerShell profile (`$PROFILE`):
```powershell
$env:LOGIC_APP_URL = "https://prod-23.southcentralus.logic.azure.com:443/workflows/3292e67eb848406cb462ebccc1e90974/triggers/When_an_HTTP_request_is_received/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FWhen_an_HTTP_request_is_received%2Frun&sv=1.0&sig=jWC_Z81adrGeLEEQ4WQBH0VSla1l7qDrP6IFpQAdnas"
```
Then all CLIs pick it up automatically — no `--logic-app-url` flag needed.
