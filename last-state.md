# Last session state — 2026-07-26 (Opportunities bot: golden percentile gates + bat-speed P90 fix)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` · branch `feature/pd-goals` (spanned barrelsville + bullpen worktrees too)
- **What we were doing:** Hardening the opportunities/goals bot — pitcher HB anchors, canonicalizing percentile pool gates, one-command org-wide run tooling, and fixing a bat-speed ceiling glitch.

- **Shipped this session (all committed + pushed):**
  - **Pitcher anchors verified on 2026 data** (P95 ceilings, FF VAA lower-better, 30-pitch gate, FT arm-side run). **`--season` now defaults to current year** + offseason fallback (the Dunford missing-player fix).
  - **CH arm-side + SL glove-side HB anchors** added, hand-normalized, verified both hands positive on 2026.
  - **Percentile GOLDEN GATES** — new `.claude/rules/percentile-golden-gates.md` (synced ×4 worktrees, committed on all) + **global `/percentile` skill** + memory `fullseason-percentile-golden-gates.md`. Gates: **Pitcher 300 / Hitter 50 / OF-IF 10 / BR 30 / Catcher 1500** (season; 500=monthly). Keyed on 4-tuple (domain,metric,period,focus); NetK splits=500.
  - **Pitcher season pool 200→300** (bullpen postgame_percentiles) to match the gate.
  - **`run_opportunities.ps1` gained `-PitcherGcids`/`-PitcherGcidFile`** (full position roster + a specific pitcher subset); `opportunities/pitcher_gcids.txt` (15 arms).
  - **BAT-SPEED CEILING FIX:** `max_bs` (raw `.max()` grabbed the 332mph Hawkeye glitch) → renamed **`bs_p90`**, computed **P90** on value + pool, mirrors `ev_p90`. Barrelsville `postgame_percentiles` + `hitter_analysis` + bsb-resources ranker. **Production apps were NEVER affected** (they clean the AVG).
  - Command Center dashboard got a "Rules & context" deck group (/load-rules, /percentile, etc.).

- **EXACT next step:** On the work laptop, `git pull` bullpen + hitting + bsb-resources, then re-run: `powershell -ExecutionPolicy Bypass -File opportunities\run_opportunities.ps1 -Season 2026 -PitcherGcidFile .\opportunities\pitcher_gcids.txt` — to get the CORRECTED `bs_p90` (90% BS) values (this session's output still had the stale 332 glitch). Then Zac updates his goals CSV from the 5-per-domain output.

- **Blockers / waiting on:** All fixes are **work-laptop-UNRUN vs live DB**. OPEN reconciles: quadrant-NetK gate 300 (bot) vs 500 (golden rule); per-PT pitcher shape gate 30-vs-300 units question; Lucas Spence dropped from ranked output (investigate); full metric-by-metric percentile audit pending.

- **Uncommitted work:** 86 pre-existing untracked/modified files in bsb-resources, unrelated. All session work committed + pushed across 3 worktrees.

---

## ALSO OPEN — EOY P13 Fielding (bsb-resources/feature/pd-goals, from 2026-07-21, preserved)

- **What:** Building the FIELDING half of the EOY position-player report. P13 "Fielding Season Review" shipped (page + `eoy_fielding_data.build_page13` + `test_eoy_page13_shape.py` 20 checks). New rule `player-facing-voice.md` (BLOCKING, you/your).
- **EXACT next step:** Zac's words: *"continue building out the fielding (IF, OF, C tools) next session — i have an idea what these will look like in 1-2 pages per each."* **ASK Zac for his 1-2-page-per-tool concept for IF/OF/Catcher FIRST, then mock.** Resolve the PARKED question: multi-position-family player → pages repeated per family, block cloned, or primary family only?
- **Blockers:** WORK LAPTOP — every P13 query written canonically but NEVER EXECUTED. Run `python scripts/test_eoy_page13_shape.py` then `generate_eoy_position.py --gcid 218498 --season 2026` (+ a real catcher gcid).
