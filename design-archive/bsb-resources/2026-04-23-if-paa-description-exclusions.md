# IF PAA Description-Based Exclusions Implementation Plan

> **⚠️ SHELVED 2026-04-23 — DO NOT EXECUTE WITHOUT GATE UNLOCK ⚠️**
>
> **Why shelved:** Farm Director debating whether the org stays on GC2's current
> PAA methodology or switches to a different framework. This plan's entire
> premise (patching the GC2 `Astros.Defense_Combined_By_Pos` PAA values via
> description-based CASE WHEN) is moot if we swap off GC2. Don't sink
> 10-file editing time until that decision lands.
>
> **Gate to resume:** Farm Director commits to staying on GC2. Once confirmed,
> pick up at Phase 0 (user runs impact SQL) — nothing upstream changes.
>
> **Artifacts preserved:**
> - This plan document (all task definitions remain valid)
> - `sql-queries/if-paa-exclusions-impact.sql` (ready to run as Phase 0 pre-flight)
> - TaskCreate list (18 tasks, all pending, ready to resume)
> - Shelf memory: `memory/if-paa-description-exclusions-shelved.md`
>
> **What to do on resume:** Re-read this plan top-to-bottom, re-run the impact
> SQL to get fresh numbers (2026 data may have moved), re-confirm the 4 LIKE
> patterns match current GC2 description conventions, then dispatch subagents
> per the original task order (Task 1.1 first, everything downstream cascades).
>
> **Do NOT touch production files (fielding_base.py etc.) until gate unlocks.**

---

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** On DCBP rows where an IF fielder is being docked for a play owned by the pitcher or 1B:
  - **Group A (pitcher plays):** zero `paa`, `out_prob`, AND `drv` for all IF positions — neutralize the row.
  - **Group B (1B missed catch):** FLIP PAA sign (negative → positive) for 2B/3B/SS; leave `out_prob` and `drv` unchanged; leave 1B entirely untouched. Credit the scramble.
Propagate across 10 IF-touching files in intangibles + pd-goals worktrees.

**Architecture:** Three per-column `CASE WHEN` expressions replicated in every SQL query that SELECTs `dcbp.paa`/`dcbp.out_prob`/`dcbp.drv`. The three CASE blocks DIFFER: `paa` has zero + flip branches, `out_prob` and `drv` have zero branches only (Group B falls through). Rows stay visible in per-play tables; Group A rows show `0.00`, Group B rows show positive PAA with original out_prob/drv. All three columns gated by `dcbp.paa < 0` — never strip deserved credit.

**Tech Stack:** SQL Server T-SQL, pyodbc, Python 3.11 (intangibles) / 3.13 (work laptop for pinning).

---

## The Canonical Predicates (three per-column CASE blocks)

Every SELECT that exposes `dcbp.paa`, `dcbp.out_prob`, or `dcbp.drv` MUST wrap it. UNLIKE the earlier draft, the three CASE blocks now DIFFER — `paa` has a sign-flip branch on Group B; `out_prob` and `drv` have zero-only branches (Group B falls through the ELSE unchanged).

### PAA column — zero on Group A, SIGN-FLIP on Group B

```sql
CASE
    WHEN pg.pos_id IN (3,4,5,6) AND dcbp.paa < 0
         AND (ev.play_by_play LIKE '%singles on a ground ball to pitcher%'
           OR ev.play_by_play LIKE '%singles on a soft bunt ground ball to pitcher%'
           OR ev.play_by_play LIKE '%deflected by pitcher%')
        THEN 0.0
    WHEN pg.pos_id IN (4,5,6) AND dcbp.paa < 0
         AND ev.play_by_play LIKE '%reaches on a missed catch error by first baseman%'
        THEN -dcbp.paa                  -- FLIP: -0.7 becomes +0.7
    ELSE dcbp.paa
END AS paa
```

### out_prob column — zero on Group A only; Group B unchanged

```sql
CASE
    WHEN pg.pos_id IN (3,4,5,6) AND dcbp.paa < 0
         AND (ev.play_by_play LIKE '%singles on a ground ball to pitcher%'
           OR ev.play_by_play LIKE '%singles on a soft bunt ground ball to pitcher%'
           OR ev.play_by_play LIKE '%deflected by pitcher%')
        THEN 0.0
    ELSE dcbp.out_prob
END AS out_prob
```

### drv column — zero on Group A only; Group B unchanged

```sql
CASE
    WHEN pg.pos_id IN (3,4,5,6) AND dcbp.paa < 0
         AND (ev.play_by_play LIKE '%singles on a ground ball to pitcher%'
           OR ev.play_by_play LIKE '%singles on a soft bunt ground ball to pitcher%'
           OR ev.play_by_play LIKE '%deflected by pitcher%')
        THEN 0.0
    ELSE dcbp.drv
END AS drv
```

### Three critical rules

1. **IF scope.** Group A touches pos_id IN (3,4,5,6). Group B touches only (4,5,6) — 1B (pos_id=3) stays fully untouched on missed-catch plays because they own the muff.
2. **Negative-only gate.** `AND dcbp.paa < 0` ensures we only transform penalties, never strip deserved credit. If paa is positive on a matching play, all three columns stay as-is.
3. **Group A is symmetric across all three columns; Group B is PAA-only.** out_prob and drv don't get touched on Group B because the scrambling fielder DID have an opportunity and DID have run-value context — we just recognize their good work via sign-flipped PAA.

### Outcome matrix

| Play type | pos_id=3 (1B) | pos_id=4,5,6 (2B/3B/SS) |
|---|---|---|
| Group A pattern + paa<0 | paa=0, out_prob=0, drv=0 | paa=0, out_prob=0, drv=0 |
| Group A pattern + paa≥0 | all unchanged | all unchanged |
| Group B pattern + paa<0 | all unchanged (owns the muff) | **paa=-paa (flipped positive)**, out_prob unchanged, drv unchanged |
| Group B pattern + paa≥0 | all unchanged | all unchanged |
| Neither pattern | all unchanged | all unchanged |

### Table alias assumption

The predicate assumes these aliases exist in the host query:
- `pg` = `Astros.Players_Games` (for `pos_id`)
- `ev` = `Astros.Events_View` (for `play_by_play`)
- `dcbp` = `Astros.Defense_Combined_By_Pos` (for `paa`/`out_prob`/`drv`)

If a query uses different aliases (`p`, `e`, `d`, etc.), remap the predicate before pasting.
If a query doesn't join `Events_View` yet, add `LEFT JOIN Astros.Events_View ev ON ev.sched_id = dcbp.sched_id AND ev.event_id = dcbp.event_id` (or equivalent based on existing join pattern).

---

## File Inventory (scope reminder — IF only, OF is out of scope)

### Intangibles worktree: `C:\Users\Owner\bsb-wt-intangibles\astros-intangibles\intangibles\`

| # | File | Role |
|---|---|---|
| 1 | `src/fielding_base.py` | **Tier 1** — shared base CTE; the leverage file |
| 2 | `src/fielding_tracker_data.py` | Tier 2 — parallel org queries (4+) |
| 3 | `src/if_kpi_data.py` | Tier 2 — monthly chart + org agg |
| 4 | `src/if_postgame_data.py` | Tier 2 — per-play |
| 5 | `src/if_postgame_percentiles.py` | Tier 2 — pool for postgame coloring |
| 6 | `src/if_weekly_data.py` | Tier 2 — per-player weekly |
| 7 | `src/snapshot_data.py` | Tier 2 — IF scope within shared file |

### PD-Goals worktree: `C:\Users\Owner\bsb-resources\pd-goals\`

| # | File | Role |
|---|---|---|
| 8 | `src/org_kpi_data.py` | Tier 3 — `_IF_VALUE_ORG_QUERY` (~line 1562) |
| 9 | `src/stats.py` | Tier 3 — per-fielder PAA/EO fetch |
| 10 | `src/percentiles.py` | Tier 3 — percentile pool (verify whether IF) |

### OUT OF SCOPE (do not touch)

`of_weekly_data.py`, `of_kpi_data.py`, `of_postgame_data.py`, `of_postgame_percentiles.py` — user confirmed OF stays as-is.

---

## Phase 0: Impact Validation (pre-flight, no code change)

### Task 0.1: User runs impact query on work laptop

**File:** `C:\Users\Owner\bsb-resources\sql-queries\if-paa-exclusions-impact.sql` (already written)

**Step 1:** User pulls the latest on `feature/pd-goals` on work laptop:
```
git pull
```

**Step 2:** User runs `sql-queries/if-paa-exclusions-impact.sql` against GCSQL02.

**Step 3:** Paste output into chat. Look for:
- HOU fielders with `|paa_eo_delta| > 0.020` (meaningful improvement)
- Tommy Sacco specifically (gcid 82035) — expected biggest mover
- `paa_groupA_zapped_sum` always ≤ 0 (we only zero negatives)
- `paa_groupB_credit_sum` always ≥ 0 (flipped negatives become positive)
- **`paa_eo_delta` ≥ 0 for every fielder** — no one gets worse. Big positive swings expected on fielders with Group B flips (2× swing from -paa to +paa)

**Step 4:** User confirms scope is acceptable. If unexpected fielders appear or deltas seem off, STOP and redesign.

**Exit criteria:** User explicit go-ahead to proceed.

---

## Phase 1: Intangibles Worktree Patch

All work on branch `feature/astros-intangibles` in `C:\Users\Owner\bsb-wt-intangibles\astros-intangibles\`.

### Task 1.1: Patch `fielding_base.py`

**File:** `intangibles/src/fielding_base.py` lines ~95–120

**Step 1:** Read the current BASE_QUERY SELECT block to confirm the exact position of `dcbp.paa`, `dcbp.out_prob`, `dcbp.drv`:

```
Read file_path="C:\Users\Owner\bsb-wt-intangibles\astros-intangibles\intangibles\src\fielding_base.py" offset=90 limit=40
```

**Step 2:** Replace the raw `dcbp.paa`, `dcbp.out_prob`, `dcbp.drv` columns with three CASE WHEN blocks using the canonical predicate above. Each column gets its own block; the WHEN conditions are identical across all three, only the ELSE changes.

**Template:** paste the three CASE blocks from the "Canonical Predicates" section above verbatim — PAA has a sign-flip branch, out_prob and drv have zero-only branches. Do NOT copy the same predicate three times; `paa` and the other two DIFFER.

Note: all three CASE blocks share the `dcbp.paa < 0` gate. But the Group B behavior differs — PAA flips sign, out_prob and drv pass through ELSE unchanged.

**Step 3:** Verify `ev.play_by_play` is accessible in this query (grep for `ev.play_by_play` or `Events_View ev` in the file). If not, the query already has `ev` alias (confirmed — the file's BASE_QUERY joins Events_View). Done.

**Step 4:** Commit (hold — will commit all intangibles edits in a single task at the end).

### Task 1.2: Grep direct DCBP queries outside `fielding_base.py`

**Purpose:** Some files may query DCBP directly, bypassing the base CTE. Identify them.

**Step 1:** In each of these files, grep for `Defense_Combined_By_Pos`, `dcbp.paa`, `dcbp.out_prob`, `dcbp.drv`:
- `fielding_tracker_data.py`
- `if_kpi_data.py`
- `if_postgame_data.py`
- `if_postgame_percentiles.py`
- `if_weekly_data.py`
- `snapshot_data.py`

**Step 2:** For each file, produce a short list of `query_variable_name: line_range` where the raw column is SELECTed.

**Step 3:** Cross-check if the query joins via `fielding_base.py`'s `BASE_QUERY` string (grep for `BASE_QUERY` or `from .fielding_base import`). If yes → the Task 1.1 fix already covers it; skip. If no → needs its own patch.

**Exit:** Table listing each file and which queries need direct patching vs. inherit from base.

### Task 1.3: Patch `fielding_tracker_data.py`

**File:** `intangibles/src/fielding_tracker_data.py`

**Step 1:** Using Task 1.2's list, locate each direct-DCBP query in this file (likely the 4 org-level queries: `_ORG_TRACKING_AGG_QUERY`, `_ORG_MONTHLY_TRACKING_AGG_QUERY`, and the DCBP-direct counterparts).

**Step 2:** For each query that does NOT import from `fielding_base.py::BASE_QUERY`, replace raw `dcbp.paa`, `dcbp.out_prob`, `dcbp.drv` columns with the 3 CASE WHEN blocks (same template as Task 1.1).

**Step 3:** Verify each modified query has `Events_View ev` joined. If not, add:
```sql
LEFT JOIN Astros.Events_View ev
    ON ev.sched_id = dcbp.sched_id
    AND ev.event_id = dcbp.event_id
```

**Step 4:** Also verify each has `Players_Games pg` with `pos_id` accessible.

**Step 5:** Hold commit.

### Task 1.4: Patch `if_kpi_data.py`

**File:** `intangibles/src/if_kpi_data.py`

Same procedure as Task 1.3. Two queries expected: monthly chart + org agg. Patch direct-DCBP queries only; if any reuse `BASE_QUERY`, skip.

### Task 1.5: Patch `if_postgame_data.py`

**File:** `intangibles/src/if_postgame_data.py`

**Per-play display critical:** This file powers the per-play table in the postgame PDF. Verify after patch that a zapped row shows `PAA=0.00, OutProb=0.00, DRV=0.00` but the row itself IS still present. The CASE WHEN only zeros values — never removes the row.

### Task 1.6: Patch `if_postgame_percentiles.py`

**File:** `intangibles/src/if_postgame_percentiles.py`

Percentile pool query — every IF fielder in the league contributes. Patch the pool-query DCBP SELECTs.

### Task 1.7: Patch `if_weekly_data.py`

**File:** `intangibles/src/if_weekly_data.py`

**Step 1:** Check if this file touches IF PAA at all, or if it's purely OF (weekly reports may be domain-agnostic).

**Step 2:** If IF-relevant blocks exist, patch them with the canonical CASE WHEN. If purely OF, skip (OF is out of scope).

### Task 1.8: Patch `snapshot_data.py`

**File:** `intangibles/src/snapshot_data.py`

**Step 1:** Grep for IF-specific DCBP queries (look for `pos_id IN (3,4,5,6)` or 1B/2B/3B/SS references). This file handles both OF + IF via shared logic OR has domain-split queries.

**Step 2:** Patch only the IF-side queries. Leave OF-side queries untouched.

### Task 1.9: Commit + push intangibles changes

**Step 1:** Stage only the files touched in Tasks 1.1 through 1.8.

```bash
cd /c/Users/Owner/bsb-wt-intangibles/astros-intangibles
git add intangibles/src/fielding_base.py intangibles/src/fielding_tracker_data.py intangibles/src/if_kpi_data.py intangibles/src/if_postgame_data.py intangibles/src/if_postgame_percentiles.py intangibles/src/if_weekly_data.py intangibles/src/snapshot_data.py
```

**Step 2:** Commit:
```bash
git commit -m "$(cat <<'EOF'
feat(intangibles): IF PAA description-based adjustments on 4 play patterns

Adds three per-column CASE WHEN (paa/out_prob/drv) across all IF queries.
Gated by dcbp.paa < 0 so positive PAA rows keep their credit.

Group A — pitcher plays (zero paa + out_prob + drv for pos_id IN 3,4,5,6):
- singles on a ground ball to pitcher
- singles on a soft bunt ground ball to pitcher
- deflected by pitcher

Group B — 1B missed catch (FLIP PAA sign for pos_id IN 4,5,6; out_prob/drv
unchanged; 1B entirely unchanged):
- reaches on a missed catch error by first baseman

Plan: docs/plans/2026-04-23-if-paa-description-exclusions.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Step 3:** Push:
```bash
git push
```

**Exit:** Intangibles branch updated.

---

## Phase 2: PD-Goals Worktree Patch

All work on branch `feature/pd-goals` in `C:\Users\Owner\bsb-resources\`.

### Task 2.1: Patch `pd-goals/src/org_kpi_data.py`

**File:** `C:\Users\Owner\bsb-resources\pd-goals\src\org_kpi_data.py` around line 1562

**Step 1:** Read `_IF_VALUE_ORG_QUERY` (line 1562 per the grep):
```
Read file_path="C:\Users\Owner\bsb-resources\pd-goals\src\org_kpi_data.py" offset=1556 limit=70
```

**Step 2:** Confirm the query joins `Events_View` with `play_by_play` accessible. If not, add:
```sql
LEFT JOIN Astros.Events_View ev
    ON ev.sched_id = dcbp.sched_id
    AND ev.event_id = dcbp.event_id
```

**Step 3:** Replace `dcbp.paa`, `dcbp.out_prob`, `dcbp.drv` with 3 CASE WHEN blocks using the canonical predicate.

**Step 4:** Verify `pg.pos_id` alias is accessible (or use the equivalent alias from the file's JOIN).

**Step 5:** Grep for other IF-relevant queries in the same file (hitting, pitching, etc. live here too — only touch IF value/fielding blocks). There may be a per-player query separate from `_IF_VALUE_ORG_QUERY`.

### Task 2.2: Patch `pd-goals/src/stats.py`

**File:** `C:\Users\Owner\bsb-resources\pd-goals\src\stats.py`

**Step 1:** Grep for `dcbp.paa`, `dcbp.drv`, `Defense_Combined_By_Pos` in this file.

**Step 2:** For each IF-scoped DCBP query, apply the CASE WHEN predicate.

**Step 3:** Skip OF-scoped queries (same file likely has OF blocks; scope to `pos_id IN (3,4,5,6)` IF blocks only).

### Task 2.3: Check `pd-goals/src/percentiles.py`

**File:** `C:\Users\Owner\bsb-resources\pd-goals\src\percentiles.py`

**Step 1:** Grep for `dcbp.paa` and `Defense_Combined_By_Pos`.

**Step 2:** Per earlier memory note: percentiles.py has PAA/EO constants defined but may not be wired. Verify whether it queries DCBP or just holds metric definitions.

**Step 3:** If it DOES query DCBP for IF percentiles, apply CASE WHEN. If not, skip.

### Task 2.4: Commit + push PD-Goals changes

**Step 1:** Stage:
```bash
cd /c/Users/Owner/bsb-resources
git add pd-goals/src/org_kpi_data.py pd-goals/src/stats.py
# add pd-goals/src/percentiles.py only if Task 2.3 patched it
```

**Step 2:** Commit:
```bash
git commit -m "$(cat <<'EOF'
feat(pd-goals): mirror IF PAA description exclusions from intangibles

Adds the same CASE WHEN predicate to _IF_VALUE_ORG_QUERY + stats.py
(+ percentiles.py if wired) so PD-Goals three-surface parity holds with
intangibles tracker + KPI weekly.

Plan: docs/plans/2026-04-23-if-paa-description-exclusions.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Step 3:** Push:
```bash
git push
```

---

## Phase 3: Verification (parity + spot-check)

### Task 3.1: Run impact query a second time post-patch

**Step 1:** User on work laptop, `feature/pd-goals` branch, runs the same `if-paa-exclusions-impact.sql` again.

**Step 2:** Confirm the "current" and "filtered" columns converge — since production now matches the filtered path, the delta should be zero-ish for all fielders (or the production query should now match the prior "filtered" output).

**Method:** If the impact query's "current" is unchanged (it only computes the predicate in the test SQL itself, doesn't hit production), then parity is verified by running `SELECT SUM(paa), SUM(out_prob) FROM <production query>` for HOU and comparing against the test query's "filtered" column for HOU.

### Task 3.2: Three-surface parity check for HOU IF

**Purpose:** Verify tracker, KPI weekly, and PD-Goals all show the same IF PAA/EO for HOU after patches land + deploy.

**Step 1:** User redeploys intangibles + PD-Goals on Connect.

**Step 2:** Open intangibles Affiliate Tracker → Infield tab → Org Rankings → HOU row. Note PAA/EO.

**Step 3:** Open intangibles IF KPI Weekly report PDF for HOU (or spot-check via app). Note PAA/EO.

**Step 4:** Open PD-Goals org KPI report → Infield section. Note PAA/EO.

**Step 5:** All three should match within 0.001. If divergence, identify which surface is still using the old formula (likely: a query was missed in Tasks 1.2–1.8).

### Task 3.3: Per-play table visual check

**Purpose:** Confirm transformed rows stay visible with the right values.

**Group A check — pitcher plays should show 0.00 across the board:**

**Step 1:** Pull up an intangibles IF postgame PDF for a date with a "ground ball to pitcher" play (e.g., Row 10 in user's CSV: afa 2026-04-02).

**Step 2:** Find the subsequent IF fielder's row for that event.

**Step 3:** Confirm:
- Row IS visible
- PAA column = 0.00
- OutProb column = 0.00
- DRV column = 0.00 (if displayed)
- Play description readable

**Group B check — missed catch plays show POSITIVE PAA with original out_prob:**

**Step 4:** Pull up an IF postgame PDF with a "reaches on a missed catch error by first baseman" play (e.g., Row 3 afx 2026-04-11).

**Step 5:** Find a 2B/3B/SS row on that event (NOT the 1B row).

**Step 6:** Confirm:
- Row IS visible
- PAA column is now POSITIVE (e.g., Row 3 was paa=-0.968 → should show +0.968)
- OutProb column is UNCHANGED from original value (~0.96-0.99)
- DRV column is UNCHANGED from original value
- 1B row on the SAME event is entirely unchanged (negative PAA, original out_prob)

**Step 7:** If any row is missing (filtered out) OR shows wrong value, there's a bug. Grep for `WHERE.*singles on a ground ball to pitcher` or `WHERE.*reaches on a missed catch` to find accidental WHERE filters.

### Task 3.4: Spot-check Tommy Sacco

**Step 1:** Note Sacco's (gcid 82035) pre-patch PAA/EO from the impact query's "current" column.

**Step 2:** After patches deploy, check Sacco's live PAA/EO in the Affiliate Tracker (or re-run the production query via work laptop).

**Step 3:** Confirm his new PAA/EO matches the impact query's "filtered" column for him.

**Exit:** Three-surface + per-play + Sacco all green.

---

## Phase 4: Pin Re-Build (IF only)

### Task 4.1: Kill in-flight IF pin if any

**Step 1:** User checks terminal — if a `pin_fielding_tracker_seasons.py --domain IF` is running, kill it.

### Task 4.2: Rebuild all 4 IF pins

**Work laptop:**
```powershell
cd C:\Users\Owner\bsb-wt-intangibles\astros-intangibles\intangibles
git pull
$env:CONNECT_API_KEY = "H9MB6feNB2ccKfmoX9Q3DS7AykVhvNNb"
python scripts/pin_fielding_tracker_seasons.py --domain IF
```

Expected runtime: ~45–60 min for 4 years (2022, 2023, 2024, 2025).

**If 2024 stalls again** (historical issue from Apr 22):
```powershell
python scripts/pin_fielding_tracker_seasons.py --year 2024 --domain IF
```
Run alone overnight.

### Task 4.3: Verify pin writes on Connect

**Step 1:** After CLI completes, user confirms OK messages for each (domain, year) tuple.

**Step 2:** Redeploy intangibles if any schema/import changes made it in.

**Step 3:** Flip to a historical year (e.g., 2024) in the tracker — should feel instant (pin hit). Logs should show `[PIN] load_tracker_bundle(...)` SUCCESS.

---

## Phase 5: Documentation + Rules Sync

### Task 5.1: Update `rules/fielding.md`

**File:** `C:\Users\Owner\bsb-resources\.claude\rules\fielding.md`

Add a new section "IF PAA Description-Based Adjustments" documenting:
- The 4 patterns (exact LIKE strings)
- Group A vs Group B: Group A zeros paa+out_prob+drv; Group B flips PAA sign only
- The `paa < 0` gate (only transform penalties, never strip credit)
- 1B (pos_id=3) untouched on Group B — owns the muff
- Outcome matrix per pos_id × play type
- File inventory across intangibles + pd-goals

### Task 5.2: Update `rules/three-surface-parity.md`

**File:** `C:\Users\Owner\bsb-resources\.claude\rules\three-surface-parity.md`

Append a "Bug history" entry under IF:
- Date: 2026-04-23
- Summary: IF PAA description exclusions across 3 surfaces
- Files touched: list
- Commit SHAs: fill in post-commit

### Task 5.3: Sync rules to all 4 worktrees

**Method:** Copy updated files from `bsb-resources/.claude/rules/` to each worktree's `.claude/rules/`:
- `bsb-wt-bullpen/.claude/rules/`
- `bsb-wt-intangibles/astros-intangibles/.claude/rules/`
- `bsb-wt-hitting/.claude/rules/`

Commit + push on each worktree's branch (per `User Preferences: Auto-push to worktrees`).

### Task 5.4: Append to graduation log

**File:** `C:\Users\Owner\bsb-resources\.claude\rules\.graduation-log.md`

Add entry:
```markdown
## 2026-04-23 — IF PAA description-based adjustments shipped

- 10 files across intangibles + pd-goals now apply per-column CASE WHEN
- Group A (pitcher plays): zero paa+out_prob+drv for pos_id IN (3,4,5,6)
  - "singles on a ground ball to pitcher"
  - "singles on a soft bunt ground ball to pitcher"
  - "deflected by pitcher"
- Group B (1B missed catch): FLIP PAA sign for pos_id IN (4,5,6);
  out_prob/drv unchanged; 1B (pos_id=3) entirely unchanged
  - "reaches on a missed catch error by first baseman"
- Gate: dcbp.paa < 0 (only transform penalties, never strip credit)
- IF pins re-built (2022–2025)
- Plan: docs/plans/2026-04-23-if-paa-description-exclusions.md
- Commits: [intangibles SHA], [pd-goals SHA]
```

---

## Out of Scope (explicitly NOT in this plan)

- OF (outfield) PAA refactor — user confirmed OF stays as-is
- Catcher PAA — not part of this refactor
- Additional description patterns — user gave exactly 4, nothing else
- BR (baserunning) — unaffected
- Postgame OF pins — separate from IF pin invalidation

## Risks + Mitigations

| Risk | Mitigation |
|---|---|
| A file queries DCBP via a path we don't spot in Task 1.2 | Phase 3 parity check catches any missed surface |
| `ev.play_by_play` not joined in a specific query | Task procedure explicitly verifies + adds JOIN if missing |
| Predicate typo (missed LIKE pattern, wrong pos_id list) | Impact query in Phase 0 validates predicate shape before any prod changes |
| PD-Goals per-player PAA in `stats.py` has different alias convention | Task 2.2 reads the file first, adapts alias |
| Postgame per-play table loses zapped rows | Task 3.3 visual check catches this; bug would be `WHERE` vs `CASE WHEN` confusion |
| Pin rebuild stalls again on 2024 | Task 4.2 fallback: run 2024 alone overnight |

## Files in This Plan — Quick Copy List

Intangibles (7 files):
```
intangibles/src/fielding_base.py
intangibles/src/fielding_tracker_data.py
intangibles/src/if_kpi_data.py
intangibles/src/if_postgame_data.py
intangibles/src/if_postgame_percentiles.py
intangibles/src/if_weekly_data.py
intangibles/src/snapshot_data.py
```

PD-Goals (2–3 files):
```
pd-goals/src/org_kpi_data.py
pd-goals/src/stats.py
pd-goals/src/percentiles.py  (conditional — if Task 2.3 determines it's wired)
```

Rules + docs (4 files):
```
.claude/rules/fielding.md
.claude/rules/three-surface-parity.md
.claude/rules/.graduation-log.md
docs/plans/2026-04-23-if-paa-description-exclusions.md  (this file)
```

---

## End State

After all phases complete:
- Every IF PAA/EO surface (tracker, KPI weekly, postgame, weekly, PD-Goals org, PD-Goals per-player) uses the same three per-column CASE WHEN
- Group A pitcher plays: per-play postgame tables show `0.00` across paa/out_prob/drv (visible but doesn't count)
- Group B 1B missed-catch plays: per-play postgame tables show POSITIVE paa for 2B/3B/SS with unchanged out_prob/drv (credit for scrambling to contain damage). 1B row on those plays entirely unchanged (they own the muff).
- Aggregates (PAA/EO, OAA, RAA): Group A collapses to zero, Group B nets a positive swing for the scramblers
- Three-surface parity verified for HOU IF
- Historical IF pins (2022–2025) re-built with new formula
- OF completely untouched
