# GC2 vs Barrelsville — Metric Comparison

**Last audited: Mar 19, 2026**
**Status: gcOBA VERIFIED MATCH**

Running document tracking differences between our Barrelsville hitter metrics and GC2 production SQL.

---

## Metrics That Match GC2

### gcOBA — VERIFIED MATCH (Mar 19, 2026)
```
gcOBA = MLB_OBP × (0.50*K% + 1.49*BB_HBP% + 0.11*0sw + 0.08*1sw - 0.10*2sw - 0.10*3+sw + BIP% × (1.70*Brl% + 1.09*UsefulEV/100))
```
- OBP: Always MLB (`level = 'mlb'`)
- Swing count: `did_swing=1` (all swings)
- IBB: Subtracted from BB/HBP rate
- Bin 3: `>= 3`
- Barrel: GC2 linear formula, non-bunt BIP, EV < 125
- EV: `hit_useful_exit_speed` on tracked non-bunt BIP

### wOBA — Match
```
GC2: (woba_BB*(BB-IBB) + woba_HB*HBP + woba_1B*1B + woba_2B*2B + woba_3B*3B + woba_HR*HR) / (AB + BB - IBB + SF + HBP)
```
IBB excluded from both numerator and denominator. We do the same.

### wRC+ — Match
```
GC2: 100.0 * ((wOBA - lgwOBA) / wOBA_scale + runs_per_pa) / runs_per_pa
```
- GC2 joins `Guts.woba_lwts` via `MlbamSchedule.league` — league-specific (AL/NL)
- We use `_get_league_woba_env()` with `mlbam_league` from pitch data, falls back to level AVG
- **Risk:** If our league detection fails, we fall back to level AVG instead of AL/NL specific. Rarely an issue.

### SwDec (Swing Decision) — Match
```
GC2: avg(ProjPitchGrades.swing_decision)
Us:  avg(ppg.swing_decision) — same table, same AVG
```

### BIP Count — Match
```
GC2: pitch_result_id IN (12,13,14,18,19,20)
Us:  BIP_CODES = (12, 13, 14, 18, 19, 20)
```
Includes pitchout BIPs (18/19/20 — extremely rare).

### Avg EV — Match
```
GC2: avg(HitsNoBunts.hit_exit_speed)
```
HitsNoBunts JOIN filters: non-bunt (`hit_trajectory_id NOT IN 2,3,4`), EV > 0, EV < 125. We match after Mar 19 bunt filter fix.

### Max EV (Postgame) — WE DIFFER (intentional)
```
GC2: PERCENTILE_CONT(0.99) on HitsNoBunts.hit_exit_speed
Us:  tracked_bip["hit_exit_speed"].max() (after clean_ev_misreads upstream)
```
GC2 uses P99. We use true MAX() after EV misread cleaning. Our misread filter (EV >= 100 & LA < -35 & EV > batter P95) removes bad reads; P99 on top of that double-filters clean data. Standardized Apr 12 2026.

### Avg LA — Match
```
GC2: avg(case when hit_vertical_angle is null or pitch_result_id not in BIP then null else hit_vertical_angle end)
```
GC2 uses HitsNoBunts JOIN (already filters to non-bunt + EV < 125 BIP). After Mar 19 fix, we compute avg LA on all non-bunt BIP with valid LA (no EV requirement in the column filter — bunt/EV already handled by the Hits JOIN).

### K%, BB%, AVG, OBP, SLG, BABIP — Match
Standard counting stat formulas. Same denominators and numerators.

---

## Known Intentional Divergences

### Contact% (Ctct%) — WE DIFFER
```
GC2:  pitch_result_id NOT IN (10, 21, 22, 23)     — 4 whiff codes
Us:   pitch_result_id NOT IN (10, 16, 21, 22, 23, 25) — 6 whiff codes (WHIFF_CODES)
```
We count missed bunt (16) and bunt foul tip (25) as whiffs. GC2 counts them as contact.
**Why:** All swinging strikes should be whiffs. 16 = missed bunt = did_swing but no contact. 25 = bunt foul tip = extremely rare.
**Impact:** Tiny — 16 and 25 are rare events. Our Ctct% is very slightly lower than GC2's.

### xwOBA IBB — WE DIFFER
```
GC2:  denominator = AB + BB + HBP + SF (IBB included)
Us:   denominator = AB + BB - IBB + HBP + SF (IBB excluded)
```
**Why:** Internal consistency with wOBA (which also excludes IBB). GC2 treats them differently.
**Impact:** Small — IBBs are rare, especially in MiLB.

### Max EV (Tracker) — WE DIFFER (intentional)
```
GC2:  PERCENTILE_CONT(0.99) — P99
Us:   MAX() after EV misread cleaning
```
All Max EV queries use true MAX() after misread cleaning (EV >= 100 & LA < -35 & EV > batter P95). GC2 uses P99 as its safety net instead. Our approach shows the actual hardest legit hit. Standardized Apr 12 2026.

---

## Metrics GC2 Has That We Don't Compute

| Metric | GC2 Source | Notes |
|--------|-----------|-------|
| LA 10-30% (Sweet Spot) | `hit_vertical_angle >= 10 AND <= 30` on BIP | We have PullAir% (LA 26-50) instead |
| xAVG | Hits_Probabilities expected AVG | Probability-based expected batting average |
| xOBP | Hits_Probabilities expected OBP | BB/HBP = 1.0, AB/SF = probability-based |
| xSLG | Hits_Probabilities expected SLG | Same formula weighted 1/2/3/4 |
| ORP (Batting) | `Proj.Batting_MLEs.mle_orp` | Offensive runs produced (MLE-adjusted) |
| DRS | `Proj.Batting_MLEs.drs + repl` | Defensive runs saved + replacement |
| ORP (Running) | `YTD_Player_Batting_RAR_Produced.orp_run` | Running value |
| RAR | `Proj.Batting_MLEs.rar` | Runs above replacement |
| WAR | `Proj.Batting_MLEs.war` | Wins above replacement |

---

## Audit History

| Date | What Changed | Commit |
|------|-------------|--------|
| Mar 12 | wRC+ league context, barrel bunt filter, whiff code 25, xwOBA IBB | `fd6e537`, `c442380`, `cf08607` |
| Mar 19 | gcOBA formula locked (did_swing, IBB sub, >=3, MLB OBP) | `1628da1` |
| Mar 19 | Tracker avg_ev bunt filter + avg_useful_ev | `5bac42f` |
| Mar 19 | Avg LA: no EV requirement (both files) | `822d891` |
| Mar 19 | Sw% coloring fix (direction=None guard) | `11895b3` |
