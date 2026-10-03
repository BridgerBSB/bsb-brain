---
name: dj-yoy-velo-still-in-org-query
description: "Reusable pattern for \"pitchers from cohort year X still in org now, show year-over-year velo\" pulls (DJ Engle ask shape)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 47f9956c-e24d-45c1-81b8-6405ab5b9886
---

DJ Engle recurringly asks for year-over-year velo pulls. Jun 24 2026
deliverable (SHIPPED + verified on work-laptop DB): "HOU arms who pitched
2025 DSL, still in our org in '26, show YoY fastball velo." Query lives at
`sql-queries/hou-dsl-2025-arms-yoy-ff-velo-2026.sql`.

Two conventions that make this query class correct (I got both wrong on
the first pass):

1. **"Still in our org" = EBIS roster gate, NOT a game-based gate.** Join
   `MLB_eBis.PP_MASTER pm ON pm.player_id = pl.ebis_id AND pm.ORG_LK='HOU'`
   (groundcontrol_id → Astros.Players.ebis_id → PP_MASTER). A "pitched a
   2026 HOU game" gate wrongly drops roster kids who haven't thrown enough
   yet this early in the season. Use `LEFT JOIN` on the current-year velo
   so those kids still list (blank current velo).

2. **Anchor years are FIXED (2025 → 2026), never min→max.** Do NOT reuse
   the first-DSL-year → last-DSL-year logic from
   `hou-dsl-ff-velo-jump-2yr.sql` — that's a different deliverable and
   produces a "random" first year. The current-year side is ANY level
   (DSL→MLB), junk excluded; show `PP_MASTER.LEVELOFPLAY_LK` as "where he
   is now."

Same conventions as the other velo queries: org gate via
`ev.fielding_team_id → MLBAM.Teams.org_abbrev='HOU'`, velo cap 60-110,
FF-only by default (swap to `IN ('FF','FT','SI')` for all fastballs),
loose FF-count gates (n shown). Relates to [[arm-farm-pitch-efficiency-shipped]].
