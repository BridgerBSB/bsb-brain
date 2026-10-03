---
name: arm-farm-trend-leaderboards-status
description: "Trend Leaderboards sub-tab (HOU WoW/MoM/YoY gainers) — Arm Farm tracker PoC, Jun 23 2026"
metadata: 
  node_type: memory
  type: project
  originSessionId: aca677f8-14ad-46d9-9cf3-db44531ca919
---

**Trend Leaderboards LIVE on ALL 6 affiliate trackers — Jun 27 2026 enhancement
TESTED WORKING by Zac on the affiliate trackers.** Files: Arm Farm
`bullpen-report/pages/3_Affiliate_Tracker.py`, Barrelsville `pages/2_Affiliate_Tracker.py`,
Intangibles `src/{br,catching,fielding}_tracker_page.py` (fielding powers BOTH OF+IF).

**Jun 27 2026 enhancement (on top of the original WoW/MoM/YoY boards):**
1. **Start/End period dropdowns per board** — `_board` takes explicit start/end keys
   (was hardcoded last-two); `_periods` builds options; `_one_board` renders 2 narrow
   selectboxes per board. **Default index len-2/len-1 → latest two, on-load UNCHANGED.**
   Keyed + stale-key prune.
2. **Bold HOU on Org boards** — `_bold_hou_row` Styler `.apply(axis=1)`: org scope only,
   bold + peach `#FCE9D6` + navy left accent. `_render(res, prev_lbl, cur_lbl)`.
3. **Weekly labels carry year** — `_plabel` weekly → `strftime("%b %d '%y")` (disambiguates
   multi-season weeks in dropdowns + headers).

**SPEED MODEL (BLOCKING lesson):** boards reuse the Trends tab's already-loaded frames →
can't be slower than Trends. YoY pulls the SINGLE prior season via `_augment_yoy` (pinned,
cached) — the only extra load. **DON'T eager-load all pinned years for the year dropdown**
(Jun 27 misstep, reverted — made the tab fire up 3-4 cold pin reads slower). Further-back
years = add the season in the sidebar (same full-reload cost Trends pays). `[TL-YoY]` timing
`print` wraps the augment loader so Connect logs reveal cache-hit/pin/live — **~30s = a
missing historical pin → one-time `pin_tracker_seasons` backfill, NOT a code bug.**

**Commits:** Barrelsville `47e856d9`→`b680429d`→`4773993c`; Arm Farm `15962c79`;
Intangibles (BR+Catching+OF+IF) `be4bd4c6`. Per-tracker hooks (selectbox prefix +
augment loader arity) tabled in the canonical doc.

**>>> CANONICAL DOC = `.claude/rules/trend-leaderboards.md` <<<** (full anatomy +
PORT RECIPE + the Jun 27 enhancement section, synced byte-identical to all 4 worktrees).

**Slow-first-load diagnosis (Jun 27-28):** the boards reuse Trends' frames, so the ONLY
extra cost vs Trends is the YoY board's **prior-year (2025) pull** via `_augment_yoy` —
Trends with 1 season never loads 2025, the leaderboards do. If 2025 isn't pin-hit that's
a ~30s live query = the entire "Trends fast / Leaderboards slow" gap. A pinned year can
still MISS → live for 3 reasons (per `_try_pin_bundle`): wrong grain not in pin coverage
(esp. **org-yearly**), the active **hand/HA split combo** not pinned (pins are per-combo),
or non-R sched type. The `[TL-YoY] prior-year 2025 load: __s` print in `_augment_yoy`
reveals it: ~2s = pinned/fine, ~30s = miss. NOTE: reordering tabs does NOT help (st.tabs
runs every body each render); real speedup would be lazy keyed-selector tabs (deferred).

**Fix = one-time historical pin backfill** (NOT recurring): `pin_tracker_seasons.py --year 2025`
(hitting + Arm Farm), `pin_br/catching/fielding_tracker_seasons.py --year 2025` (intangibles).
Omit `--year` to pin all of 2022-2025. Needs CONNECT_API_KEY set in the PS session. 2026
stays live by design.

**STATE @ Jun 28 2026:** Hitting (Barrelsville) 2025 **REPINNED** → its slow YoY load
should be closed. **STILL OPEN:** (1) pin 2025 for the other 4 trackers (Arm Farm / BR /
Catching / Fielding) IF they show the same slow first load — same commands; (2) **redeploy
the 3 Connect apps** (Barrelsville, Arm Farm, Intangibles) via `rsconnect deploy manifest`
so the new Trend Leaderboards goes live in production (code is on the feature branches,
tested working on affiliate trackers, not yet redeployed). See [[arm-farm-pitch-efficiency-shipped]].
