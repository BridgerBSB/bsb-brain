# Connect Offload + New Repo — Migration Preface (NOW, not future)

**Date:** 2026-06-12
**Status:** PREFACE / PLAN — driver is live (IT/Catherine Fields server-load review).
**New official home:** https://github.com/Baseball-Operations/player-development
  (under the Baseball Operations umbrella — R&D-visible, DB-architecture-aligned)
**Relationship to the hub:** This is the **data-layer** prerequisite to the
unified PD Hub (`2026-06-12-unified-pd-hub-design.md`). The HUB (UI consolidation)
is a future move. The CODE MIGRATION described here is **not** future — it's
the response to active IT pressure and the reason the new repo exists.

---

## 1. The driver (Catherine Fields / IT, 2026-06-12 thread)

IT's RConnect (Posit Connect) review flagged PD processes consuming excessive
server resources — at times **100% CPU/RAM** — and noted the **pin tracker jobs
running throughout the day despite being scheduled for off-hours.** Core points:

- RConnect is designed for **visualization, not large-scale data processing.**
- The heaviest offenders are the processes acting as **data pipelines** —
  querying the DB and outputting aggregated/modeled data (i.e. our tracker pins).
- Tuning the Python is unlikely to fix it — the bottleneck is **architectural**
  (heavy aggregation on a viz server), not code efficiency.
- R&D will reach out to help with the Python.
- Catherine's suggested path: lean on GC2, which **already** serves org-level
  pages (e.g. `/orgs/HIT`) backed by `_view` tables / stored procs — have R&D
  add a column or a `_view`/stored proc there so we **read pre-computed results**
  instead of recomputing on Connect.
- Also: work with coaches/coordinators to decide **daily vs weekly** necessity,
  to scale back compute.

**Zac's agreed position (in-thread):** the tracker pins are heavy because they
compute **league-wide aggregations + percentile rankings across all 30 orgs and
every level** — genuinely data processing. The sustainable fix is to **move that
aggregation into the database** (scheduled SQL job / materialized tables) so the
apps simply read pre-computed results — which both unloads Connect AND makes the
apps faster. This is exactly where R&D help fits.

> This was ALREADY the documented long-term direction before IT asked:
> `rules/tracker-parquet-pins.md §11.2 Step 3` — "DB-side materialized table …
> the right architecture for the 5-year horizon … all apps query the
> materialized table directly — no per-app pin layer for current year."

---

## 2. The "running during the day" diagnosis (to confirm with IT)

Likely causes, in priority order:

1. **6-hour pin refresh cadence.** Connect-scheduled tracker refreshes run
   **~4×/day** (per `tracker-parquet-pins.md §12.10`). On a 6h cadence two of
   those four fire near **midday and early evening — peak hours.** This alone
   explains daytime CPU spikes that look like "running off-schedule."
   → **Quick win:** reschedule to genuinely off-hours (e.g. 1× overnight) OR
   drop current-year refresh to once/twice daily off-peak, until the DB-side
   move lands.
2. **Fielding combo precompute** — the single heaviest job (~132 min on Connect,
   content 909; see `memory/fielding-tracker-perf-session.md`). Pooled-percentile
   combos. Prime candidate to move DB-side first.
3. **Manual daily report runs** 8:30–9am (3 `.py` scripts, gated on video/IZ
   ingest finishing ~8:30) — business hours by necessity.
4. **Monday weekly cascade** (Azure webhook → Slack) — heavy but weekly.
5. **TCP-retry churn** on VPN drops re-running queries (`database-tcp-retry.md`)
   could extend job wall-clock into the day.

→ **Action:** pull the actual Connect job history + schedules per content item
and confirm which of the above IT is seeing. Don't guess in the meeting — bring
the schedule table.

---

## 3. What moves, and where (the migration map)

**Principle:** apps become **pure readers.** All league-wide aggregation +
percentile pooling moves to the **database** (SQL Server Agent jobs writing
materialized tables / `_view` / stored procs), refreshed overnight. Apps read
those — directly, or via a thin pin that's now cheap because it's a SELECT, not
a 30-org compute.

| Heavy Connect job today | Target |
|---|---|
| 5 affiliate tracker pins (hitter / pitcher / OF / IF / BR / catcher) — 30-org × all-level aggregates + percentiles | **DB materialized tables / stored procs** (R&D + GC2 alignment). App reads results. |
| Fielding combo precompute (pooled-percentile combos, ~132 min) | **DB-side** first — biggest single win |
| Defense Matrix pin / Compliance pin | DB `_view` or stored proc, read on demand |
| Daily postgame/report `.py` (8:30–9am) | Keep on Connect/laptop for now (per-game, not league-wide) — review necessity w/ coaches |
| Org-level stats overlapping GC2 `/orgs/*` | **Reuse GC2** — have R&D add the missing columns to existing `_view`/proc rather than recompute |

**Where GC2 already overlaps:** Catherine's `/orgs/HIT` example. Before
rebuilding any org-level aggregate DB-side, check whether GC2 already exposes it
(or can with an added column) — that's the fastest R&D path and avoids
duplicate sources of truth. Watch for the parity rules
(`three-surface-parity.md`, `org-codes.md`) so GC2's numbers match ours.

---

## 4. The new repo — `Baseball-Operations/player-development`

- Official home under Baseball Ops → R&D-visible, expected to align with DB
  architecture (the whole point of the move).
- **Target for:** the unified PD Hub (future) AND the migrated, DB-backed data
  layer (now). i.e. the place where "apps read pre-computed DB results" lives.
- **Open questions to resolve before moving code:**
  1. **Monorepo vs per-app?** Does the new repo hold all 4 apps + the hub shell,
     or just the hub + shared data layer while the 4 apps stay in their worktrees
     for now? (Leans monorepo given the hub end-state is a single shell — but
     confirm with R&D's conventions.)
  2. **Branch/worktree model** — current setup is one worktree per app per
     feature branch. The new repo likely wants `main` + PR flow (R&D norms),
     which conflicts with the current "merge to main only at milestones" habit.
  3. **What migrates first?** Recommend: the **shared data-layer** (database.py,
     pins_config, roster, the aggregation SQL) — because that's what R&D
     restructures DB-side. The UI follows once the read-layer is stable.
  4. **Secrets/deploy** — CONNECT_API_KEY, DB creds, Logic App URL move to the
     new repo's deploy story; coordinate with IT/R&D.

> ACTION: inspect the new repo's current state (is it empty? does it have a
> structure/README R&D expects?) before deciding monorepo layout.

---

## 5. Sequencing (how the two efforts interleave)

```
NOW  ── Connect offload (this doc) ───────────────────────────────┐
        1. Bring schedule table to IT/R&D meeting; reschedule 6h→  │
           off-peak as the immediate relief.                       │
        2. With R&D, move heaviest aggregation DB-side             │
           (fielding combos first, then the 5 tracker pools).      │  data layer
        3. Reuse GC2 _view/procs where org stats already exist.    │  stabilizes
        4. Apps repointed to read DB results (thin/no pin).        │
                                                                   ▼
FUTURE ─ Unified PD Hub (the other doc) ───────────────────────────
        Built on the now-stable, DB-backed read layer, in the new
        Baseball-Operations/player-development repo.
```

The migration makes the hub *easier*: once the read-layer is "SELECT from a
DB-computed table," the hub's pin-first load-speed strategy gets even simpler
and Connect stops being the bottleneck for either effort.

---

## 6. Immediate next actions (no code yet — preface only)
1. **Pull the Connect schedule + job-duration table** per content item → confirm
   the daytime-run cause (almost certainly the 6h cadence hitting noon/6pm).
2. **Reschedule the 6h tracker refreshes to off-peak** as immediate relief —
   reversible, no architecture change, buys goodwill before the R&D meeting.
3. **Inventory the heaviest jobs** by wall-clock (fielding combo precompute is #1)
   to prioritize the DB-side move.
4. **Inspect `Baseball-Operations/player-development`** current state → decide
   monorepo vs hub-only layout.
5. **Prep the R&D ask:** which aggregations to materialize DB-side, which already
   exist in GC2 `/orgs/*`, and the parity guardrails (`three-surface-parity.md`,
   `org-codes.md`).

---

## 7. What NOT to do
- Don't frame this to IT as "tune the Python" — the bottleneck is architectural
  (heavy aggregation on a viz server). Zac already said this correctly in-thread.
- Don't rebuild org stats DB-side that **GC2 already serves** — reuse/extend the
  existing `_view`/proc (Catherine's point); avoid a duplicate source of truth.
- Don't move the heavy aggregation into the hub app — the hub must stay a READER.
- Don't migrate UI before the read-layer is stable (data layer first, §5).
- Don't lose the parity guardrails when GC2 becomes a source — its org numbers
  must reconcile with ours (`three-surface-parity.md`, `org-codes.md`).
- Don't drop the off-peak reschedule "quick win" while waiting on R&D — it's the
  cheapest immediate relief for the actual complaint.

---

## 8. Cross-references
- `2026-06-12-unified-pd-hub-design.md` — the future hub this prefaces.
- `rules/tracker-parquet-pins.md` §11 (3-step ladder) + §11.2 Step 3 (DB-side
  materialized table = the documented long-term target) + §12 (Connect schedule).
- `memory/fielding-tracker-perf-session.md` — the heaviest job (combo precompute).
- `rules/three-surface-parity.md`, `rules/org-codes.md` — parity guardrails if
  GC2 org pages become a source.
- `rules/database-tcp-retry.md` — VPN-drop retry behavior (job wall-clock).
