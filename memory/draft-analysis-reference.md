---
name: Draft Analysis Scripts & DB Patterns
description: R4_Draft_Query usage, PP_MASTER roster levels, draft pick analysis patterns from Feb-Apr 2026
type: project
---

Two draft analysis scripts exist in `pd-goals/scripts/`:

1. **`ss_draft_analysis.py`** (Feb 13, 2026) — Sam's request. First-round HS shortstops 2020-2024, level progression in following year via Pitches_View stint detection. 2-page landscape PDF with percentile-colored metrics (K%, BB%, wOBA, AVG, OPS, ORP, DRS, RAR). Marcelo Mayer appears in output.

2. **`hs_firstround_2025_placement.py`** (Apr 3, 2026) — Boss's request. All 2025 first-round HS picks (any position), current roster level from PP_MASTER. Answer: 13 of 15 at full-season affiliates (A ball), 2 at complex (Steele Hall CIN, Jordan Yost DET). Xavier Neyens (HOU, #21) at A (1F).

**Why:** These are the "Xavier Neyens project" / "BBC college" analyses the user references. The BBC connection is that BBC (Big League Camp) is a junk level in Schedule_View — the college draft data lives in `R4_Draft_Query.school_type` filtering, not BBC level code.

**How to apply:** When boss or Sam asks about draft pick placement/progression, start from these scripts. R4_Draft_Query → Astros.Players → PP_MASTER is the pattern for "where are they rostered now." R4_Draft_Query → Pitches_View stint detection is the pattern for "where have they actually played."
