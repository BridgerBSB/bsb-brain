---
name: feedback_match_existing_definitions_dont_invent
description: When refactoring scope/gate/bucket logic, MATCH the existing in-report definition exactly. Never invent a "simpler" alternative without explicit user approval, even when proposing a default.
type: feedback
originSessionId: c0bb79da-67cb-471a-9f9d-349e1195ea7d
---
When the user asks to change scope/gate/bucket logic in a report (e.g. "use 80 BIPs per bucket instead of 100 PA"), the bucket DEFINITION must be **read from the existing report code that already uses it** and matched exactly. Do NOT propose a "simpler" alternative as a default.

**Why:** Apr 30 2026 hitter advance scope refactor. User said "80 BIPs in IF bucket and OF bucket." The existing report had TWO different bucket definitions in the same file:
- Heatmap split: `LA <= 10` / `LA > 10`  
- Wedge chart split: `LA < 15 AND dist < 150` / `LA >= 15 AND dist >= 150`

I proposed the heatmap split as my "default" without confirming, called it "simpler" and "no distance dependence" — and shipped the unilateral pick. User: "WHY THE FUCK DID U DO THAT DUMBFUCK EXPLICITLY IN OUR RULES I TOLD U NOT TO." Correct. The wedge-chart definition was what they wanted because that's the panel the coordinator looks at to size sample.

**How to apply:**
- When the user says "scope by BIP buckets" or any similar gate change, grep the existing report file for ALL bucket definitions in use. Often there's more than one (heatmap vs wedge vs scatter).
- If there are multiple, list them and ASK which one is canonical for the scope refactor. Do not propose a default — let the user pick.
- "It's simpler" / "no distance dependence" / "matches the heatmap" are NOT reasons to override an existing definition. The existing definition wins by default.
- Cross-reference rules: `feedback_no_arbitrary_gates.md` (no min sample gates without direction), `feedback_match_reference_first.md` (diff against reference first), CLAUDE.md core rule #3 (never speculate).
