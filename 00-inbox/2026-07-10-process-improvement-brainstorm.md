# Process-Improvement Brainstorm - Astros PD Analytics Engineering

IDEATION ONLY. No files in any repo were touched. Ranked by payoff-to-effort.
Grounded in the actual stack (Python 3.11 + Streamlit on Posit Connect, SQL Server
GroundControl2 read-only, joblib/parquet pins, 4 worktrees, personal-vs-work laptop
split, PowerShell cascades to Slack via Logic App) and the documented friction in
`.claude/rules/` (prp-pin-wipe-recovery, pd-goals-prp-connected-cycle,
tracker-parquet-pins, three-surface-parity, render-and-look, pin-deploy-runbook,
windows-toolchain).

IT hard constraints assumed throughout: no SMTP AUTH, Slack webhooks/bot install
denied, Connect-only hosting, SQL Server is READ-ONLY from our code (the "real fix"
DB table with row-level UPDATE is blocked on IT), no Claude Code on the work laptop,
no DB/Connect reachability from the personal laptop.

---

## The scoring key

- Payoff = how much recurring pain it removes (the bug classes are documented, not hypothetical).
- Effort S/M/L = personal-laptop code S<1 day, M a few days, L a week-plus incl work-laptop runs.
- Every idea has a skeptic line: the honest reason it might not be worth it for US.

---

## 1. `safe_pin_write()` - one guarded write wrapper for EVERY pin (contract + shrink-floor + version-CAS + provenance stamp)

- **Friction removed:** The dtype-triad cascade of 5 bugs (pd-goals-prp-connected-cycle),
  the 48->10 PRP mass-wipe (prp-pin-wipe-recovery), sparse-pin writes (tracker-parquet-pins
  5.14/§10), and "which code built this pin" uncertainty. Today the anti-shrink guard
  lives ONLY in `pin_prp_records.py::_pin_write`; every other pin writer is unguarded.
- **External pattern:** Data-contract-on-write + optimistic concurrency (compare-and-swap)
  + write-audit. Draw on pandera schema contracts (`@pa.check_types`, decorator, pure-pandas,
  no server) and the classic lost-update/CAS guard. Provenance = a `_meta` sidecar key
  (git SHA, build UTC, per-key row counts) - the "data version" that Connect pruning erases.
- **What it does:** A single helper all writers call instead of `board.pin_write`. It (a)
  validates the frame against a registered pandera schema (dtypes, nullability, allowed
  values) so the Int64-vs-string-vs-object triad is caught at the boundary, not 5 bugs
  later; (b) refuses a >N-row/player shrink unless `force=True` (generalize the PRP guard);
  (c) reads the current pin's version hash and refuses to write if it changed since the
  read the caller started from (kills concurrent-save clobber); (d) stamps `_meta`.
- **Fit:** Pure Python, pins-native, zero IT. pandera is one pip line, already-installable
  in a Connect bundle. Compatible with joblib AND parquet pins.
- **Effort:** S (one module + register schemas incrementally as writers adopt it).
- **Risk:** Low. Opt-in per writer; the shrink-guard precedent already works in production.
- **Payoff:** Very high. This is the single highest-ratio item - it retires 3 documented
  wipe/dtype/sparse bug classes with a few hundred lines.
- **Skeptic:** It is defense-in-depth, not the structural fix. It makes clobbers LOUD and
  RARE, it does not make the shared-pin RMW architecture go away (that is idea 2). If you
  do idea 2, some of this guard's job shrinks.

## 2. Shard the shared state pins per-player (or append-only event log) to kill RMW clobber at the root

- **Friction removed:** The entire whole-pin read-modify-write clobber class. PRP and goals
  both store ALL players in ONE pin; any writer that reads a thin/blank state and writes it
  back wipes everyone (documented Jun 25-26 AND Jul 8, plus the goals cascade). The rules
  themselves name the real fix as row-level UPDATE, blocked on IT.
- **External pattern:** Two options, both avoid IT. (a) Shard - one pin per player
  (`prp_records_<season>_<gcid>`); a save rewrites exactly ONE player's pin, so cross-player
  blast radius is structurally zero (this is the "aggregate per entity" idea from event
  stores). (b) Event sourcing / append-only log - each save APPENDS an immutable event; read
  folds events to current state. You never overwrite, so a thin read cannot erase history,
  and the log gives you the audit trail Connect pruning currently destroys.
- **Fit:** pins supports arbitrarily many named/versioned pins; both options are Connect-native,
  no IT. Sharding is the lower-lift of the two. Read cost = list+load N small pins (cache it).
- **Effort:** M (migrate the PRP + goals loaders + writers; one-time reseed from current pin).
- **Risk:** Medium. More pin objects to manage; a "list all player pins" read path replaces a
  single load. The daily EBIS roster sync writer must be ported carefully.
- **Payoff:** High. Removes the highest-severity, most-repeated production incident class
  (coach-visible data "vanishing").
- **Skeptic:** If IT ever grants a single writable table, that beats both and this migration
  is throwaway. Worth asking IT for one narrow writable schema BEFORE committing to sharding -
  a small ask (one table, one service login) vs a full DB. If they say no (likely), shard.

## 3. Golden-fixture + synthetic-data CI - verify LOGIC where the code is written (personal laptop)

- **Friction removed:** The core of the personal-vs-work laptop split. Nothing data-dependent
  can be checked where Claude Code runs; the verification-backlog piles up; "what do I run now"
  is asked 10+ times. You already have the seeds of this (`--check-p95` byte-identical harness,
  the goal-parser golden-diff). This generalizes them into a gate.
- **External pattern:** CI for data pipelines on a no-warehouse dev box: pin small golden
  input/output fixtures, run transformations against them with pytest, assert byte-identical
  output. Plus pandera contract tests on the fixtures. Runs on GitHub Actions (repo is on
  GitHub via SSH) or a local pre-push hook - no DB, no Connect needed.
- **What it catches on the PERSONAL laptop, today impossible:** metric aggregation regressions,
  the dtype-triad, org-code CASE drops (feed a 30-org fixture, assert 30 out), three-surface
  parity (run all 3 surface fns on the same fixture, assert equal), rounding drift.
- **Fit:** Pure Python + committed fixtures. Zero IT. Fixtures are SYNTHETIC or fully
  anonymized so no player data leaves the work network.
- **Effort:** M (build a fixtures/ set + a pytest suite; wire a GH Action).
- **Risk:** Medium. Fixtures must be representative or they give false confidence; they need
  maintenance when schemas change.
- **Payoff:** High. Directly shrinks the verification-backlog and moves failure-detection
  left, off the scarce work-laptop time.
- **Skeptic:** It never exercises REAL data shapes (HawkEye sparsity, league-split woba rows,
  traded-player org rows). Some bugs only appear against GCSQL02. It reduces work-laptop
  round-trips; it does not eliminate them.

## 4. Pin provenance + immutable versioning (the data-versioning gap Connect pruning creates)

- **Friction removed:** Connect prunes old pin versions (the Jul 8 good PRP version 51802 was
  pruned and UNRECOVERABLE). No pin records which git SHA / query built it, so "is this pin
  stale after a metric fix" is guesswork (tracker §5.13 exists precisely because stale pins
  look fine).
- **External pattern:** Immutable, content-addressed data versioning (lakeFS/DVC philosophy,
  applied minimally). Every pin bundle carries a `_meta` key {git_sha, build_utc, row_counts,
  code_version}; critical snapshots (PRP daily) also written under an immutable dated name that
  the pruner will not reclaim.
- **Fit:** `_meta` is free (part of idea 1's stamp). Immutable dated snapshots = one extra
  `pin_write` per day to a name you never overwrite; a tiny scheduled retention job trims by age.
- **Effort:** S.
- **Risk:** Low. Storage grows; add an age-based trim.
- **Payoff:** Medium-high. Turns "unrecoverable wipe" into "restore yesterday's immutable
  snapshot" and makes stale-pin detection a SHA comparison instead of memory.
- **Skeptic:** Mostly insurance. If ideas 1-2 land, wipes become rare enough that the
  snapshot is a belt-and-suspenders you rarely draw on.

## 5. Single source of truth for metric definitions - a shared `bsb-metrics` package

- **Friction removed:** Manual 3-surface (sometimes 5-surface) parity. three-surface-parity.md
  is an entire BLOCKING rule + a huge bug-history table precisely because gcOBA/xwOBA/wRC+/
  FramRAA/Depth are re-implemented per surface and drift. That rule is a symptom of no SSOT.
- **External pattern:** Semantic-layer / metrics-as-code single source of truth. The purest
  version is the dbt Semantic Layer (define a metric once, served everywhere) - see getdbt.com.
  For US, the grounded version is NOT dbt (see skeptic): a plain internal Python package with
  ONE canonical function per metric (the SQL string builder + the aggregation/rollup logic),
  imported by all surfaces. The reference-impl-index rule already NAMES the canonical impl per
  metric; this promotes that index into importable code.
- **Fit:** Python package, importable by every worktree app and every pin CLI. No IT, no DB
  write. dbt-core + dbt-sqlserver COULD materialize DB-side views but needs write access to
  SQL Server (blocked) and does not run inside a Connect Streamlit app, so it is out for now.
- **Effort:** L. Migrating each metric off 3 copies onto one import is real work, done metric
  by metric.
- **Risk:** Medium. A shared package across 4 worktrees needs a distribution mechanism (see
  idea 9); a bug in the shared fn now hits all surfaces at once (that is also the point).
- **Payoff:** High and compounding. Every future metric ships once, not three times; the
  parity bug-history table stops growing. Also the prerequisite for a clean operate->assemble
  cutover (idea 10).
- **Skeptic:** dbt Semantic Layer proper is overkill and mis-fitted (needs DB write + a
  serving gateway our Connect apps cannot call). The Python-package version is "just good
  factoring" dressed as a pattern - and the per-surface differences that are INTENTIONAL
  (date cutoffs, multi-level SQL vs Python rollup) mean the shared fn needs careful
  parameterization, not a blind merge. High effort, slow payback.

## 6. Model manifest + backtest scorecard + champion/challenger log (small-sample sports models)

- **Friction removed:** Promote/release models FIT-AT-SCORE-TIME with no registry, no
  versioning, no drift/calibration tracking; validation is ad-hoc scripts (MEMORY confirms
  the v3-vs-v4 bake-off was a manual OOF comparison). No record of which model version scored
  which player when.
- **External pattern:** Model registry + champion-challenger + backtest monitoring. Full
  tool = MLflow; the file-based `mlflow-skinny` (no server, no DB, artifacts to a local dir)
  is the constrained fit and can log to a joblib pin. The grounded minimum is a home-grown
  "model manifest": a versioned joblib {fitted_model, train_date, feature_list, OOF scores by
  cohort, calibration curve, git_sha} pinned under an immutable name, plus a running
  scorecard pin that appends each period's realized-vs-projected.
- **Fit:** mlflow-skinny is pip-installable and file/pin-backed; but the model-REGISTRY
  feature specifically wants a DB-backed store (blocked). So use skinny for TRACKING/logging
  only, or skip it and hand-roll the manifest. All Connect-native.
- **Effort:** M (manifest + scorecard); L if adopting mlflow-skinny end to end.
- **Risk:** Low-medium. Low deploy cadence means light governance is enough.
- **Payoff:** Medium-high. Turns "fit at score time, trust the script" into a versioned,
  backtested, calibration-tracked artifact - matches the "projected not definitive" standard
  and lets you defend a model to the Farm Director.
- **Skeptic:** These are small-sample seasonal models retrained rarely. Full MLflow is
  cannon-for-a-sparrow; the honest win is just the manifest + a backtest log, not a registry.
  Drift monitoring on a model refit each score is semantically odd - track CALIBRATION and
  realized-vs-projected, not classic feature drift.

## 7. pytest-mpl image-regression to back the render-and-look rule

- **Friction removed:** Visuals ship wrong and are caught only by a discipline rule
  (render-and-look.md exists because compile+unit tests are blind to layout; the stray-P-
  under-the-logo cost two round-trips).
- **External pattern:** Matplotlib image-regression testing (pytest-mpl): store a baseline
  PNG, fail CI when a render diffs beyond tolerance. Renders with SYNTHETIC data at production
  dpi - exactly what the rule already prescribes manually.
- **Fit:** Pure Python, runs on the personal laptop and in GH Actions, no DB. Slots into idea 3's
  CI.
- **Effort:** S (baseline the key figures; wire the check).
- **Risk:** Low-medium. Baselines need regenerating on intentional visual changes (noise if
  over-applied); font/backend differences can cause flaky diffs.
- **Payoff:** Medium. Catches REGRESSIONS automatically (a chart that used to be fine and
  broke). Does not catch "wrong" on a brand-new visual - human eyes still gate novelty, as
  the rule says.
- **Skeptic:** render-and-look already forces a human to look. Image-regression only adds
  value for UNCHANGED visuals that silently break; if visuals churn a lot, baseline
  maintenance may cost more than it saves.

## 8. Reproducible pin builds - parameterized job + input manifest (papermill-style)

- **Friction removed:** Pin builds are multi-hour, laptop-network-fragile (tracker §11.1),
  and their exact inputs/params are not recorded. Re-pin discipline (§5.13, §7) is entirely
  tribal knowledge in the rules file.
- **External pattern:** Parameterized, reproducible notebook/script execution (papermill) +
  an input manifest. Each pin build records params (year, levels, sched_types, git SHA) and
  emits a run log artifact; re-runs are one command with recorded params.
- **Fit:** Connect already runs the daily refresh as a scheduled job; papermill or a plain
  parameterized `__main__` both work. No IT.
- **Effort:** S-M.
- **Risk:** Low.
- **Payoff:** Medium. Makes "which params built this" answerable and re-pins one-command
  instead of runbook-recall. Overlaps idea 4's provenance stamp.
- **Skeptic:** The pin CLIs are already parameterized argparse scripts; papermill adds a
  notebook layer you may not want. The real value is the input manifest (cheap), not the
  notebook engine.

## 9. Kill worktree copy-drift - a distributed `bsb-common` package (rules, slack_channels.csv, helpers)

- **Friction removed:** Rules synced BY HAND across 4 worktrees (slack-channels-sync.md notes
  the CSV lives in 5 places; `/sync-rules` is a manual crutch). Copy-drift is a standing risk.
- **External pattern:** Shared internal library vs monorepo. Options: a pip-installable
  internal package, a git submodule, or git subtree for the shared `.claude/rules` + data +
  common Python helpers.
- **Fit:** Works with the current 4-worktree layout; no IT. A submodule for `rules/` +
  `slack_channels.csv` is the lowest-lift.
- **Effort:** M.
- **Risk:** Medium. Submodules add checkout friction; the work laptop must also learn the
  new layout; per-worktree feature-branch model complicates a shared dependency.
- **Payoff:** Medium. Removes a manual sync chore and a drift class.
- **Skeptic:** The worktrees already share ONE git history and `/sync-rules` exists. This is
  convenience, not a bug-killer, and submodules are famously irritating. Lower priority than
  the data-integrity items.

## 10. Strangler-fig cutover for operate->assemble (live apps -> unified PD hub)

- **Friction removed:** dual-track-operate-vs-assemble.md describes two parallel builds with
  NO clean migration mechanism and an explicit "no big-bang cutover" rule - but no positive
  pattern for HOW to retire a live app domain into the hub.
- **External pattern:** Strangler fig - the new hub wraps and incrementally replaces the old
  apps one domain at a time, routing each domain to the hub only once proven, old app retired
  after. This is literally the rule's stated intent; naming the pattern gives it a mechanism.
- **What makes it clean:** If the hub IMPORTS the shared `bsb-metrics` package (idea 5) rather
  than re-porting each metric, "assemble" becomes wiring a UI over already-canonical logic, not
  re-implementing and re-verifying. Strangler-fig + SSOT is the migration engine.
- **Fit:** Both repos are Connect Streamlit; the hub can consume the same pins the live apps do.
- **Effort:** L (ongoing, by design - no deadline per the rule).
- **Risk:** Medium. The whole point is to avoid disruption; done wrong it dual-maintains.
- **Payoff:** High long-term; near-zero this month.
- **Skeptic:** Mid-season this is explicitly NOT to be forced. It is a direction, not a
  now-task; only worth pitching as "adopt idea 5 first so the eventual cutover is cheap."

## 11. Local DuckDB/SQLite fixture snapshot - real dev-DB parity on the personal laptop

- **Friction removed:** Deepest cut at pain point 2 - the personal laptop cannot touch data
  AT ALL. A committed, anonymized/synthetic columnar snapshot (DuckDB reads parquet natively,
  is already used in the repo) would let Claude Code actually RUN data-dependent code locally.
- **External pattern:** Local analytical replica for offline dev (DuckDB-over-parquet).
- **Fit:** DuckDB is present (the fielding pilot used it); no IT for a synthetic fixture.
- **Effort:** M.
- **Risk:** HIGH on governance - any REAL player data landing on the personal laptop / GitHub
  is a hard no. Must be synthetic or irreversibly anonymized, which limits realism.
- **Payoff:** High IF governance allows; otherwise collapses into idea 3's synthetic fixtures.
- **Skeptic:** The governance wall likely forces synthetic data anyway, at which point this is
  just idea 3 with a heavier engine. Do idea 3 first; only build this if a real-shape anonymized
  extract is ever sanctioned.

---

## Top 3 I would pitch to Zac first

1. **`safe_pin_write()` guard wrapper (idea 1).** Best payoff-to-effort on the board. A few
   hundred lines of pure Python, no IT, and it retires three documented bug classes at once
   (the dtype triad, the mass-wipe, sparse pins) by validating a pandera contract + shrink
   floor + version-CAS + provenance stamp on every write. Ship it as the standard entry point,
   adopt writer by writer.

2. **Shard the PRP + goals pins per-player (idea 2).** The whole-pin RMW is the root cause of
   the most severe, most REPEATED, coach-visible incident (data vanishing). Sharding makes the
   blast radius structurally one player. First, spend one email asking IT for a single writable
   table (the actual real fix); if denied, shard - it is the best no-IT option.

3. **Golden-fixture synthetic-data CI (idea 3).** Attacks the laptop-split tax where it hurts:
   it lets the personal laptop (where Claude Code lives) verify aggregation, org-code, parity,
   and dtype LOGIC before anything reaches the work laptop, shrinking the verification-backlog.
   You already have the harness DNA (`--check-p95`, goal-parser golden-diff) - generalize it.

Honorable mention to promote next: the **shared `bsb-metrics` package (idea 5)** - highest
compounding payoff (kills the 3-surface parity tax and unlocks a clean operate->assemble
strangler cutover) but it is L effort, so stage it after the three quick integrity wins land.

---

## Sources

- MLflow lightweight/file-based tracking + `mlflow-skinny`: https://mlflow.org/docs/latest/ml/model-registry/ , https://mlflow.org/docs/latest/tracking.html
- dbt Semantic Layer (metrics-as-code single source of truth) + dbt-sqlserver: https://www.getdbt.com/product/semantic-layer , https://docs.getdbt.com/docs/use-dbt-semantic-layer/dbt-sl
- pandera (pandas dataframe schema contracts): https://pandera.readthedocs.io
- pytest-mpl (matplotlib image-regression): https://github.com/matplotlib/pytest-mpl
- papermill (parameterized reproducible notebooks): https://papermill.readthedocs.io
- DuckDB (local analytical engine over parquet): https://duckdb.org
- Strangler-fig migration pattern (Fowler): https://martinfowler.com/bliki/StranglerFigApplication.html
- Event sourcing / append-only log (Fowler): https://martinfowler.com/eaaDev/EventSourcing.html
