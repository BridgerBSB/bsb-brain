# Combined Weekly KPI Stapler — Cross-Worktree PDF Merge Pattern (BLOCKING)

## What this rule covers

The 6 weekly KPI reports (Hitter, Pitcher, OF, IF, BR, Catcher) live in
3 different worktrees. Each generates per-level PDFs. Until Apr 28 2026,
each ALSO delivered its PDFs to the general affiliate channels
(`z1_sugar_land`, `z2_corpus_christi`, etc.) — meaning every Sunday
those channels got blasted with 6 PDFs in a row. That was the spam.

Apr 28 2026 fix: the affiliate-channel delivery moved out of the 6
individual scripts and into a single new "stapler" script in pd-goals
that runs after the 6 finish. It collects the 6 per-level PDFs from the
worktree output dirs, trims each one's individual title page, prepends
ONE combined cover page, and delivers a SINGLE combined PDF per level
to the affiliate channel.

Cross-worktree orchestration. Owns the affiliate-channel delivery for
the whole KPI weekly family. Future agents touching any of the 6 weekly
KPI scripts MUST NOT re-add affiliate-channel delivery to them.

---

## The two-stage delivery topology (BLOCKING)

```
                                  (each script lives in its own worktree)
┌─────────────────────────┐    ┌──────────────────────────────────┐
│  6 individual KPI       │───▶│  Per-domain Slack channels       │
│  scripts                │    │  (sugarland_barrelsville,        │
│  (run sequentially      │    │   sugarland_armfarm,             │
│   on Sunday, untouched  │    │   sugarland_intangibles, etc.)   │
│   by this pattern)      │    │  ← single PDF per script         │
└─────────────────────────┘    └──────────────────────────────────┘
            │
            │ writes 6 per-level PDFs to each
            │ worktree's output/ directory
            ▼
┌─────────────────────────┐    ┌──────────────────────────────────┐
│  Combined stapler       │───▶│  General affiliate channels      │
│  pd-goals/scripts/      │    │  (z1_sugar_land,                 │
│  generate_combined_     │    │   z2_corpus_christi, etc.)       │
│  kpi.py                 │    │  ← ONE combined PDF per level    │
│  (run AFTER the 6)      │    │  ← MLB → pd-automation-test      │
└─────────────────────────┘    └──────────────────────────────────┘
```

**Stage 1 — Per-domain delivery.** Each of the 6 scripts continues to
deliver its single PDF to its own per-domain channel. This is unchanged
and lives in the script (e.g., `barrelsville/scripts/generate_hitter_kpi_report.py`
delivers to `sugarland_barrelsville` for AAA, `corpus_barrelsville` for AA,
etc.). The `CHANNEL_IDS` dict in each script defines this routing.

**Stage 2 — Combined affiliate delivery.** AFTER the 6 finish, the
stapler runs once. It does not re-query DB, does not re-render any
report; it reads the PDFs the 6 scripts already wrote to disk, trims
their first page, staples them with `pypdf`, and POSTs ONE combined PDF
per level to the affiliate-channel map below.

---

## Affiliate channel routing (canonical, owned by the stapler)

| Level | Combined PDF goes to | Channel name |
|---|---|---|
| `mlb` | `C0ABHSF6SCA` | pd-automation-test (overflow) |
| `aaa` | `GFYF1JQR1` | z1_sugar_land |
| `aax` | `CFXS0BMLG` | z2_corpus_christi |
| `afa` | `GFYF4K3GB` | z3_asheville |
| `afx` | `GFYJ94D2N` | z4_fayetteville |
| `rok` | `C0516HKL6KX` | wpb_complex (FCL) |
| `dsl` | `CFZLA3W2K` | z8_dominican_academy |

This map lives ONLY in `pd-goals/scripts/generate_combined_kpi.py`. Do
not duplicate it in any of the 6 individual scripts — they have no
business knowing about affiliate channels.

**MLB and DSL get combined deliveries.** Pre-Apr-28 the 6 individual
scripts excluded MLB and DSL from affiliate sends entirely (the old
`AFFILIATE_CHANNEL_IDS` dict had a `# DSL and MLB: no affiliate channel
send` comment). The combined stapler INCLUDES them — MLB goes to the
overflow test channel, DSL goes to the new dedicated Dominican Academy
channel.

---

## Worktree layout assumption

The stapler resolves source PDFs by walking up to a shared parent dir
where the four worktrees are siblings:

```
C:\Users\<user>\
  ├─ bsb-resources\         # main repo, feature/pd-goals, hosts the stapler
  │  └─ pd-goals\
  │     ├─ scripts\generate_combined_kpi.py   ← THE STAPLER
  │     ├─ assets\*.png                        ← logos for combined cover
  │     └─ output\                             ← combined PDFs land here
  ├─ bsb-wt-hitting\         # feature/barrelsville
  │  └─ barrelsville\output\Hitter_KPI_<level>_<date>.pdf
  ├─ bsb-wt-bullpen\         # feature/bullpen-reports
  │  └─ bullpen-report\output\Pitcher_KPI_<level>_<date>.pdf
  └─ bsb-wt-intangibles\     # feature/astros-intangibles
     └─ astros-intangibles\intangibles\output\
        ├─ OF_KPI_<level>_<date>.pdf
        ├─ IF_KPI_<level>_<date>.pdf
        ├─ BR_KPI_<level>_<date>.pdf
        └─ C_KPI_<level>_<date>.pdf
```

The stapler resolves the root via `Path(__file__).resolve().parent.parent.parent.parent`
(four levels up from the script). Override with the `BSB_WORKTREE_ROOT`
env var if the worktree layout changes (e.g., different machine, custom
checkout location).

### Intangibles dual-layout (BLOCKING — May 4 2026 fix)

The Intangibles worktree exists in TWO known layouts depending on the
machine:

| Machine | Path |
|---|---|
| Personal laptop (`C:\Users\Owner\`) | `bsb-wt-intangibles/astros-intangibles/intangibles/output/` |
| Work laptop (`C:\Users\zbridger\`) | `bsb-wt-intangibles/intangibles/output/` (no middle dir) |

The stapler runtime-detects which exists at module load time:

```python
_INTANGIBLES_NESTED = _WORKTREE_ROOT / "bsb-wt-intangibles" / "astros-intangibles" / "intangibles" / "output"
_INTANGIBLES_FLAT = _WORKTREE_ROOT / "bsb-wt-intangibles" / "intangibles" / "output"
_INTANGIBLES_OUTPUT = _INTANGIBLES_NESTED if _INTANGIBLES_NESTED.exists() else _INTANGIBLES_FLAT
```

**Symptom of getting this wrong:** combined PDFs ship with only Hitter +
Pitcher (2 of 6 domains). All 4 Intangibles domains (Outfield, Infield,
Baserunning, Catcher) log `[SKIP] not found at <path>` because the
hardcoded path doesn't exist on that machine. Caught May 4 2026 on first
real work-laptop run.

**Don't hardcode either layout.** Both must remain valid. Hitting + Arm
Farm worktrees use the same shape on both machines (`bsb-wt-hitting/barrelsville/`,
`bsb-wt-bullpen/bullpen-report/`) so they need no detection.

---

## Stitch logic (BLOCKING — keep these invariants)

1. **Iterate REPORT_SOURCES in order.** Hitter, Pitcher, Outfield,
   Infield, Baserunning, Catcher. Combined PDF page order matches.
2. **Skip missing source PDFs gracefully.** If a level didn't generate
   a particular domain (e.g., catcher KPI for DSL didn't run that
   week), the stapler logs `[SKIP] Catcher: not found at ...` and
   continues. A combined PDF with 5 of 6 reports is still valid.
3. **If ALL 6 sources missing for a level, skip the level entirely.**
   No empty cover page. The stapler returns None and the level is
   omitted from the run.
4. **Drop page 1 of each domain PDF.** Each KPI report has a
   `_draw_level_cover_page()` that renders a single title page
   (page 1) followed by the actual content (pages 2+). The stapler
   uses `reader.pages[1:]` to skip page 1. If a report happens to be
   1 page only, the stapler appends all of it (defensive — see
   `[WARN]` log) instead of producing an empty section.
5. **One combined cover page on top.** Rendered with matplotlib's
   `PdfPages` to byte buffer, then read with `pypdf` and added as the
   first page of the combined PDF. Mirrors the existing per-report
   cover layout: affiliate logo centered, "Astros Weekly KPI Reports"
   in Astros navy bold, "<Affiliate> — <Level>" subtitle, "Week of
   YYYY-MM-DD", "<Year> Season". Adds an italic "Includes: <domain
   list>" line so the coach sees which reports were stitched in.
6. **Output filename: `Combined_KPI_<level>_<date>.pdf`.** Saved to
   `pd-goals/output/`. Don't change this name — Logic App delivery
   uses it as the Slack-displayed filename, and the format is the
   contract for downstream tools.

---

## CLI usage

```bash
# Default — generate all 7 levels, no Slack delivery
python pd-goals/scripts/generate_combined_kpi.py --end 2026-04-26

# Generate + deliver to affiliate channels
python pd-goals/scripts/generate_combined_kpi.py --end 2026-04-26 --deliver

# Single level (testing)
python pd-goals/scripts/generate_combined_kpi.py --end 2026-04-26 --level aaa --deliver

# Override season year (defaults to year of --end)
python pd-goals/scripts/generate_combined_kpi.py --end 2026-04-26 --season 2025 --deliver
```

`LOGIC_APP_URL` env var picked up automatically (matches all other CLI
deliveries — see `delivery.md`).

**Run order on Sunday:**

```bash
# 1) Run the 6 individual scripts (existing weekly workflow, untouched)
python barrelsville/scripts/generate_hitter_kpi_report.py    --end <date> --weeks 2 --deliver
python bullpen-report/scripts/generate_pitcher_kpi_report.py --end <date> --weeks 2 --deliver
python intangibles/scripts/generate_of_kpi_report.py         --end <date> --weeks 2 --deliver
python intangibles/scripts/generate_if_kpi_report.py         --end <date> --weeks 2 --deliver
python intangibles/scripts/generate_br_kpi_report.py         --end <date> --weeks 2 --deliver
python intangibles/scripts/generate_c_kpi_report.py          --end <date> --weeks 2 --deliver

# 2) Then the stapler — picks up the 6 PDFs, builds + delivers combined PDFs
python pd-goals/scripts/generate_combined_kpi.py --end <date> --deliver
```

Each of the 6 in step 1 sends to its per-domain channel only. Step 2
sends ONE combined PDF to each affiliate channel.

---

## What changed in each of the 6 KPI scripts (Apr 28 2026)

ALL SIX scripts had the same `AFFILIATE_CHANNEL_IDS` dict + a 4-line
delivery block immediately after the per-domain delivery. Both were
removed. The dict and block are now dead code that future agents must
NOT re-add.

| Script | Worktree | Branch | Commit |
|---|---|---|---|
| `barrelsville/scripts/generate_hitter_kpi_report.py` | `bsb-wt-hitting` | `feature/barrelsville` | `dd60173` |
| `bullpen-report/scripts/generate_pitcher_kpi_report.py` | `bsb-wt-bullpen` | `feature/bullpen-reports` | `498bb90` |
| `intangibles/scripts/generate_of_kpi_report.py` | `bsb-wt-intangibles` | `feature/astros-intangibles` | `0d1daae` |
| `intangibles/scripts/generate_if_kpi_report.py` | same | same | same commit |
| `intangibles/scripts/generate_br_kpi_report.py` | same | same | same commit |
| `intangibles/scripts/generate_c_kpi_report.py` | same | same | same commit |

Stapler itself: `pd-goals/scripts/generate_combined_kpi.py` (commit
`1851468` on `feature/pd-goals`).

Each modified script now has a comment in place of the deleted block:

```python
# Affiliate-channel delivery is owned by pd-goals/scripts/generate_combined_kpi.py
# (the combined-KPI stapler). This script only sends to the per-domain Barrelsville
# channels above. Run the combined script after all 6 weekly KPI runs finish.
```

That comment is a tripwire. If a future agent removes it AND re-adds
affiliate delivery, the spam comes back.

---

## Reference implementation

Read these in order when adding a new combined report (e.g., daily-tracker
combined, monthly snapshot combined):

1. **`pd-goals/scripts/generate_combined_kpi.py`** — the canonical
   stapler. Worktree-root resolution, REPORT_SOURCES table, cover page
   rendering, pypdf merge, Logic App delivery wrapper.
2. **`barrelsville/src/hitter_kpi_report.py::_draw_level_cover_page`**
   — the cover-page layout the stapler mirrors. Same fonts, same
   positioning, same logo placement.
3. **`pd-goals/assets/`** — affiliate logos used by the combined cover.
   Three exist: sugarland, corpus_christi, asheville, fayetteville.
   FCL/DSL/MLB fall back to `astros_logo.png`.
4. **`.claude/rules/delivery.md`** — Logic App payload shape (the
   `{"channel", "filename", "pdf"}` BLOCKING contract). The stapler's
   `_deliver_pdf` is copy-pasted from a working script, per the
   delivery.md anti-spam rule.

---

## What NOT to do

- **NEVER re-add `AFFILIATE_CHANNEL_IDS` or affiliate-channel delivery
  to any of the 6 individual KPI scripts.** That's how the spam comes
  back. The tripwire comment in each script is the last line of defense.
- **NEVER duplicate the channel map** in any worktree. The 7-level
  affiliate map lives ONLY in the stapler. Adding a copy to `bullpen-report/`
  or `intangibles/` is the same anti-pattern as the pre-Apr-28 state.
- **NEVER make the stapler re-query the database.** It's a thin
  PDF-merger; it reads what the 6 scripts already wrote to disk. If
  you need fresher data, re-run the source script(s), then re-run
  the stapler. Don't duplicate the report-generation logic.
- **NEVER hardcode the worktree root** as `C:/Users/Owner` or
  `C:/Users/zbridger`. Use the relative-from-script resolution
  (`Path(__file__).resolve().parent.parent.parent.parent`) so it works
  on every machine. Allow `BSB_WORKTREE_ROOT` env-var override.
- **NEVER deploy the stapler as Connect content.** It needs filesystem
  access to four worktrees that don't exist on Connect. CLI on the
  work laptop only. (Future: if a "scheduled combined PDF" need ever
  arises, the right answer is to make the 6 individual scripts deploy
  their PDFs to a shared pin first, then a Connect-deployed combiner
  reads the pin. Don't try to subprocess-spawn other apps from
  Connect.)
- **NEVER add affiliate channels to the per-domain `CHANNEL_IDS`
  dict** in any of the 6 scripts. CHANNEL_IDS is per-domain. The
  affiliate map is the stapler's responsibility, full stop.
- **NEVER drop more than page 1 from each source PDF.** Some KPI
  reports have multi-page content (overflow rosters, per-position
  pages). `reader.pages[1:]` keeps all of them. If a future report
  adds a multi-page front-matter (cover + ToC + content), you'll need
  to teach the stapler about a per-source `cover_pages_to_drop` count.
- **NEVER skip the combined cover page.** Even if there's only 1
  source PDF for a level (e.g., DSL with only catcher), the combined
  PDF still gets the unified cover. That's the user-facing branding.
- **NEVER post-process the combined PDF after stitching.** No
  watermarks, no annotations, no compression. Stitch and ship. Any
  styling change goes in the per-source generators or in the combined
  cover renderer.

---

## Bug history

- **Apr 28 2026** — Initial implementation. Boss request: stop spamming
  affiliate channels with 6 PDFs each weekly. Stapler shipped. DSL and
  MLB added to affiliate routing for the first time (DSL → new
  Dominican Academy channel `CFZLA3W2K`, MLB → overflow). E2E tested
  with 2 synthetic source PDFs locally; full work-laptop test deferred
  to next Sunday's regular run.

- **Apr 28 2026 follow-up** — Documented as cross-worktree pattern.
  Propagated to all 4 worktrees so any future agent editing a KPI
  script auto-loads this rule.

---

## Cross-references

- `delivery.md` — Logic App payload contract (BLOCKING field names),
  per-domain `CHANNEL_IDS` routing for the 6 individual scripts, and
  the general delivery pipeline this stapler plugs into.
- `kpi-weekly-charts.md` — chart-line implementation across the 6 KPI
  weekly reports (the metric-math sibling rule).
- `kpi-roster-filter.md` — Season table active-roster filter (display
  layer; another sibling rule for KPI weekly).
- `kpi-parallelization.md` — P2/P3/P4 query parallelization for the
  per-level data fetches inside each KPI script.
- `pdf-patterns.md` — general matplotlib + reportlab PDF patterns
  this codebase uses.
- `in-app-submission.md` — different pattern (form → pin → PDF →
  Slack inside one app); not used for KPI weekly but relevant for
  any future user-triggered combined PDF flow.
