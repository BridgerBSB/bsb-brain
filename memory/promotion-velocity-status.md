---
name: promotion-velocity-status
description: "Sam Niedorf org promotion-velocity one-off — status, decisions, 3 open bugs, next probe. Resume here."
metadata: 
  node_type: memory
  type: project
  originSessionId: 8375ff3b-2585-4f8b-af77-7fdae13a9fc5
---

# Promotion Velocity by Org (Sam Niedorf one-off) — RESUME HERE

**Branch:** `feature/pd-goals` (main repo `C:\Users\Owner\bsb-resources`). **Started Jun 2026.**
**Ask (Sam, Slack):** "Are we a team that moves position players / pitchers from level to level
quicker or slower than other teams?" Measured as **PA (hitters) / IP (pitchers) banked at a level
before promotion**, for each org's **top-10 AV players per side**.

## RESUME HERE (Jun 6, post-documentation, user cleared)
**Canonical reference = `pd-goals/docs/plans/2026-06-02-promotion-velocity-design.md`** — fully
rewritten as how-it-works + how-to-edit (every knob mapped) + caveats. Read it first on resume.

**State:** pipeline SHIPPED + verified against probes. Runnable:
`python pd-goals/scripts/generate_promotion_velocity.py --av-source asset_value` → 4 CSVs + PDF.
All of this session's QA bugs fixed (gamelog PA, developing-org cohort, traded-in, FLA→MIA,
asx→A, played-since gate). **ONLY OPEN ITEM = BUG 1 (AV $ formula, Mayer 21.3 vs 38.2)** — needs
GC2's real AV calc from user; AV only selects the cohort so it's low-stakes.

**BIG KNOWN CAVEAT (user-flagged, documented design §5 Caveat 1 + module docstring):** a player
traded away BEFORE MLB is credited wholly to his developing org and his per-level wait counts ONLY
that org's games → UNDERSTATES true level tenure (he usually repeats the level under the new org).
Traded-pre-MLB per-level numbers are a FLOOR, not full length. Future fix options listed in the doc
(merge cross-org same-level time / flag traded players / credit the org that promoted him out).
Not built — user accepted for now, flagged as iffy.

## State (Jun 6): BUG 2 + BUG 3 + traded-in SHIPPED in one rewrite (commit on feature/pd-goals,
## gamelog probe confirmed all 5 results). PENDING work-laptop run + spot-check. Only BUG 1 (AV) open.

### Jun 6 (part 3) — 3 follow-up QA bugs ALL SHIPPED
1. Trammell pinned to HOU: `get_developing_org` used LAST below-A game = a 2025 HOU FCL **rehab**
   stint (confirmed num3: 2016 rok CIN dev + 2025 rok HOU rehab). Fix: only count below-A games
   BEFORE first full-season ball (rank>=afx). -> Trammell resolves to CIN, off HOU.
2. FLA->MIA: added to `_ORG_CANON` (Marlins rebrand, like OAK->ATH). 31 orgs -> 30.
3. Short-season A "A-" = gc2_level_code **`asx`** (confirmed num2: Hunter Brown 2019 Tri-City asx HOU).
   Fix: `_ACTIVITY_LEVELS_SQL` admits asx; `_NORM_LEVEL_SQL` CASE normalizes asx->afx in every
   SELECT (hitter/pitcher activity + get_developing_org union) so A- merges into the A bucket.
   Hunter Brown now shows A/AA/AAA (A+ genuinely blank — he skipped it, COVID 2020).
   Note: other intl/amateur codes (nae/naw/nat/ame/kor) are NOT affiliate rungs — left excluded.
Real Hunter Brown = gc 95843 / mlbam 686613 (num1; other Hunter Browns are stubs/older player).

### Jun 6 (part 4) — played-since gate SHIPPED
Lupe Chavez showed up but last played 2019. Cause: `build_cohort` never passed min_year to the
AV path, and the old gate used PP_MASTER.R4YEAR (draft year) anyway. Fix: gate = gamelog
`last_season` (max game year) >= min_year (default 2022). build_cohort now passes min_year;
get_developing_org returns last_season; build_cohort_asset_value filters on it. Old pre-2022
stats still feed level history — gate only controls cohort membership. R4YEAR gate removed.

### ONLY OPEN ITEM = BUG 1 (AV formula, Mayer 21.3 vs 38.2). Everything else (PA source, detector,
### traded-in org attribution, org canon FLA+OAK, asx->A level, played-since gate) DONE + verified.

### SHIPPED Jun 6 (part 2) — cohort keyed on DEVELOPING org, not current org
User revised attribution: credit the org that DEVELOPED the player, not current/acquiring org.
- Rule: developing org = org at player's LAST game BELOW A-ball (dsl/rok); if never below A,
  org at FIRST pro game. New `get_developing_org(player_ids)` (union both gamelogs, lowest-rung
  pick). Encodes "acquired below A counts for acquirer" (Yordan picked up in DSL -> HOU) vs
  "acquired at/above A -> original developer" (Cam Smith -> Cubs, OFF HOU list).
- `build_cohort_asset_value` now drops PP_MASTER.ORG_LK for org; inner-merges dev_org; top-N AV
  per (DEVELOPING org, type). Players w/ no pro games drop out.
- Consequences: HOU-developed-then-traded players appear on HOU's list (if top-10 AV); acquired-
  above-A drop off HOU onto their developer; Trammell no longer blank under HOU (he's CIN's now,
  likely not CIN top-10 so just absent). Detector UNCHANGED (already filters games to attributed
  org -> a player's upper levels under a different org stay blank for his dev org).
- Trammell logic check: he was traded before MLB, so user's "count for org he made MLB with IF not
  traded before" -> falls back to original team. Definition A (lowest-level org) is the unique rule
  consistent with ALL user statements (Yordan/Cam Smith/Trammell/below-A carve-out).
- PENDING work-laptop run + spot-check (HOU list: Yordan in, Cam Smith out, Trammell gone).

### SHIPPED Jun 6 (part 1) — gamelog rewrite (`promotion_velocity_data.py`)
- Gamelog probe `sql-queries/promotion-velocity-gamelog-probe.sql` confirmed: Gamelog_Batting has
  `pa` + `team_id`; Gamelog_Pitching has `outs` + `team_id`; Yordan 2016 dsl R = **57** (matches GC2);
  per-game sched_date + team_id present; Mayer IP correct. dsl stays its own rung via gc2_level_code.
- `get_hitter_activity_by_game` rewritten: MLBAM.Gamelog_Batting (was Pitches_View, sparse). Adds
  per-game `org` (team_id -> MLBAM.Teams.org_abbrev). `get_pitcher_activity_by_game` adds same org.
- `detect_velocity` rewritten ORG-AWARE: promotion timeline (first higher-rung arrival, gate+rehab)
  computed over ALL games; velocity + credit use ONLY cohort-org games; if earliest higher arrival
  <= L's first org game -> EXCLUDE L (demotion/rehab, e.g. Trammell AAA); else banked = org units at L
  dated strictly < earliest_higher (strips post-promotion demotion games). Censored = no higher rung,
  velocity NaN, excluded from mean.
- Compiles clean. PENDING: user `git pull` + run `--av-source asset_value` + spot-check Yordan DSL /
  Trammell AAA / HOU per-level sanity. Then BUG 1 (AV) is the only remaining item.

## Files (all committed + pushed on feature/pd-goals)
- `sql-queries/promotion-velocity-audit.sql` — initial audit (done)
- `sql-queries/promotion-velocity-av-candidates.sql` — found the AV table
- `sql-queries/promotion-velocity-av-pa-diagnostics.sql` — the 3-issue diagnostics (RESULTS captured below)
- `sql-queries/promotion-velocity-official-pa-probe.sql` — **NEXT: user must run this, paste A/B/C back**
- `pd-goals/src/promotion_velocity_data.py` — cohort + detector + canonical PA/IP + org rollup
- `pd-goals/src/promotion_velocity_pdf.py` — 2 org-matrix pages + per-team player pages
- `pd-goals/scripts/generate_promotion_velocity.py` — CLI, writes 4 CSVs + PDF to `pd-goals/output/`
- `pd-goals/docs/plans/2026-06-02-promotion-velocity-design.md` — design doc
- Run: `python pd-goals/scripts/generate_promotion_velocity.py --av-source asset_value`

## LOCKED decisions
- Cohort = **top-10 per side (10 H + 10 P)** per org by AV. NOT 10 total.
- Eligibility = "in system 2022+" → effectively current top-10 (no real 2022 gate applied; `min_year`
  param exists but asset_value path ignores it — acquired-since-2022 needs acq-year logic, deferred).
- **7-rung ladder** (dsl<rok<afx(A)<afa(A+)<aax(AA)<aaa(AAA)<mlb), via `gc2_level_code`.
- Org rollup = **MEAN** wait per (org, level); rank lower = faster = 1. (User said mean, not median.)
- AV source = `Player_Val.Asset_Value` (schema.table; was permission-gated → now accessible).
  AV = `SUM(mkt_sv)` over controllable seasons at latest `date_generated` snapshot. **Verified on Kevin
  Alvarez (gc 213722) = $3.79M == GC2 $3.8M** — but see OPEN BUG 1 (breaks for pitchers/near-MLB).
- Canonical PA = `SUM(CAST(ev.pa AS int))+SUM(CAST(ibb AS int))` event-anchored; IP = Gamelog outs.
  **But see OPEN BUG 2 — must switch to OFFICIAL MLBAM stats, pitch-derived undercounts.**

## THREE OPEN BUGS (found in QA Jun 5-6, diagnosed)

### BUG 1 — AV rollup wrong for pitchers + near-MLB hitters
- Bryce Mayer (gc 176229, P): GC2 AV **21.3M**. Our SUM(mkt_sv) season-MAX = **38.2M** (= SP-only sum,
  since SP>RP every season). RP-sum=7.6, all-rows sum=45.8. **None equal 21.3.**
- Trammell (gc 73618, CF): clean sum = 38.2, GC2 ≈ 31.2 (off ~7M) — even a single-pos hitter is off.
- Kevin Alvarez matched only because far-future low-value prospect (nuances vanish).
- → GC2's AV is NOT a plain `SUM(mkt_sv)`. Extra logic invisible in mkt_sv (role-prob blend for
  pitchers, likely present-value / control-year scoping). **NEED GC2's actual AV formula or a
  `Player_Val` view/proc that computes the displayed number.** Asked user.
- Fallback if unobtainable: keep SUM as cohort-SELECTION proxy (picks ~right top-10), note displayed AV
  won't tie to GC2. Low-stakes since AV only selects the cohort.

### BUG 2 — PA/IP undercount (pitch-derived ≠ GC2 official)
- Yordan DSL 2016: ours **19** vs GC2 official **57**. Upper/recent levels close (AAA 189=189) but
  DSL/old years badly low (our Pitches_View sparse pre-tracking).
- **YTD probe (Jun 6) ruled OUT `MLBAM.YTD_Player_Batting_Stats`:** (1) it's `split_id`-keyed —
  multiple rows per (player,season,level,gm_type), summing all splits inflated (Yordan 2019 mlb R =
  6180, 2021 = 10085). (2) **No `dsl` level** — YTD `level` codes are aaa/aax/afa/afx/rok/mlb (+junk
  ame/asx/bbc/hsb/ind/int/kor/min/nae/nat/naw/win); DSL collapses into `rok`, would lose bottom rung.
  (3) YTD is season-aggregate — can't window PA at a mid-season promotion date (the whole metric).
- **NEW FIX (Jun 6) = per-game gamelog.** Source = `MLBAM.Gamelog_Batting` (hitters) +
  `MLBAM.Gamelog_Pitching` (pitchers, already correct → Mayer IP matched). Join
  `Gamelog.game_pk = Schedule_View.mlbam_game_pk`, `Gamelog.player_id = Astros.Players.mlbam_id`.
  Schedule_View gives per-game `sched_date` + **`gc2_level_code` (keeps dsl separate → full 7-rung
  ladder)** + per-game team for org. ONE source fixes BUG 2 + BUG 3 + traded-in together. gm_type='R'
  for regular season (confirmed). `MLBAM.Gamelog_Pitching.outs` per ip-calculation.md gold standard.
- **BLOCKED on probe**: `sql-queries/promotion-velocity-gamelog-probe.sql` (committed, pushed). Need
  A/B (gamelog columns — does Gamelog_Batting have `pa`? `team_id`?), C (Yordan gamelog DSL 2016 = 57?),
  D (per-game sched_date+level+team present), E (Mayer IP via gamelog stays correct). If Gamelog_Batting
  has no `pa` col → build PA from AB+BB+HBP+SF; if no `team_id` → derive org from Schedule home/away.

### BUG 3 — detector censors/over-counts yo-yo + rehab players (Trammell)
- Trammell AAA showed **1314\*** (censored). Root cause: his `mlb` first game **2021-04-01** is BEFORE
  his `aaa` first game **2021-05-13** — rushed to MLB then demoted. His AAA is all post-MLB
  demotion/rehab, not "before a call-up." Lower levels also polluted w/ rehab games (AA 2025/26, FCL
  2025) — see his TR_HISTORY (heavy IL/REHAB 2018-2026).
- Current detector: promotion_out = first higher arrival AFTER this level's first arrival → wrong.
- FIX (rewrite): velocity(L) = official PA at L banked **before the player FIRST reaches ANY higher
  rung** (chronological MIN over higher rungs, gate+non-rehab). If that earliest-higher date is BEFORE
  L's first game → L is a demotion/rehab level → **exclude** (not censored, just drop). Else velocity =
  PA at L dated < earliest-higher. Else (no higher) = censored ceiling. This also auto-strips rehab
  games (anything after first higher-level arrival).

## ALSO STILL PENDING (separate from the 3 bugs)
- **Traded-in correction** (never built): currently ALL of a player's level waits credit to his CURRENT
  org. Should credit each level to the org that held him THEN (per-level org via MLBAM.Teams). So an
  acquired guy's pre-trade climbing doesn't count as HOU's behavior. User chose this ("option 2,
  account for acquired-from-elsewhere"). Build with official-PA rewrite.

## Known-good signal already (sanity)
HOU = **rank 28/30 on AAA→MLB pitcher promotion** (sits AAA arms long before call-up); moves hitters
through upper minors aggressively. Cohort top-AV names look right (Griffin/PIT, Ohtani/LAD, Skenes…).

## Key IDs / commits
- gc_ids: Mayer 176229, Trammell 73618, Yordan 75884, Kevin Alvarez 213722.
- Detector dtype crash (object-Series `~`/`&`) fixed in `b5b0aa3d` (plain-Python jump detection).
- Last commit `60fd65d9` (official-PA probe).

## NEXT SESSION ORDER (updated Jun 6 — gamelog pivot)
1. User runs `sql-queries/promotion-velocity-gamelog-probe.sql` → paste A/B/C/D/E.
   (Supersedes the YTD probe, which is ruled out — see BUG 2. official-pa-probe.sql results captured:
   YTD level list has no dsl; gm_type R=regular; YTD is split_id-keyed/inflated.)
2. REWRITE data layer on per-game gamelog (one source = Gamelog_Batting/_Pitching →
   Schedule_View on mlbam_game_pk; player via mlbam_id). Per-(player,game) frame: sched_date,
   gc2_level_code rung, org (per-game team→MLBAM.Teams + org canon), pa (hitters) / outs (pitchers).
   This single rewrite fixes BUG 2 (official PA) + BUG 3 (per-game dates) + traded-in (per-game org).
3. Detector on the gamelog frame: arrival(rung) = MIN(sched_date); velocity(L) = SUM(units) at L
   dated < earliest-higher-rung arrival; if earliest-higher < L's first game → L is demotion/rehab,
   EXCLUDE; else censored ceiling. Trammell AAA (mlb 2021-04-01 < aaa 2021-05-13) → excluded.
4. Org attribution falls out of #2 (per-game org). Replaces current "all credit to current org."
5. AV: get GC2 formula from user, else keep SUM(mkt_sv) as cohort-SELECTION proxy + note divergence.
6. Re-run, re-verify Yordan PA / Trammell AAA / Mayer AV+IP against GC2.
