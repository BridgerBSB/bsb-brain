---
paths:
  - "pd-goals/**"
---
# PD Goals — WPA Plays (Card 3 + CLI)

> **Extracted from `pd-goals.md` 2026-05-19** to keep the parent rule under
> the article-recommended discoverability threshold. See parent for
> `## WPA Plays Report` pointer. Auto-loaded with the parent on any
> Python edit in `pd-goals/`.

---

## WPA Plays Report — Daily Top/Bottom Win Probability Swings (Apr 19, 2026)

Daily "highlight reel" of biggest WP-shifting plays per affiliate per game.

**Files:**
- `pd-goals/src/wpa_plays_data.py` — SQL + Python ranking
- `pd-goals/src/wpa_plays_report.py` — PDF rendering (matplotlib + plottable)
- `pd-goals/scripts/generate_wpa_plays.py` — batch CLI + Logic App delivery
- `docs/plans/2026-04-18-wpa-plays-report-design.md` — full design

**Scope:** 7 affiliates (mlb/aaa/aax/afa/afx/rok/dsl), one PDF per game per side (offense + defense). Doubleheaders = 2 PDFs per side per affiliate.

**SQL source:** `Astros.Win_Probability` (event-level `li`, `home_team_wp`, `home_team_wpa`) joined to `Events_View` + `Schedule_View` + `mlbam.teams` (both batting and fielding sides).

**Key pattern — home-team-centric WPA sign flip:**
`Win_Probability.home_team_wp` / `home_team_wpa` are from home team perspective. Flip per event via `top_of_inning`:
```sql
bat_wpa = CASE WHEN ev.top_of_inning = 1 THEN -home_team_wpa ELSE home_team_wpa END
fld_wpa = CASE WHEN ev.top_of_inning = 1 THEN  home_team_wpa ELSE -home_team_wpa END
bat_wp_pre  = CASE WHEN top=1 THEN 1-home_team_wp            ELSE home_team_wp END
bat_wp_post = CASE WHEN top=1 THEN 1-(home_team_wp+home_team_wpa) ELSE home_team_wp+home_team_wpa END
```
Same pattern for fld side (inverse). Any future per-team WPA queries must use this.

**Column resolution — BLOCKING:** Events_View has NO batter_id/pitcher_id/balls_before/strikes_before. Pull those from `Pitches_View` via an OUTER APPLY on the AB-ending pitch (`cur_event_id = ev.event_id`). Non-PA events (SB, pickoff) won't match and the columns come back NULL — expected, display as `—`.

**6-bucket ranking per game:**
- `off_top` / `off_bot` — 5 biggest +/- non-K offensive plays
- `off_ks` — 5 biggest-magnitude Ks suffered
- `def_top` / `def_bot` — 5 biggest +/- non-K defensive plays
- `def_ks` — 5 biggest Ks recorded

All buckets displayed WPA DESC so "higher is better" reads top-to-bottom every table.

**2×2 PDF layout:**
```
OFFENSE                              DEFENSE
┌────────────┬────────────┐          ┌────────────┬────────────┐
│ TOP 5      │ WP CHART   │          │ TOP 5      │ TOP 5 Ks   │
├────────────┼────────────┤          ├────────────┼────────────┤
│ BOTTOM 5   │ TOP 5 Ks   │          │ BOTTOM 5   │ WP CHART   │
└────────────┴────────────┘          └────────────┴────────────┘
```
WP chart = HOU WP timeline with 5 green dots (top-5 non-K) + 5 red dots (bottom-5 non-K), one x-tick per inning.

**Description aliases:** uses the same `_DESC_REPLACEMENTS` list as `intangibles/src/if_postgame_data.py:339`, plus ordinal forms (`"1st base"`, `"2nd base"`, `"3rd base"`). If you update aliases, update BOTH worktrees.

**Channel routing (per `rules/delivery.md`):**
- Offense → per-affiliate barrelsville channels (same map as `barrelsville/scripts/generate_hitter_kpi_report.py:29`)
- Defense → per-affiliate intangibles channels (documented in `rules/delivery.md`)
- MLB both sides → `pd-automation-test` placeholder (no real MLB channel yet)

**Video link pattern:** AB-ending pitch via `cur_event_id = ev.event_id` OUTER APPLY + Video_Network angle fallback `M → V → A → I`. `cell.text.set_url()` on the plottable triangle cell, color `#1565C0`.

**CLI:** `python pd-goals/scripts/generate_wpa_plays.py --date YYYY-MM-DD [--deliver] [--affiliate-only aaa] [--dry-run]`

## WPA Plays — `--2-week` Leaderboard (one-off, Jun 17 2026)

Separate CLI mode on the SAME script. Instead of per-game PDFs, it pools
a trailing window and emits **ONE 2-page PDF**: page 1 = top-N offensive
plays, page 2 = top-N defensive plays. **No WP timeline chart.**

```bash
python pd-goals/scripts/generate_wpa_plays.py --level mlb --date 2026-06-16 --2-week
#   --days 14        trailing window, inclusive of --date (default 14)
#   --top-n 10       plays per side (default 10)
#   --level          any level, default mlb
#   --whole-league   pool ALL teams (DEFAULT is HOU-only — Sam, Jun 17)
#   --deliver [--channel C…]   optional; defaults to mlb-reports/overflow
# Output: .../window_<end>/<level>_<hou|league>_wpa_top<N>_<start>_to_<end>.pdf
```

**Scope = HOU-only by default** (Sam direction Jun 17 2026). `lvl_games`
joins `mlbam.teams` + `org_abbrev='HOU'` (the daily `my_games` pattern);
ranking keeps offense = HOU batting (`org_bat='HOU'`), defense = HOU
fielding (`org_fld='HOU'`). `--whole-league` removes both filters for the
pooled version.

**Video = M preferred, then fallback so EVERY play has a clip** (Sam,
Jun 17 — first wanted M-only, then "not all have M, need all to have
video", then "B then X first after M"). The window query's video OUTER
APPLY picks the first non-null of: `Video_Network 'M'` (Sam's pick) →
`VN 'B'` → `VN 'X'` → `Astros.Video angle_id=1` (sporty-clips CF, **always
populated for MLB games** per `video-angles.md`) → `VN 'a'` → `'v'`.
Coach-facing reel, so device-safety isn't the driver — M is the preferred
view, B/X are Sam's next-best MLB angles, the av1 tier guarantees coverage.

**Companion diagnostic** (`sql-queries/wpa-window-video-angles.sql`): the
SAME top-N HOU plays with EVERY camera angle as its own URL column (M /
sporty CF1+CF2 / VN a,v,H,F,7,5,6) — copy-paste to hunt a working clip
when the auto-resolved link isn't the angle you want. HOU MLB only; edit
`@end` / `@top`.

**Strikeouts excluded from both top tables.** A K *recorded* is a big
positive fielding-team WPA, so it would otherwise rank into the defensive
top plays (this surprised us on the first HOU run — it's correct, just
not wanted here). `rank_window_plays` filters `is_strikeout == 0`.

**The 3 pieces (all in the existing files):**
- `get_mlb_window_plays(level, start, end, hou_only=True)` — date-range
  query, optional HOU filter, score per batting/fielding-team perspective
  (`bat_team_score_before` / `fld_team_score_before`), forced M-angle
  video. Same `top_of_inning` WPA sign-flip as daily.
- `rank_window_plays(df, top_n, hou_only=True)` — non-K top-N by `bat_wpa`
  (offense) / `fld_wpa` (defense).
- `render_mlb_window_pdf(..., pool_label)` — full-width landscape tables
  with **Date / Team / Opp** columns. Page 1 banner green, page 2 navy.

**TODO (deferred, Sam wants it):** add separate **offensive Ks suffered**
+ **defensive Ks recorded** tables (mirror daily `off_ks`/`def_ks`). Data
is already in the frame (`is_strikeout`); needs a 2nd table per page or a
page 3/4. Other open polish: defense page credits the **pitcher** of
record; score reads play-team-first; Team column is constant "HOU" in
HOU-only mode (could drop). Commits `3aec5999` (initial) + this refine on
`feature/pd-goals`.

## WPA Plays — Card 3 (LIVE Apr 25, 2026)

Third landing card. Streamlit presentation layer over the existing
WPA data + PDF pipeline above. Coaches review the previous day's
games with click-to-video on every play. **No data divergence** —
the page imports the SAME `wpa_plays_data` + `wpa_plays_report`
modules the CLI uses.

### Files

| Role | File |
|---|---|
| App page | `pd-goals/pages/4_WPA_Plays.py` (~520 lines) |
| Landing card | `pd-goals/PD_Engine.py` (3rd nav-card) |
| Data module (reused) | `pd-goals/src/wpa_plays_data.py` |
| PDF generator (reused) | `pd-goals/src/wpa_plays_report.py` |
| Design doc | `docs/plans/2026-04-25-wpa-plays-app-design.md` |

### Architecture

```
Filter row (Affiliate dropdown + Date picker)
  ↓
_cached_game_plays(level, date)            ← @st.cache_data(ttl=3600)
  ↓
For each sched_id (1 or 2 games — doubleheader auto-stacked):
    ctx = game_context(...)
    ranked = rank_plays(...)
    summary = game_summary_stats(..., side)
    ↓
    Header strip + tabs Offense | Defense
      Plotly WP step-line (linear, NOT 'hv') with click→video
      3 stacked HTML tables (Top 5 / Bottom 5 / Ks) — green→red WPA shading
  ↓
PDF download (1 button, both pages):
  _cached_pdf_bytes(level, date)           ← @st.cache_data(ttl=600)
    For each sched_id:
      render_offense_pdf(...) + render_defense_pdf(...) → tempdir
      pypdf.PdfWriter() merges all into one combined.pdf
    Returns bytes for st.download_button
```

### Caching

| Helper | TTL | Reason |
|---|---|---|
| `_cached_game_plays(level, date)` | 3600s | Heavy SQL, identical results within an hour. Same as Postgame data load. |
| `_cached_pdf_bytes(level, date)` | 600s | PDF render is deterministic from (level, date). Match KPI weekly. |

### Click-to-video

Plotly chart dots use the canonical pitch-identity helper from
`rules/visual-standards.md` (Click-to-Video Pattern → Canonical
Helper). Customdata layout: `[sched_id, last_pitch_id, video_url]`,
`video_url_index=2`. Each table row also has a `▶` link with
`target="_blank"` for direct video access — same Astros.Video angle
fallback as the PDF (`M → V → A → I`).

### Required env vars

NONE new. The DB connection is shared with PD Goals. WPA does NOT
use pins (no `CONNECT_API_KEY` access path) and does NOT call the
Logic App (delivery is in the CLI only). Only requirements addition
was `pypdf>=4.0.0` + `plottable>=0.1.5` (the latter was already in
sibling-app requirements; was missing from `pd-goals/requirements.txt`
because the WPA report had been CLI-only before this).

### Known traps (don't reintroduce)

1. **Plotly step-line shape "hv" looks blocky in the app.** Use
   `shape="linear"` (matches the PDF). Same WP semantic loss as the
   PDF accepts (linear interpolation between events) — coaches
   prefer the smoother read.
2. **Selection-count click-to-video helper drops second clicks.**
   Plotly's `selection_mode=("points",)` keeps prior points in the
   event payload; count doesn't grow. Use the pitch-identity helper
   from `rules/visual-standards.md`. Customdata identity must be
   unique per dot.
3. **`plottable` and `pypdf` must be in `pd-goals/requirements.txt`.**
   The CLI module imports `plottable` at module top, so even read-
   only access to `wpa_plays_report` (e.g. importing `_DESC_REPLACEMENTS`)
   triggers the install path. `pypdf` is imported lazily inside
   `_cached_pdf_bytes` but ships as a hard requirement so first PDF
   click works.
4. **Existing CLI modules must be in `manifest.json`** even if they
   were already in the repo. `wpa_plays_data.py` + `wpa_plays_report.py`
   + `scripts/generate_wpa_plays.py` had to be added to manifest at
   the same time as `4_WPA_Plays.py` — rsconnect uses manifest as an
   allow-list. (Already a documented `tracker-parquet-pins.md` rule;
   reapplied here.)
