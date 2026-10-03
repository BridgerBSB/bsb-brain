---
type: inbox
created: '2026-07-13'
tags: [inbox, session-digest, needs-processing]
session: 99bb7133
corrections: 2
---
# Session digest — 2026-07-13 00:17:30UTC · 99bb7133

- cwd: `C:\Users\Owner\bsb-resources` · end: clear · 80 turns · 6 files · 10 bash
- raw: [[transcripts/2026-07-13_99bb7133.jsonl]]

## Files touched
- `MEMORY.md` ×6
- `college-to-pro-fb-velo-jump-2024-2025.sql` ×5
- `ff-cu-separation-26-30in-2026.sql` ×4
- `org-pre2k-2k-usage-gcperf-2026.sql`
- `sam-dj-velo-usage-queries-2026-07.md`
- `MEMORY_original.md`

## ⚠️ Possible teaching moments (curate → golden set)
> "this is a /amateur query we need to cook up for sam similar to our most recent query and also a blend of some in teh past ro =so remember those!!! to assist us here... also i have 2 other non amateur requests from DJ we can /plan or /spec if you need naymore h…"
>   ↳ after: (session start)

> "yes why are you even asking 0- just run them and ill tell you whats wronfg with them"
>   ↳ after: Pushed to `feature/pd-goals`. This is SQL-only (no Connect deploy), so the runbook is just…

## Conversation skeleton (first 30 of 80)

**You:** this is a /amateur query we need to cook up for sam similar to our most recent query and also a blend of some in teh past ro =so remember those!!! to assist us here... also i have 2 other non amateur requests from DJ we can /plan or /spec if you need naymore helo from me: Sam Nie…
→ I'll start by invoking the `/amateur` skill since this is squarely a college/draft/amateur query — it forces the disambiguation that keeps us out of the college-reliever-dig bug class.
→ `Skill`
→ The skill is loaded. Before I ask Sam-query disambiguation, let me ground myself in the prior queries this should blend — the college-reliever dig (reference impl), the amateur-vs-pro script, and any …
→ `Bash: ls sql-queries/ | grep -iE 'velo|ff|ft|amateur|draft|jump|ds…`
→ `Grep`
→ Highly relevant prior work exists: `dsl-ff-velo-jump-org-leaderboard.sql` (the org-rollup shape Sam wants) and the college-reliever dig (college tracked-velo extraction). Let me read both.
→ `Read`
→ `Read`
→ I've grounded myself in the three prior queries this blends: the **college-reliever dig** (`generate_college_reliever_dig.py` — the college tracked-velo extraction, EXISTS source gate, gcid grouping, …
→ `AskUserQuestion`
→ Crystal clear. Locking the spec: - **FB = FF+FT pooled into one avg velo**; jump = pro FB − final-college-season FB. - **Top 100 = non-traded arms only** (drafting org == current org), ranked by jump;…
→ `Write college-to-pro-fb-velo-jump-2024-2025.sql`
→ Now committing + pushing so you can pull it on the work laptop:
→ `Bash: git add sql-queries/college-to-pro-fb-velo-jump-2024-2025.sq…`
→ Pushed to `feature/pd-goals`. This is SQL-only (no Connect deploy), so the runbook is just: ``` ── Work-laptop runbook ────────────────────────── 1. cd C:\Users\zbridger\bsb-resources ; git pull 2. Ru…

**You:** yes why are you even asking 0- just run them and ill tell you whats wronfg with them
→ Building both now.
→ `Write org-pre2k-2k-usage-gcperf-2026.sql`
→ `Write ff-cu-separation-26-30in-2026.sql`
→ `Bash: git add sql-queries/org-pre2k-2k-usage-gcperf-2026.sql sql-q…`
→ Both DJ pulls are pushed. `git pull` on the work laptop, run against GroundControl2. All three files are pure SQL, no deploy. **1. `org-pre2k-2k-usage-gcperf-2026.sql` — DJ's usage + gcPerf** Per org …

**You:** in sams quey youe top 100 is what how did u handle that? just curious - sam requested we include 2023 make those adjustments ; u did ivb separation right? 2. ff-cu-separation-26-30in-2026.sql — DJ's FF/CU separation Pitchers whose avg FF and avg CU are 26–30" apart in total movem…
→ Good catches — let me look at what you're seeing before I edit. Reading the image and the exact failing line.
→ `Read`
→ `Read`
→ Both issues are clear now, and the image confirms DJ's point precisely: - **Row 1 Max Banks:** FF IVB 14.3, CU IVB −7.0 → the IVB separation DJ wants is `14.3 − (−7.0) = 21.3`. My `Sep` column reads 3…
→ `Edit college-to-pro-fb-velo-jump-2024-2025.sql`
→ `Edit college-to-pro-fb-velo-jump-2024-2025.sql`
→ `Edit college-to-pro-fb-velo-jump-2024-2025.sql`
