# Last session state — 2026-07-24 (Intangibles Individual position radio + two org/position bug sweeps)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` · branch `feature/astros-intangibles` (rules on `bsb-resources/feature/pd-goals`)
- **What we were doing:** Added the OF/IF Individual position radio Zac asked for, which surfaced two latent bugs — both fixed and swept everywhere.

- **Shipped this session (all committed, pushed, and DEPLOYED by Zac):**
  - **OF/IF Individual position radio** (All/LF/CF/RF, All/3B/SS/2B/1B) + events-frame caching + on-demand "Build Report" PDF + 6h per-position percentile pools (pinned tracking + live PAA/value). `cd15a670`→`c769a325`.
  - **Range & Difficulty page removed** from weekly OF + IF PDFs. `48d517f7`, `c3d83639`.
  - **Players_Games position fan-out fix** — `fielding_base.drop_phantom_pos_rows()` (keyed on player+sched+event), applied in of/if_weekly_data + of/if_postgame_data. Cam Smith 169165, 2026-07-12 CF+RF: 33 rows→26. `47122c7a`, `df1cc558`, `40796c0d`. New rule `players-games-position-fanout.md` (`8d134e12`,`55cc1167`).
  - **Trends-tab mid-season acquisition fix (rule #17)** on **all 5 affiliate trackers** via `_names_hou_pref`: Arm Farm `3a4bedf4`, Barrelsville `b2352c2f`, Catcher/Fielder/BR `647591c1`. Rule #17 updated with the player-identity-vs-org-identity distinction. `31d59604`. Jack Dashwood 73573.
  - Both rules propagated byte-identical to all 4 worktrees.

- **EXACT next step:** Nothing blocking — session is closed. If resuming optional cleanup, start with the 3 unguarded diagnostic scripts (`error_diagnostic.py:63`, `diag_dsl_if_scope.py:43`, `diagnose_tier1_gate.py:121`) — apply `drop_phantom_pos_rows` or gate them.
- **Blockers / waiting on:** none. All deployed.
- **Uncommitted work:** intangibles src/pages clean (0); only synced `.claude/rules/*.md` copies + pre-existing unrelated user WIP in bsb-resources.

---

## ALSO OPEN — EOY P13 Fielding (bsb-resources/feature/pd-goals, from 2026-07-21, preserved)

# Last session state - 2026-07-21 (EOY P13 "Fielding Season Review": page + backend)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` * branch `feature/pd-goals`
- **What we were doing:** Building the FIELDING half of the EOY position-player
  report, page by page with Zac. P13 went idea -> mock -> in-module page -> real
  data layer in one session.

- **Shipped this session (all committed + pushed to `feature/pd-goals`):**
  - **P13 page** in `pd-goals/src/eoy_position_report.py`
    (`draw_page13_fielding_usage`, `_PAGE_REGISTRY` entry 13, synthetic payload in
    `_synthetic_payload()`). Diamond of **8-sector PAA/EO direction roses**
    (UNIFORM size; centres show usage % totalling **exactly 100** via
    largest-remainder `_usage_shares_to_100`), per-position PAA/EO + OAA table,
    catching strip with **NetK / BlockRAA / AugPop2B**, and a catcher **NetK
    4-quadrant square straddling the zone edge**.
  - **P13 backend** `pd-goals/src/eoy_fielding_data.py::build_page13` - thin layer
    over `paa_eo_matrix_data` + canonical catcher SQL, recomputes nothing. Wired
    into `eoy_data.build_position_payload` (OUTSIDE the `bip_df` guard).
  - `pd-goals/scripts/test_eoy_page13_shape.py` - 20 offline checks, ALL PASS
    (monkeypatched `run_query`, no DB). Includes a `_DIR8` cross-module contract
    check (report stores tuples, data layer stores strings - drift would rotate
    every wedge silently).
  - **P1 cover** split into two boxes (HITTING | FIELDING / BR) + new
    `--summary-fielding` CLI flag. **P2** -> "Hitting Season Review",
    **P12** -> "Hitting Glossary", **P13** -> "Fielding Season Review".
  - **`.claude/rules/player-facing-voice.md`** (BLOCKING, NEW) - EOY/PRP copy is
    SECOND PERSON (you/your), never he/his, glossary included.
  - Fixed `eoy_hitting_percentiles.py` missing from `manifest.json` (would have
    degraded P2 percentile coloring silently on Connect).
  - Spec: `pd-goals/docs/plans/2026-07-20-eoy-fielding-half-spec.md`.
    Renders: `pd-goals/docs/plans/mocks/eoy-fielding/`.

- **EXACT next step:** Zac's words: *"continue building out the fielding (IF, OF, C
  tools) next session - i have an idea what these will look like in 1-2 pages per
  each."* So **ASK Zac for his 1-2-page-per-tool concept for IF / OF / Catcher
  FIRST, then mock.** Before mocking, resolve the still-PARKED structural question:
  does a multi-position-FAMILY player get metric pages repeated per family, the
  whole block cloned, or primary family only? It decides page counts. Also open:
  P14 metric list (each surviving metric costs a directional pool build) and the
  games-vs-innings schema check on `Astros.Players_Games`.

- **Blockers / waiting on:** **WORK LAPTOP.** Every P13 query is written against
  canonical patterns but has **NEVER EXECUTED** (no DB on the personal laptop).
  Run from `pd-goals/`:
  `python scripts/test_eoy_page13_shape.py` (offline, expect 20 PASS), then
  `python scripts/generate_eoy_position.py --gcid 218498 --season 2026` (Schiavone).
  Watch the `[EOY] real-data pages built:` line for `page13`; if absent, the WARNING
  above it is the reason. **Schiavone is NOT a catcher** - run a real catcher gcid
  too, the catching half is the least-proven code. The direction pool query is the
  slow-query / pin candidate.

- **Uncommitted work:** 85 pre-existing untracked/modified files, unrelated to this
  session. All session work committed + pushed.

- **Flagged / undurable:** `sync-rules.sh` HUNG (killed at 2 min), so
  `player-facing-voice.md` is **not yet copied to the 3 sibling worktrees** - run
  `/sync-rules` next session (matters once the EOY pitcher report is built in
  `bsb-wt-bullpen`). MEMORY.md is ~20KB vs the hook's 17.1KB target.
