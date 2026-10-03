# 2→H / 1→3 Run-Attribution Fix — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the broken `outs_after = outs_before` "did the runner score" proxy in the 2→H and 1→3 baserunning metrics with lead-first run-attribution, across every live surface, so a runner who scores on a single is credited even when another out is made on the play.

**Architecture:** The current logic credits a 2→H / 1→3 only when ZERO outs were made on the play — so a runner who scores from 2nd while the batter (or a trailing runner) is thrown out gets wrongly scored 0. Camden's 41-play video review (AAX 2026) confirmed ~30 of 41 flagged plays were real scores we're discarding. The fix swaps the outs test for "a run actually scored on the play, credited to runners lead-first." Same logic lands in 4 SQL queries + 2 Python helpers, validated against Camden's video ground truth, then re-pinned and redeployed.

**Tech Stack:** T-SQL (GroundControl2 / GCSQL02), Python (pandas), Streamlit, joblib tracker pins on Posit Connect. DB access is **work-laptop only**; code edits can be done anywhere.

---

## Background — the canonical new rule (read before any task)

A runner on base **B** *scored* on a play iff:
1. **He left the bases** — he is not on 1B/2B/3B after the play, AND
2. **`runs_on_play >= rank`**, where:
   - `runs_on_play` = the batting team's runs on this event = `CASE WHEN ev.top_of_inning = 1 THEN ev.away_team_score_after - ev.away_team_score_before ELSE ev.home_team_score_after - ev.home_team_score_before END`
   - `rank` = 1 + (number of runners present on bases **ahead** of B at pitch). Lead runners score first.

Concretely:
- **2→H** (runner on 2B): `rank = 1 + (runner on 3B present ? 1 : 0)` → **no runner on 3B: need ≥1 run; runner on 3B: need ≥2 runs.** (This is the version validated at ~88% / ~28-of-29 perfect on the no-runner-on-3rd bucket.)
- **1→3** (runner on 1B): the "**reached 3B**" success (`runner_3b_after = runner_1b`) is reliable and **stays unchanged**. Only the rare "**scored all the way from 1st**" branch swaps to run-attribution with `rank = 1 + (runner on 2B present ? 1 : 0) + (runner on 3B present ? 1 : 0)`.

**Validation accuracy (vs Camden's 41 video verdicts):** naive `runs_on_play>0` = 76% (9 false credits, all runner-on-3rd). Lead-first rule = ~88%; the residual error is confined to the ~12 runner-on-3rd plays/level/year where even video isn't always conclusive. The no-runner-on-3rd bucket (the bulk) is essentially exact.

**Decision already locked by Zac:** ship the lead-first 2-run rule (auto, all surfaces), NOT conservative/manual-review. Do not re-litigate.

**Surfaces (three-surface-parity + daily + drift-free):**

| # | File | Symbol | Type |
|---|---|---|---|
| 1 | `intangibles/src/br_tracker_data.py` | `_FT3_S2H_QUERY` (per-runner) | SQL |
| 2 | `intangibles/src/br_tracker_data.py` | `_ORG_FT3_S2H_QUERY` (per-org) | SQL |
| 3 | `intangibles/src/br_kpi_data.py` | `_ORG_DAILY_FT3_S2H_QUERY` | SQL |
| 4 | `pd-goals/src/org_kpi_data.py` | `_BR_FT3_S2H_ORG_QUERY` | SQL |
| 5 | `intangibles/src/br_data.py` | `_compute_2h` + `_compute_13` | Python |
| 6 | `intangibles/src/snapshot_data.py` | (verify in Task 1) | SQL/Python? |
| — | `intangibles/src/baserunning_base.py` | `aggregate_ft3`/`aggregate_s2h` | **DEAD — delete** |

Worktrees: Intangibles = `C:\Users\Owner\bsb-wt-intangibles\astros-intangibles` (`feature/astros-intangibles`); PD-Goals = `C:\Users\Owner\bsb-resources` (`feature/pd-goals`).

---

## Task 0: Capture Camden's 41-play verdicts as a keyed fixture

**Why:** the regression test for the whole change. Must be keyed by `(sched_id, event_id)`, not positional (my earlier positional zip was off-by-one).

**Files:**
- Create: `sql-queries/_fixtures/camden_2h_aax_2026.tsv`

**Step 1:** Ask Camden (or Zac) to re-export the 41 verdicts as 3 columns: `sched_id`, `event_id`, `verdict` (`SCORED` / `OUT`). Source rows are the output of `sql-queries/s2h-outs-clause-bug-hunt.sql` (= SQLQuery32). Save as the TSV above.

**Step 2:** Sanity-check it has exactly 41 rows and the `sched_id`/`event_id` pairs match the hunt query's 41 rows.

**Step 3:** Commit.
```bash
git add sql-queries/_fixtures/camden_2h_aax_2026.tsv
git commit -m "test(br): Camden 41-play 2->H video ground-truth fixture (AAX 2026)"
```

> **Blocker:** do not start Task 2+ until this fixture exists — every surface is validated against it.

---

## Task 1: Pre-flight — confirm live surfaces + the snapshot path

**Files:** read-only.

**Step 1:** Confirm `baserunning_base.py` is dead:
```bash
grep -rln "baserunning_base" intangibles/src intangibles/pages intangibles/scripts | grep -v baserunning_base.py
```
Expected: **no output** → safe to delete in Task 8.

**Step 2:** Check whether `snapshot_data.py` computes its OWN ft3/s2h success or consumes `br_*_data`:
```bash
grep -niE "outs_after|no_extra_outs|s2h_success|ft3_success|FT3_S2H" intangibles/src/snapshot_data.py
```
- If it has its own `outs_after = outs_before` success CASE/logic → add it to the fix list (Task 6b, same change).
- If it only imports/sums precomputed columns → no change needed; note it.

**Step 3:** Check `br_daily_data.py` / `br_daily_report.py` similarly — they should consume `br_kpi_data` / `br_data`, not recompute. Confirm.

**Step 4:** Record findings inline in this plan (edit the table above) and commit the plan edit.

---

## Task 2: Validation harness — prove the new rule on Camden's fixture (work laptop)

**Why (TDD-equivalent):** lock the accuracy number BEFORE editing any production surface. This query IS the test.

**Files:**
- Create: `sql-queries/s2h-1to3-fix-validation.sql`

**Step 1: Write the harness.** Re-run the hunt's 41 rows, compute OLD vs NEW success inline, LEFT JOIN the fixture verdict, and tally agreement. The NEW `s2h_success` CASE (canonical — copy verbatim into production later):
```sql
-- runs_on_play (batting side)
CASE WHEN ev.top_of_inning = 1
     THEN ev.away_team_score_after - ev.away_team_score_before
     ELSE ev.home_team_score_after - ev.home_team_score_before END  -- = runs_on_play

-- NEW s2h_success
CASE
  WHEN (ev.runner_2b_after IS NULL OR ev.runner_2b_after != ev.runner_2b)
   AND (ev.runner_3b_after IS NULL OR ev.runner_3b_after != ev.runner_2b)
   AND (CASE WHEN ev.top_of_inning = 1
             THEN ev.away_team_score_after - ev.away_team_score_before
             ELSE ev.home_team_score_after - ev.home_team_score_before END)
       >= (CASE WHEN ev.runner_3b IS NULL THEN 1 ELSE 2 END)
  THEN 1 ELSE 0
END AS s2h_success_new
```
Output columns: `sched_id, event_id, runner_on_2b, runs_on_play, runner_3b, s2h_OLD, s2h_NEW, verdict, NEW_matches_video = CASE WHEN (s2h_NEW=1)=(verdict='SCORED') THEN 1 ELSE 0 END`.

**Step 2: Run on work laptop.** Confirm: `s2h_OLD` = 0 on all 41 (reproduces the bug); `s2h_NEW` matches Camden on the no-runner-on-3rd rows ~28/29; overall agreement ≈ 88%+. Eyeball every disagreement — all should be runner-on-3rd rows.

**Step 3:** If agreement is materially below the validation (e.g. <85%), STOP — the fixture keying or the rule is off; reconcile with Camden before continuing.

**Step 4:** Commit.
```bash
git add sql-queries/s2h-1to3-fix-validation.sql
git commit -m "test(br): 2->H/1->3 run-attribution validation harness vs Camden fixture"
```

---

## Task 3: Fix the tracker queries (`br_tracker_data.py`)

**Files:**
- Modify: `intangibles/src/br_tracker_data.py` — `_FT3_S2H_QUERY` (~L634) **and** `_ORG_FT3_S2H_QUERY` (~L1271)

**Step 1:** In **both** queries, in the **2→H branch**, replace the `s2h_success` CASE's `AND ev.outs_after = ev.outs_before` line with the runs-on-play `>=` test (canonical block from Task 2, Step 1).

**Step 2:** In **both** queries, in the **1→3 branch**, update `ft3_success`:
- Keep `WHEN ev.runner_3b_after = ev.runner_1b THEN 1` (reached 3B).
- In the second WHEN (scored from 1st), replace `AND ev.outs_after = ev.outs_before` with:
```sql
AND (CASE WHEN ev.top_of_inning = 1
          THEN ev.away_team_score_after - ev.away_team_score_before
          ELSE ev.home_team_score_after - ev.home_team_score_before END)
    >= (1 + CASE WHEN ev.runner_2b IS NOT NULL THEN 1 ELSE 0 END
          + CASE WHEN ev.runner_3b IS NOT NULL THEN 1 ELSE 0 END)
```

**Step 3 (coupling — do not miss):** the `ft3_opps` CASE has an **LF branch** that mirrors the scored condition (LF opp only counts on success). Apply the SAME outs→runs swap inside the `ft3_opps` LF branch so opp and success stay consistent. (RF/CF opp logic is unchanged.)

**Step 4:** Syntax check:
```bash
python -c "import ast; ast.parse(open(r'intangibles/src/br_tracker_data.py',encoding='utf-8').read()); print('OK')"
```

**Step 5 (verify, work laptop):** bypass the pin (`_TRACKER_PINS_AVAILABLE=False` per tracker-parquet-pins.md §5.13) and run `get_org_rankings`/per-runner for AAX 2026; confirm 2→H/1→3 counts rose vs the pinned values and that a known Sullivan-type play now credits.

**Step 6:** Commit on `feature/astros-intangibles`.
```bash
git commit -am "fix(br): 2->H/1->3 success via lead-first run-attribution (tracker queries)"
```

---

## Task 4: Fix the KPI weekly query (`br_kpi_data.py`)

**Files:**
- Modify: `intangibles/src/br_kpi_data.py` — `_ORG_DAILY_FT3_S2H_QUERY` (~L232)

**Step 1:** Same edits as Task 3 (2→H success swap, 1→3 success swap, ft3_opps LF-branch swap) in this query's inner subquery.

**Step 2:** Syntax check (as Task 3 Step 4, this file).

**Step 3 (verify):** generate a BR KPI weekly for AAX 2026 on the work laptop; confirm the chart-line + table 2→H/1→3 totals match the tracker for the same window (three-surface-parity).

**Step 4:** Commit on `feature/astros-intangibles`.

---

## Task 5: Fix the PD-Goals org query (`org_kpi_data.py`)

**Files:**
- Modify: `pd-goals/src/org_kpi_data.py` — `_BR_FT3_S2H_ORG_QUERY` (~L1713)

**Step 1:** Same three edits as Task 3 in this query.

**Step 2:** Syntax check (this file).

**Step 3 (verify):** run the PD-Goals org KPI BR section for AAX 2026; confirm it matches the tracker + KPI weekly numbers (three-surface-parity).

**Step 4:** Commit on `feature/pd-goals`.

---

## Task 6: Fix the daily play-by-play Python (`br_data.py`)

**Files:**
- Modify: `intangibles/src/br_data.py` — `_compute_2h` (~L1412), `_compute_13` (~L1377), and the pitch/`ev_adv` SELECTs that feed them.

**Step 1:** Ensure the dataframe rows carry `top_of_inning`, `home_team_score_before/after`, `away_team_score_before/after`. Add them to the SELECT(s) in this function's queries if missing.

**Step 2:** Add a helper near the top of the compute block:
```python
def _runs_on_play(row):
    top = row.get("top_of_inning")
    if pd.isna(top):
        return 0
    if int(top) == 1:
        a, b = row.get("away_team_score_after"), row.get("away_team_score_before")
    else:
        a, b = row.get("home_team_score_after"), row.get("home_team_score_before")
    if pd.isna(a) or pd.isna(b):
        return 0
    return int(a) - int(b)
```

**Step 3:** In `_compute_2h`, replace the `no_extra_outs` scored test:
```python
dest = _runner_on_base_after(row, runner_gc_id)
need = 2 if pd.notna(row.get("runner_3b")) else 1
if dest == 0 and _runs_on_play(row) >= need:
    return "Y"   # scored (lead-first run attribution)
return "N"
```

**Step 4:** In `_compute_13`, keep the reached-3B branch (`dest >= 3 → "Y"`); replace the scored branch + the blocked-base `no_extra_outs` usages:
```python
need = 1 + (1 if pd.notna(row.get("runner_2b")) else 0) + (1 if pd.notna(row.get("runner_3b")) else 0)
scored = (dest == 0 and _runs_on_play(row) >= need)
# blocked-base check: replace `dest == 0 and no_extra_outs` with `scored`
...
if dest >= 3:
    return "Y"
if scored:
    return "Y"
# LF failures still not opportunities; else "N"
```

**Step 5:** Syntax check (this file).

**Step 6 (verify):** run `generate_br_daily_report.py` (or `pages/1_Baserunning.py`) for the Sullivan game (`sched_id 1289533`, 2026-06-02) — and a clean OF-single example from the fixture — and confirm `adv_2h`/`adv_13` now read "Y" where the runner scored.

**Step 7:** Commit on `feature/astros-intangibles`.

---

## Task 6b (conditional): Fix `snapshot_data.py`

Only if Task 1 Step 2 found it computes its own success. Apply the identical canonical swap; verify the snapshot BR section matches the tracker; commit on `feature/astros-intangibles`.

---

## Task 7: Cross-surface parity verification (work laptop)

**Step 1:** Pick one AAX player with known 2→H + 1→3 activity in 2026. Pull his 2→H/1→3 from: tracker (live, pin bypassed), KPI weekly, PD-Goals org section, daily report sum. **All four must agree.** Any mismatch = a missed site or an asymmetric edit — fix before proceeding.

**Step 2:** Re-run the Task 2 harness; confirm accuracy unchanged from the locked number.

**Step 3:** No commit (verification only) unless a fix was needed.

---

## Task 8: Re-pin + redeploy + delete dead file

**Step 1 (work laptop):** re-pin BR tracker so the live app reflects the new logic:
```bash
cd C:\Users\zbridger\bsb-wt-intangibles\astros-intangibles
git pull
python intangibles/scripts/pin_br_tracker_seasons.py    # full; ~per tracker-parquet-pins.md
```
(Pin CLI already bypasses `_TRACKER_PINS_AVAILABLE` per §5.13 — confirm it re-queries DB.)

**Step 2:** Redeploy Intangibles (BR tracker + KPI weekly) and PD Engine (org KPI) per the standard rsconnect deploy.

**Step 3:** Delete dead `baserunning_base.py` (confirmed dead in Task 1) on `feature/astros-intangibles`:
```bash
git rm intangibles/src/baserunning_base.py
git commit -m "chore(br): delete dead baserunning_base.py (no live importers; logic lived in br_data/br_tracker_data)"
```

**Step 4 (verify in deployed apps):** Sullivan's game + a couple fixture plays show the credit; tracker/KPI/PD-Goals agree.

---

## Task 9: Document the BLOCKING rule + sync 4 worktrees

**Files:**
- Create: `.claude/rules/br-advancement-scored-logic.md` (BLOCKING)

**Step 1:** Write the rule: the `outs_after = outs_before` trap, the canonical lead-first run-attribution rule (2→H + 1→3, with the exact SQL/Python), the surface inventory, the Camden-fixture regression test, and a "what NOT to do" (don't use outs-delta as a scored proxy; don't ship naive `runs>0`; keep ft3_opps LF-branch in sync with ft3_success).

**Step 2:** Use the **document-pattern** skill so it auto-syncs byte-identical to all 4 worktrees; verify md5 match.

**Step 3:** Cross-reference it from `three-surface-parity.md` (BR bug-history) and `reference-impl-index.md` (1→3 / 2→H entry — update the "single-only by design" note to add the run-attribution scored rule).

**Step 4:** Append a graduation-log entry (`.claude/rules/.graduation-log.md`) summarizing the fix + commits + the validated accuracy.

**Step 5:** Commit on `feature/pd-goals` + sync commits on the 3 sibling worktrees.

---

## What NOT to do

- **Don't ship the naive `runs_on_play > 0`** — it over-credits runner-on-3rd plays (76% / 9 false credits). Always the lead-first `rank` test.
- **Don't edit `baserunning_base.py` to "fix" it** — it's dead; delete it.
- **Don't change the OF gate or the opportunity definition** — only the *success* (scored) determination changes (plus the coupled ft3_opps LF-branch).
- **Don't fix one surface and ship** — three-surface-parity means tracker + KPI + PD-Goals + daily move together or numbers diverge.
- **Don't skip the re-pin** — the tracker reads the pin; code-only changes won't show until re-pinned (tracker-parquet-pins.md).
- **Don't validate positionally** — join Camden's fixture on `(sched_id, event_id)`.
- **Don't forget `top_of_inning`** when computing `runs_on_play` — home vs away score column depends on it.
