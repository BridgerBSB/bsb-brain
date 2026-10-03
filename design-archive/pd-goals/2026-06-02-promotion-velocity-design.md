# Promotion Velocity by Org (Sam Niedorf one-off) — HOW IT WORKS + HOW TO EDIT

**Branch:** `feature/pd-goals`  ·  **Status:** SHIPPED + runnable (rewritten Jun 6 2026).
**Only open item:** AV dollar figure (see Caveat #2 / BUG 1).

**Ask (Sam, Slack 2026-06-02):** "Are we a team that moves position players / pitchers from
level to level quicker or slower than other teams?" Measured as **PA (hitters) / IP (pitchers)
banked at a level before promotion**, for each org's **top-10 Asset-Value prospects per side**.

---

## 0. What it produces / how to run

```
cd <repo>/pd-goals
python scripts/generate_promotion_velocity.py --av-source asset_value
```
Writes to `pd-goals/output/`:
- `promotion_velocity_cohort_asset_value.csv`   — who's on each org's list (+ AV)
- `promotion_velocity_events_asset_value.csv`   — per (player, level) velocity rows
- `promotion_velocity_org_rollup_asset_value.csv`— per (org, level) mean wait + 30-org rank
- `promotion_velocity_HOU_vs_field_asset_value.csv`
- `promotion_velocity_asset_value.pdf`           — 2 org-matrix pages + 1 page per team

CLI flags: `--av-source {asset_value|signing_bonus}` (default signing_bonus — use asset_value),
`--top-n N` (default 10), `--min-year YYYY` (default 2022, the played-since gate).
CLI-only one-off — NOT in manifest.json / deploy.ps1, NOT on Connect.

---

## 1. Pipeline — 5 stages, all in `pd-goals/src/promotion_velocity_data.py`

```
build_cohort_asset_value()   -> WHO: top-N AV per DEVELOPING org, played-since gate
   └─ get_developing_org()   -> which org "owns" each player + his last_season
detect_velocity()            -> the wait: units banked at each level before promotion
org_rollup()                 -> mean wait per (org, level) + rank 1..30 (lower = faster)
promotion_velocity_pdf.build_pdf()  -> renders the PDF (separate file)
```
`build_promotion_velocity()` is the top-level driver the CLI calls; returns
`{cohort, velocity, org_rollup}`.

---

## 2. Data sources (per-game gamelog is the spine)

| Need | Source | Join |
|---|---|---|
| Asset Value (cohort pick) | `Player_Val.Asset_Value` (`mkt_sv`, latest `date_generated`) | by `groundcontrol_id` |
| Hitter PA per game | `MLBAM.Gamelog_Batting.pa` | `game_pk = sv.mlbam_game_pk`; `player_id = Players.mlbam_id` |
| Pitcher IP per game | `MLBAM.Gamelog_Pitching.outs` | same |
| Game date + level | `Astros.Schedule_View` (`sched_date`, `gc2_level_code`) | `mlbam_game_pk` |
| Per-game org (traded-in) | `MLBAM.Teams.org_abbrev` | `team_id = gamelog.team_id AND season = sv.year` |
| id bridge / staff filter | `Astros.Players`, `MLB_eBis.PP_MASTER` (`EMPLOYEE_FLG=0`) | `mlbam_id` / `ebis_id` |

Why gamelog (not Pitches_View, not YTD): Pitches_View undercounts PA pre-tracking (Yordan DSL
19 vs official 57); YTD is `split_id`-keyed (inflates) AND has no `dsl` rung. Gamelog gives
official per-game PA + per-game date (needed to window the wait) + per-game team (org). All
verified Jun 6 (Yordan DSL = 57 ✓, Mayer IP ✓).

---

## 3. The rules — and the exact knob to edit each

| Rule | Where it lives (edit here) |
|---|---|
| **Level ladder** (rungs + order) | `LADDER` dict — `dsl1<rok2<afx3(A)<afa4(A+)<aax5(AA)<aaa6(AAA)<mlb7`. `LEVEL_LABEL` for display names. |
| **Short-season A ("A-") = A** | `_ACTIVITY_LEVELS_SQL` (admits `asx`) + `_NORM_LEVEL_SQL` (normalizes `asx`→`afx`). To fold another A-equivalent code, add it to both. `asx` = NY-Penn/Tri-City short-season A (confirmed). |
| **Org canon (same-franchise merges)** | `_ORG_CANON` — `OAK→ATH`, `FLA→MIA`, `CHI→CHC`, `LA→LAD`, `NY→NYM`. Add future rebrands (e.g. legacy TBD→TB) here. |
| **Developing org (whose list)** | `get_developing_org()` — org at his LAST below-A game BEFORE he first reached full-season ball; if he never played below A, org at his FIRST pro game. |
| **Played-since gate** | `min_year` (default 2022) → filters cohort to `last_season >= min_year`. Change default in `build_cohort`/CLI. |
| **Activity gate (real promotion)** | `HITTER_GATE_PA = 10`, `PITCHER_GATE_OUTS = 15`. |
| **Rehab exclusion** | `REHAB_WINDOW_DAYS = 21`, `REHAB_CODES`. |
| **Cohort size** | CLI `--top-n` (default 10), per (org, player_type). |
| **Org rollup stat + rank dir** | `org_rollup()` — mean per (org, level), rank lower=faster=1; median also computed. |
| **Pitcher position list** | `PITCHER_POSITIONS`. |
| **PDF layout** | `pd-goals/src/promotion_velocity_pdf.py` (matrix pages + per-team pages). |

---

## 4. Attribution model (the heart of it)

- **Cohort = top-N AV per DEVELOPING org** (NOT current org). So an org's list = the prospects
  IT developed: a player it drafted/developed then traded away still counts for it; a player it
  ACQUIRED at A-ball-or-above counts for his original developer, not the acquirer.
  - Acquired BELOW A-ball → acquirer counts (Yordan, picked up in the DSL → HOU ✓).
  - Acquired AT/ABOVE A-ball → original developer (Cam Smith via Cubs → Cubs, off HOU ✓).
- **Developing org** = `get_developing_org()` (definition in §3). The "developmental" restriction
  (only below-A games BEFORE first full-season ball) is what stops a veteran's late FCL **rehab**
  stint from re-pinning him to the new org (Trammell: 2025 HOU rehab ignored → he's CIN ✓).
- **velocity(L)** = official units banked at level L, counting **only the player's developing-org
  games**, dated **before he first reached ANY higher rung** (with the activity gate, non-rehab).
  Levels he only reached AFTER a higher rung (demotions/rehab) are dropped, not censored.
  Never promoted out of L → **censored** (reported, excluded from the mean).

---

## 5. KNOWN CAVEATS — read before trusting edge cases

### Caveat 1 (BIGGEST — user-flagged Jun 6): traded-before-MLB players UNDERSTATE level tenure
A player is credited wholly to his **developing (original) org**, and his per-level wait counts
**only that org's games**. So if org A develops him through, say, AA, **trades him before MLB**,
and org B keeps him at AA longer before promoting:
- A's "AA wait" = only the **pre-trade** AA games (partial) — even though A never actually
  promoted him out of AA (B did, after more AA time).
- B gets nothing for him (he's attributed entirely to A).
- The reported wait is therefore **LESS than his true total time at that level** (A + B combined),
  and the "promotion" it's measured against happened under a different org.

**Net: for players an org traded away before MLB, the per-level number is a FLOOR, not the full
minor-league length they actually spent at that level. Treat those rows as iffy.** This matters
because traded prospects usually repeat the same level under the new org.

Future fix options (not built): (a) merge cross-org same-level time into one tenure; (b) flag or
exclude players who were traded mid-minors; (c) credit each level to the org that actually
promoted him out of it. Pick one when this becomes a priority.

### Caveat 2 (BUG 1): AV dollar figure is off for pitchers / near-MLB players
`AV = SUM(mkt_sv)` matches GC2 for position players (Kevin Alvarez $3.8M ✓) but not pitchers
(Mayer GC2 21.3M vs ours 38.2M) — GC2 applies extra logic (likely SP/RP role-prob blend +
present-value scoping) not visible in raw `mkt_sv`. **Low stakes:** AV only SELECTS the cohort;
it feeds no velocity number. Fix needs GC2's real AV formula (a `Player_Val` view/proc or doc).
Fallback: keep `SUM(mkt_sv)` as the selector and label the column "approx."

### Caveat 3: a game whose `team_id` doesn't resolve in `MLBAM.Teams` gets no org → dropped
Rare (mostly very old / non-affiliate rows). If an obviously-present player is missing, check the
`MLBAM.Teams` resolution for his team_id/season.

### Caveat 4: international/amateur level codes are intentionally excluded
`nae/naw/nat/ame/kor/bbc/hsb/ind/win/int/min/sum/jcb` are NOT affiliate rungs → not in the ladder.
Only the 7 rungs (+ `asx` folded into A) count.

---

## 6. How to edit common things (quick recipe)

- **Add/rename a level rung:** edit `LADDER` + `LEVEL_LABEL`; if it's an alias of an existing
  rung (like A-), add the code to `_ACTIVITY_LEVELS_SQL` and normalize it in `_NORM_LEVEL_SQL`.
- **Merge another rebranded franchise:** add `"OLD": "NEW"` to `_ORG_CANON` (NEW = current form).
- **Change the played-since cutoff:** `--min-year YYYY` (or the default in `build_cohort`).
- **Change cohort size:** `--top-n N`.
- **Change "what counts as a real promotion":** `HITTER_GATE_PA` / `PITCHER_GATE_OUTS`.
- **Change org stat from mean→median or rank direction:** `org_rollup()`.
- **Re-verify a player:** run `sql-queries/promotion-velocity-gamelog-probe.sql` (per-game PA/IP/org)
  or `promotion-velocity-level-probe.sql` (full level history, all codes).

---

## 7. What NOT to do
- Don't go back to Pitches_View for PA (sparse pre-tracking) or YTD (split_id inflation, no dsl).
- Don't attribute by CURRENT org — it's DEVELOPING org (the whole point of the trade handling).
- Don't count below-A games AFTER a player reached full-season ball (that's rehab; re-pins wrongly).
- Don't drop the org canon on any `MLBAM.Teams` join (OAK/ATH, FLA/MIA, CHI/LA/NY) — 31-org bug.
- Don't trust traded-before-MLB per-level numbers as full tenure (Caveat 1).
- Don't deploy to Connect — CLI one-off.

---

## 8. Diagnostic SQL (in `sql-queries/`)
- `promotion-velocity-gamelog-probe.sql` — confirmed gamelog as the PA/IP/org source.
- `promotion-velocity-level-probe.sql` — found `asx` = A-; confirms a player's full level history.
- `promotion-velocity-av-pa-diagnostics.sql` / `-official-pa-probe.sql` — AV + PA source audits.
- `promotion-velocity-audit.sql` / `-av-candidates.sql` — original AV-table discovery.

## 9. History
- 2026-06-02 — design (offline, no DB).
- 2026-06-05 — AV table resolved (`Player_Val.Asset_Value`); detector dtype crash fixed.
- 2026-06-06 — REWRITE: PA→gamelog (BUG 2), org-aware before-first-higher detector (BUG 3),
  developing-org cohort (traded-in), FLA→MIA + asx→A, played-since gate. All verified vs probes.
  Remaining: BUG 1 (AV formula).
