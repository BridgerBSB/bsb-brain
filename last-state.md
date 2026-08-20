# Last session state - 2026-08-20 14:09 (IT-facing DB documentation: two docs shipped, NOT yet sent)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `9b50` - domain `bsb-resources/feature/pd-goals` - id `07cfc75f0511de34`. Ring buffer 3/10.
- **What we were doing:** IT asked for documentation of what runs slowly on the visualization server and why the PD apps precompute everything. Read the pin/tracker code across all four worktrees and built two handoff documents (MD + PDF): the "why is it slow" half with code, and the "what runs" half with cadences.
- **Shipped this session:** `56da3b74` (doc 1, 16pp, ten operation shapes, 18 `path:line` citations + 15 verbatim code blocks) - `1df645ed` (reframe for IT-as-requester + lead with Zac's 97% screenshot) - `f6d36432` (doc 2, 7pp job view, written FRESH with no names; also scrubbed the departed IT contact from `CLAUDE.md`) - `6fa815b8` (LINEAGE). Renderer `pd-goals/scripts/_render_cost_inventory_pdf.py`: markdown -> styled HTML -> headless Edge `--print-to-pdf`, no pandoc/LaTeX, takes a path, does both by default. Every page rendered and read back.
- **EXACT next step:** Port `AC_TIMING` to the other three apps. Copy the ~6-line timer block from `intangibles/src/database.py:123-137` into `barrelsville/src/database.py`, `bullpen-report/src/database.py`, `pd-goals/src/database.py` - each has a `run_query`, none has AC_TIMING. Then on the WORK LAPTOP run each pin once with `$env:AC_TIMING = "1"` and capture the log. That converts most DERIVED tags in doc 1 into MEASURED with per-query attribution. No schema change, no new access. Then re-run the renderer (does both docs) and re-send.
- **Blockers / waiting on:** Nothing blocking. Docs are committed + pushed but **NOT yet handed to IT** - Zac's call on whether to retitle doc 1 first.
- **Uncommitted work:** 74 paths, all pre-existing untracked clutter from other threads. Everything this session is committed and pushed.

### Worth keeping

1. **The headline number came from Zac, not from me.** His screenshot of the postgame card's OWN load-time panel (`bullpen-report/src/postgame_v2_view.py:446`): cold build **150.33s, `get_level_percentiles` 146.13s = 97.22%**. Next entry 0.949s; everything that is not percentiles totals under 3s. It lands because it is the app's own instrumentation, not a benchmark we constructed. Traced to `bullpen-report/src/postgame_percentiles.py:1450`.

2. **We have exactly FIVE measured numbers and the doc says so.** The other pair carries the mechanism: `monthly_fielders` ONE base slice **8203s (2h17m)** vs season `fielders` **126s**, same run, same table, same 9 metrics - **65x for adding one partition column**. That is the cost of non-additive aggregation on our own data. Everything else is DERIVED from source and tagged as such. Nothing is estimated.

3. **`_RAW_TDM_QUERY` (`intangibles/src/fielding_tracker_data.py:2015`) IS ALREADY THE FACT TABLE.** One row per (fielder, event), every metric, every dimension (org/level/season/pos/ha_split), ~6 min to build. All 95 `PERCENTILE_CONT` expressions elsewhere in that file are a groupby-quantile over that frame. We do not need to invent a grain.

4. **The design question is additive vs non-additive.** Counts and sums roll up; per-entity quantiles do not - the pooled P95 across two levels is not any function of the two per-level P95s (the Nunez arm case: weighted-mean 85.9 vs true pooled 87.5). That is why 120 combos exist. Two ways through: materialise the fact + a pooling proc, or columnstore + mergeable quantile sketches (t-digest). **Whether the platform supports sketches is the one open question we put to IT.**

5. **The instrument is already written and switched off.** `intangibles/src/database.py:112` has a per-query timer behind `AC_TIMING=1`. The other three apps have ZERO occurrences. Every pin script already prints per-slice wall-clock + row count. The measurement harness is ~80% built and has never been turned on for a full pin run.

6. **Wrote doc 2 fresh rather than scrubbing the July one.** The July R&D inventory names a person, a vendor, and another team in its first 60 lines. A scrub leaves the framing of a doc written for a different audience, and one missed line is a departed colleague's name in something that leaves the building. Also found `CLAUDE.md` still listed an IT contact who has LEFT - that file auto-loads every session, which is exactly the mechanism.

### Standing rule from this session (Zac, verbatim)

> *"we shoudlnt referneec any peoipkle or anything becasue josephy left teh comapnyt ... and im not telling u any more names cuz u randomly refernece them"*

**No names but Zac in any outgoing artifact. Sweep before every handoff.** `pd-goals/docs/plans/2026-07-28-rd-heavy-compute-inventory.md` is INTERNAL ONLY - do not send it, do not quote it to IT, do not cite it in an IT-facing doc.

### Open, Zac's call (not blocking)

- **Doc 1 title.** "SQL Server Cost Inventory" is accurate but slightly ask-flavoured. If IT's own words were closer to "what's slow in Posit and why do you pin", retitle to match. Offered, not answered.
- **The measure dictionary** (~60 metrics: grain, numerator, denominator, filter, agg fn, additive?, pool gate) does not exist and is named in doc 2 as work on OUR side. Spread across four 4000-6000 line files. It is the artifact that actually unblocks a design.
- **The one thing we asked IT for:** Query Store / `sys.dm_exec_query_stats` filtered to our login over ~7 days. Our timers measure wall-clock incl. network; theirs measure server CPU + IO. Neither side has both halves.

### Flagged, NOT yet durable (carried from 2026-08-19, survived two wraps - now genuinely top of queue)

The **rsconnect `--app-id`** lesson lives only in `pd-goals/injury_tracker/DEPLOY.md` + that app's `LINEAGE.md`. `rsconnect deploy` matched by `--title` does NOT identify existing content, so a deploy from a fresh clone silently creates a **second** app with an empty Vars tab - which presents as an SSPI/Kerberos DB error, not as a duplicate. Belongs in `.claude/rules/new-posit-app.md` + the 4-worktree sync. ~10 min.

### ALSO OPEN - Injury Tracker (paused by choice, not blocked)

Two club analyses shipped 2026-08-20 morning (`3565d92b`, `95a69646`, `ac2d4b05`) are **UNRUN vs the live DB** - `--list-parts` FIRST, then `--season 2026`. App not redeployed since `fb198582`. Zac: *"we are good on the injury stuff at the moment and will come back later with more."*
