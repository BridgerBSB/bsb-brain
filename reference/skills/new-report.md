---
name: new-report
description: Pattern-enforced report generation. Use when building ANY new report system (KPI, weekly, advance, postgame, batch). Enforces reading reference implementations first, matching SQL/PDF/delivery patterns exactly, and generating per-player PDFs.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent
---

# New Report — Pattern-Enforced Generation

When building any new report system, follow this workflow exactly. Do NOT skip steps.

## Step 1: Scope Confirmation

Ask the user:
- [ ] Which worktree? (barrelsville, arm-farm, intangibles, pd-goals)
- [ ] Report type? (daily postgame, weekly individual, KPI org, batch advance, one-off analysis)
- [ ] Reference implementation to match? (e.g., "match the weekly hitter report pattern")

## Step 2: Read the ENTIRE Reference Implementation

Before writing ANY code:
- [ ] Read the reference report's **data module** end-to-end (every SQL query, every function)
- [ ] Read the reference report's **PDF/report module** end-to-end (layout, tables, charts)
- [ ] Read the reference report's **CLI script** (args, delivery, channel routing)
- [ ] Read the reference report's **app page** if one exists (sidebar flow, data calls)

**List every SQL column name, function signature, and filtering gate you found. Show the user this list and wait for confirmation before coding.**

## Step 3: Grep Before Writing SQL

- [ ] Grep for ALL column names you plan to use — confirm they exist in the DB
- [ ] Check `rules/db-columns.md` for Astros vs MLBAM column name conventions
- [ ] Match SQL Server (T-SQL) syntax exactly: `ISNULL()`, `TOP N`, `CASE WHEN` inside aggregates, `CAST(bit AS int)` before `SUM()`
- [ ] Use full schema prefixes: `MLB_eBis.PP_MASTER`, `Guts.woba_lwts`, etc.

## Step 4: Build Data Layer

- [ ] Match the reference's query structure (same JOINs, same WHERE clauses, same GROUP BY)
- [ ] Apply the correct tier gates / observation minimums from the reference
- [ ] Include `{sched_filter}`, `{level_clause}`, `{ha_filter}` placeholders where the reference has them
- [ ] Match the reference's `_build_level_filter()` and `_sched_type_filter()` usage

## Step 5: Build Report Layer

- [ ] Generate **per-player PDFs** (not bulk) — one PdfPages output per player
- [ ] Match header layout from reference (navy bar, headshot, affiliate logo, date range)
- [ ] Match table rendering from reference (plottable pattern, `_fix_null_bbox()`, percentile coloring)
- [ ] Match glossary from reference (EN/ES if applicable, same column layout)
- [ ] Never use `fontdict` and `fontsize` together in matplotlib

## Step 6: Build CLI Script

- [ ] Match reference CLI arg pattern: `--end` (required), `--level`, `--deliver`, `--deliver-z`
- [ ] Wire Slack delivery matching existing channel CSV routing (`pd-goals/data/slack_channels.csv`)
- [ ] Use `send_to_channel()` or `send_reports_via_logic_app()` from `src/deliver.py`

## Step 7: Verify Before Committing

- [ ] Run `python -m py_compile` on every new/modified `.py` file
- [ ] Run the CLI with `--help` to verify it parses
- [ ] If app page exists, verify imports resolve and page renders without error
- [ ] Update `manifest.json` if new files were added
- [ ] Update `.claude/rules/<app>.md` with the new report's files, CLI args, and key patterns

## Step 8: App/Report Parity (if applicable)

If this report has both a PDF and a Streamlit app page:
- [ ] Same data queries feed both
- [ ] Same filters applied in both
- [ ] App's PDF download button calls the report generator with the same data
- [ ] Document the file map in `.claude/rules/<app>.md`
