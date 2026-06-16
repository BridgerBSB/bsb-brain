# Org Codes — Universal Canonicalization (BLOCKING)

Any time a query JOINs **two or more sources** that carry an MLB-org
identifier, the org codes MUST be canonicalized to a single form
BEFORE the JOIN. Otherwise rebranded / aliased orgs silently drop out
of the result (Athletics is the live case as of 2024+; more may
follow).

This applies **everywhere**, not just draft projects. Three-surface
parity, KPI weekly, org KPI, tracker pins, Team View ranks, advance
reports — anywhere two tables expose an org column and you JOIN on it.

---

## Sources and their natural org column form

| Source | Column | Form | Notes |
|---|---|---|---|
| `MLB_eBis.PP_MASTER.ORG_LK` | `ORG_LK` | UPPERCASE 3-char | Updated when player moves orgs |
| `MLB_eBis.GBL_CLUB_LKUP.ORG_LK` | `ORG_LK` | UPPERCASE 3-char | Updated when clubs rebrand |
| `MLBAM.Teams.org_abbrev` | `org_abbrev` | UPPERCASE 3-char | Per-season; can lag rebrand by import cycle |
| `MLB_eBis.R4_Draft_Query.draft_org` | `draft_org` | **lowercase** | Has historical shorthand quirks (`chi`/`la`/`ny`) |
| `Astros.Players` (no org column) | — | — | Use PP_MASTER for current org |

---

## The canonicalization rules

### Rule 1 — Athletics (BLOCKING)

`OAK` and `ATH` are the same franchise. Each source independently
chose when to flip. Always collapse both to a single canonical form.

**Canonical = `ATH`** (the post-rebrand form).

```sql
CASE UPPER(<src>) WHEN 'OAK' THEN 'ATH' ELSE UPPER(<src>) END
```

Apply this transform to **EVERY org column on EVERY side of the JOIN**.
Not just one side. Applying it on one side and not the other still
silently drops Athletics (the other side keeps the un-canonicalized
value and the JOIN misses).

### Rule 2 — Cubs / Dodgers / Mets shorthand (BLOCKING)

Verified Apr 20 2026: `MLB_eBis.PP_MASTER.ORG_LK` and
`MLB_eBis.GBL_CLUB_LKUP.ORG_LK` use lowercase shorthand for three orgs
(uppercased = `CHI` / `LA` / `NY`), while `MLBAM.Teams.org_abbrev`
uses the full 3-char form (`CHC` / `LAD` / `NYM`). They do NOT match
out of the box.

| PP_MASTER / GBL_CLUB_LKUP form | MLBAM form |
|---|---|
| `CHI` | `CHC` (Cubs) |
| `LA`  | `LAD` (Dodgers) |
| `NY`  | `NYM` (Mets) |

**Same lowercase forms appear in `R4_Draft_Query.draft_org`** (`chi`,
`la`, `ny`) for the same orgs — so whichever source you start from on
the MLB_eBis side, the JOIN to MLBAM needs the remap.

**Important:** `ny` = NYM (Mets), NOT Yankees. Yankees = `nyy`. Same
for `la` = LAD (Dodgers), NOT Angels — Angels = `laa`. The shorthand
only applies to these three orgs (the ones with two NYC/LA/Chicago
clubs where MLBAM disambiguates with the 3rd letter).

### Pick a canonical form for your query

You can canonicalize either direction:

- **To PP_MASTER form (CHI/LA/NY/ATH)** — remap MLBAM side:
  ```sql
  CASE UPPER(t.org_abbrev)
      WHEN 'CHC' THEN 'CHI'
      WHEN 'LAD' THEN 'LA'
      WHEN 'NYM' THEN 'NY'
      WHEN 'OAK' THEN 'ATH'
      ELSE UPPER(t.org_abbrev)
  END AS org
  ```
- **To MLBAM form (CHC/LAD/NYM/ATH)** — remap PP_MASTER side:
  ```sql
  CASE UPPER(pm.ORG_LK)
      WHEN 'CHI' THEN 'CHC'
      WHEN 'LA'  THEN 'LAD'
      WHEN 'NY'  THEN 'NYM'
      WHEN 'OAK' THEN 'ATH'
      ELSE UPPER(pm.ORG_LK)
  END AS org
  ```

Either works; pick the form that matches your downstream display
(channel routing, label dicts, etc.). Don't mix forms within one query.

---

## Reference helpers

### Python — `_R4_TO_MLBAM_ORG` dict

Lives in `barrelsville/scripts/generate_amateur_vs_pro.py`. Copy/paste:

```python
_R4_TO_MLBAM_ORG = {
    "chi": ("CHC",),
    "la":  ("LAD",),
    "ny":  ("NYM",),
    "ath": ("ATH", "OAK"),  # Athletics rebrand 2024
    "oak": ("OAK", "ATH"),
}

def _mlbam_codes_for(draft_org: str) -> tuple[str, ...]:
    return _R4_TO_MLBAM_ORG.get(draft_org.lower(), (draft_org.upper(),))
```

Use with `UPPER(mt.org_abbrev) IN (<codes>)` for the SQL projection.

### SQL — inline CTE pattern

For two-table JOINs (no R4), the OAK→ATH CASE is enough:

```sql
WITH src1 AS (
    SELECT CASE UPPER(s.ORG_LK) WHEN 'OAK' THEN 'ATH'
                                  ELSE UPPER(s.ORG_LK) END AS org,
           ...
    FROM <source 1> s
    ...
),
src2 AS (
    SELECT CASE UPPER(t.org_abbrev) WHEN 'OAK' THEN 'ATH'
                                       ELSE UPPER(t.org_abbrev) END AS org,
           ...
    FROM <source 2> t
    ...
)
SELECT ... FROM src1 JOIN src2 ON src1.org = src2.org ...
```

For three-table JOINs (e.g., GBL_CLUB_LKUP + PP_MASTER + MLBAM.Teams),
apply the CASE on every source's projection. Pattern in:
`pd-goals/pages/6_Team_View.py::_ORG_AGE_RANKS_SQL` (Team View avg
age + Lvl Rk + Lg Rk subtitle).

For four-source JOINs with R4 in the mix, see the SQL pattern in
`barrelsville/scripts/generate_amateur_vs_pro.py` (org-tenure gating
on pro stats keyed by `draft_org`).

---

## Live reference impls

| File | Why it does this |
|---|---|
| `pd-goals/pages/6_Team_View.py::_ORG_AGE_RANKS_SQL` | 3-source JOIN (PP_MASTER + GBL_CLUB_LKUP + MLBAM.Teams); CASE applied in all three CTEs |
| `barrelsville/scripts/generate_amateur_vs_pro.py` | R4 → MLBAM via `_R4_TO_MLBAM_ORG` + Athletics dual-acceptance in pro-stats gate |
| `barrelsville/src/advance_data.py::_map_mlbam_org_to_pp_master` | One-way reverse mapping for advance scouting |
| `intangibles/src/hitter_advance_data.py::_map_mlbam_org_to_pp_master` | Same as above for hitter advance |

When adding a new cross-source JOIN, **read one of these first** —
copy the existing pattern, don't reinvent.

---

## Symptoms when this is missed (audit checklist)

If any of these appear, suspect missing OAK/ATH canonicalization:

- **29 orgs instead of 30** in a "per-org" leaderboard / rank
- **Athletics row missing** from an org rollup table
- **Athletics Lg Rk = NULL** or **Lvl Rk = NULL** in a level page
- **Athletics' draft picks** missing from a draft-class analysis
- **Athletics' pro-tenure stats** dropped when org-tenure-gating a
  prospect's pro performance

Verify by adding the OAK/ATH `CASE` to every projection in the chain
and re-running. If the count goes from 29 → 30, the diagnosis was right.

---

## Bug history

- **May 12 2026 (2 of 2)** — Same Team View query had a SECOND missing
  canon: PP_MASTER's `CHI` / `LA` / `NY` shorthand for Cubs / Dodgers /
  Mets didn't match MLBAM's `CHC` / `LAD` / `NYM`. Lg Rk came back NULL
  for those 3 orgs' affiliate pages. Audit triggered this discovery —
  the cross-source rule was scoped to "Athletics only" but the bug
  class is broader (any time PP_MASTER ↔ MLBAM disagree on org form).
  Rule v2 (this file): now documents both Rule 1 (OAK/ATH) and Rule 2
  (CHI/LA/NY) as universal cross-source concerns, not draft-specific.
  Fixed in `07fff07` on `feature/pd-goals`.
- **May 12 2026 (1 of 2)** — Team View `_ORG_AGE_RANKS_SQL` shipped without
  OAK/ATH canonicalization. User correctly flagged: "we handle these
  everywhere — should be naturally dialed." Rule promoted from
  draft-projects.md (R4-scoped) → this universal rule (any cross-source
  JOIN). Fixed in `3c5f91d` on `feature/pd-goals` + synced cross-worktree.
- **Apr 2026** — `_R4_TO_MLBAM_ORG` mapping shipped in
  `generate_amateur_vs_pro.py` (commit `2ecdd0e`) after first amateur-vs-pro
  run showed Athletics + Cubs + Dodgers + Mets dropping from the org
  rollup (28 orgs displayed instead of 30). Originally scoped to draft
  analysis only — see `rules/draft-projects.md` "R4 → MLBAM" section
  for the project context.

---

## What NOT to do

- **Don't** apply the OAK/ATH CASE on only one side of the JOIN. Both
  sides must canonicalize or the JOIN still misses.
- **Don't** assume a query "shouldn't have this issue" because it's
  small or because Athletics "isn't relevant" — they're still 1/30 of
  the org pool and they'll be missing from results, distorting averages
  and ranks.
- **Don't** add chi/la/ny remapping to PP_MASTER ↔ MLBAM JOINs. Those
  are R4-shorthand-specific. Adding them where R4 isn't a source either
  no-ops (no rows match) or silently corrupts data.
- **Don't** hardcode `'OAK'` or `'ATH'` as a literal filter without
  testing both — `WHERE org = 'OAK'` misses Athletics rows currently
  tagged `'ATH'` and vice versa.
- **Don't** rely on a single helper file for the rule — embed the
  CASE in every cross-source JOIN. The cost of duplicating five lines
  of SQL is trivial; the cost of importing a shared helper across
  4 worktrees and 3 levels of caching is not.
