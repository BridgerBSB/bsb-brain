---
name: Org Age Rank — Sam ask shipped
description: One-off SQL ranking HOU age vs 30 orgs at AAA/AA/A+/A, opening day vs now. TR_HISTORY reconstruction pattern.
type: project
---

**Shipped May 7-8 2026** as `sql-queries/org-age-rank-opening-day.sql` on `feature/pd-goals`. Final commit: `b99d339`.

**Why:** Sam Niedorf Slack ask — "where did we rank age wise on opening day in FAY/ASH/CC/SUG vs the other 30 teams?" Plus current rank comparison.

**How to apply:** Future "where did we rank in X on date Y" questions can reuse this query's structure — only the metric and date change.

---

## Output shape

**Part 1 — HOU summary, one row per affiliate level (AAA/AA/A+/A):**
`level_affiliate, hou_n_open, hou_age_open, rk_open_youngest, hou_n_now, hou_age_now, rk_now_youngest, of_n_orgs, rank_diff`

**Part 2 — HOU opening-day player roster, one row per player:**
`level, club_short, player, pos, bats, throws, age_at_4_1, mn_status_4_1, mj_status_4_1, last_txn_date, last_txn_name, groundcontrol_id, ebis_id`

---

## Non-obvious decisions (don't re-derive)

1. **Mixed methodology by design:**
   - "Now" pool = PP_MASTER directly (matches Org Board's `roster.get_roster()`)
   - "Opening day" pool = TR_HISTORY reconstruction (PP_MASTER has no historical state)

2. **Filter is intentionally different per pool:**
   - Now → Alvaro blacklist (`NOT IN ('REL','FA','VOL','DIS','TI','RES','7DL','DL','10D','15D','60D','FSIL','7RH','15R','60R','DFA')`). Required for `hou_age_now` to match Org Board.
   - Opening day → strict ACT/PAC/DEVEL whitelist on `COALESCE(POST_MN, POST_MJ)`. User direction.

3. **Org canonicalization via `GBL_CLUB_LKUP`, NOT `TR_HISTORY.POST_ORG_LK`.** Using POST_ORG_LK directly inflates the org count past 30 — historical/junk abbreviations leak through (defunct franchises, indy ball orgs, OAK/ATH rebrand, etc.). The 30-MLB-org universe is defined as "orgs with an active ML-level club in GBL_CLUB_LKUP" (`mlb_orgs` CTE).

4. **MN vs MJ status precedence:** `COALESCE(MN, MJ)` — minor-league status takes priority over major-league status. A guy with MN='IL' MJ='ACT' is hurt at his MiLB level, exclude. Part 2 displays both columns separately for audit.

5. **TR_HISTORY rewind pattern:**
   ```sql
   ROW_NUMBER() OVER (PARTITION BY PLAYER_ID ORDER BY TRANSACTION_DTSTMP DESC)
   WHERE TRANSACTION_DTSTMP < '2026-04-02'
   ```
   Most recent txn at/before cutoff → POST_* fields = roster state at cutoff. Reusable for any historical "where was this player on date X" reconstruction.

---

## Iteration history (so we don't repeat the dead-ends)

- Initial version used current PP_MASTER for both ranks with two age anchors. User pushed back: "where we ranked on opening day" needs ACTUAL opening-day rosters, not just rewound ages on current rosters.
- First TR_HISTORY reconstruction had two bugs:
  1. Used `TR_HISTORY.POST_ORG_LK` directly → >30 orgs in output (historical org abbrevs).
  2. Switched "now" pool to TR_HISTORY too → diverged from Org Board (TR_HISTORY has lingering POST_ORG=HOU rows for guys who later got released without clean status updates).
- User reverted me. Reshipped with: GBL_CLUB_LKUP-derived org for opening day, PP_MASTER unchanged for now.
- Tried ACT/PAC whitelist on both pools → `hou_age_now` diverged from Org Board (whitelist excludes OPT/OUTRT). Switched now back to Alvaro blacklist. Whitelist (with DEVEL added) stayed on opening-day pool.
- Final: split filters per pool. MN/MJ shown separately in Part 2.

---

## Open / unresolved

- User said "needs more refining" but is OK as a starting point. Next iteration likely after a clear + new context.
- Hardcoded reference date `'2026-04-01'` for opening day. Parameterize if reused.
- `HAVING COUNT(*) >= 5` per (org, level) — defensive against pool-size noise. May need to drop for thin levels in early-season. Currently AAA/AA/A+/A always ≥5.
- DEVEL is a status code I added per user direction May 7. Not in `db-columns.md` PP_MASTER status code list — verify when it appears in output.

---

## What NOT to do

- Don't use `TR_HISTORY.POST_ORG_LK` as the org grouping key. Always go through `GBL_CLUB_LKUP` (filtered to 30-org MLB universe).
- Don't apply the same filter to both pools. They're different pools answering different questions.
- Don't COALESCE MN and MJ for display — show both. COALESCE only for the WHERE filter.
- Don't try to make TR_HISTORY-based "now" pool match Org Board. It won't (lingering POST_ORG=HOU rows on released players). Use PP_MASTER for "now."
