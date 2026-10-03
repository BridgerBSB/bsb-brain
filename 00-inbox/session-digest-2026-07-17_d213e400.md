---
type: inbox
created: '2026-07-17'
tags: [inbox, session-digest, needs-processing]
session: d213e400
corrections: 0
---
# Session digest — 2026-07-17 18:09:47UTC · d213e400

- cwd: `C:\Users\Owner\bsb-resources` · end: other · 16 turns · 0 files · 12 bash
- raw: [[transcripts/2026-07-17_d213e400.jsonl]]

## ⚠️ Possible teaching moments (curate → golden set)
_(none auto-detected — still worth a glance)_

## Conversation skeleton

**You:** ok - what are teh scripts i need top run for our 2 mlb kpi reports (org and weekly org kip)? just need what to run in teh terminal quickly
→ Quick lookup — let me find the exact scripts for your two MLB KPI reports.
→ `Bash: ls pd-goals/scripts/ | grep -iE 'kpi|org'`
→ `Bash: grep -rl "mlb" pd-goals/scripts/*kpi* 2>/dev/null; echo "---…`
→ `Bash: grep -nE 'add_argument|--level|--mlb|choices|def main|argpar…`
→ `Bash: grep -rniE 'weekly.*org|org.*weekly|mlb.*kpi' pd-goals/scrip…`
→ `Bash: sed -n '103,220p' pd-goals/scripts/generate_org_kpi.py`
→ `Bash: cat "C:/Users/Owner/.claude/projects/C--Users-Owner-bsb-reso…`
→ `Bash: grep -nE "LEVEL_CONFIGS|'mlb'|\"mlb\"|mlb" pd-goals/scripts/…`
→ `Bash: grep -niE "mlb|org-kpi|org_kpi|kpi" pd-goals/scripts/run_mon…`
→ `Bash: grep -rniE "weekly.?org|org.?kpi.?weekly|weekly_org|mlb.*wee…`
→ `Bash: grep -rniE "mlb" pd-goals/scripts/generate_combined_kpi.py 2…`
→ Got it — here's the picture. Both are CLI-only (no Connect deploy), run on the work laptop.
→ `Bash: sed -n '195,275p' pd-goals/scripts/generate_combined_kpi.py`
→ `Bash: grep -nE "REPORT_SOURCES|Outfield|Infield|Baserunning|out_di…`
→ Here's what to run on the work laptop (both are CLI-only, no Connect deploy). Using today `2026-07-17` as `--end`: ## 1. Org KPI (MLB) — season-long, `generate_org_kpi.py` MLB only shows up in the `--…
