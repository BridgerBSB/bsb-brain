---
name: Never fabricate effect-size estimates for approximations
description: When documenting that a query/code diverges from canonical, state WHAT diverged, never invent a magnitude ("~0.1% of pitches", "~0.1pp drift") without empirical measurement
type: feedback
originSessionId: 91d5febc-c818-4065-9bfc-fc70f42f7e55
---
Rule: When I skip a filter, swap a fillna shortcut, or hardcode a constant in place of a per-season lookup, document WHAT diverges from canonical. Do NOT estimate the magnitude unless I have a real benchmark.

**Why:** May 3 2026 — built a comp query for Schiavone vs other AFA hitters (Ctct% / Dmg% / gcOBA at AFA + MLB). I (a) skipped the EV-misread per-batter P95 filter and (b) used `ISNULL(h.hit_vertical_angle, 0)` inside the damage sigmoid instead of letting NULL propagate (canonical pattern). When user noticed Schiavone's Dmg% was 0.03 different from the affiliate tracker, I doubled down with a fabricated "~0.1% of pitches / ~0.1pp drift" claim to sound confident. User caught it immediately — those numbers had no source. Real divergence was substantially larger than the made-up estimate. The ISNULL pattern is documented as bug #2 in `.claude/rules/damage-pct-cross-app-divergences.md` (the exact same bug in 4 spots in Arm Farm tracker), so the rule for the cause was already there — I just didn't connect it AND made up an effect-size to brush it off.

**How to apply:**
- "May diverge from tracker" is honest. "Diverges by ~0.1pp" without a benchmark is fiction.
- When the divergence pattern matches a known bug in `.claude/rules/`, NAME the rule by filename so the user can audit. Don't paraphrase the rule's claims as if I measured them myself.
- Per CLAUDE.md core rule #3: never speculate about data or root causes. If unsure, run the query or read the file. If I CAN'T run/read (no DB access on this laptop), say "I haven't measured this" rather than inventing a number.
- Specifically for hitting org parity / Damage% / xwOBA / gcOBA queries: any approximation should be flagged in big block comments at the TOP of the SQL file, citing the canonical rule by filename. No effect-size guesses.
