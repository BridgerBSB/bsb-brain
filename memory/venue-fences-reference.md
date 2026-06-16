---
name: venue-fences-reference
description: MiLB venue fence data from Adam Brodie — venue_fences_detailed table, HawkEye reliability issues at CC/SUG
type: reference
---

## MiLB Venue Fences (Adam Brodie, Mar 22 2026)

**Table:** `venue_fences_detailed` (schema TBD — need INFORMATION_SCHEMA)
**Join:** `venue_id` from `MLBAM.Schedule`

**What it has:** Estimated fence dimensions per venue, based on batted ball distances and HR/fielded classification. Plus official dimensions.

**Quality:** Validates great on MLB parks. MiLB HawkEye data has proven unreliable at several venues including **Corpus Christi (CC)** and **Sugar Land (SUG)** — so fence estimates are not very good at those parks anymore.

**Current approach:** Always use Minute Maid fence equations (matches Barrelsville advance pattern). This works for now since we're focused on Astros org and the visual is primarily about ball flight arcs, not precise fence representation.

**Future:** Could query `venue_fences_detailed` per game's venue_id for park-specific fences. Would need to:
1. Find the table's full schema (`INFORMATION_SCHEMA` query)
2. Join via `MLBAM.Schedule.venue_id`
3. Convert fence data points to polar equations (or use linear interpolation like the Athletics/Rangers pattern from Robbiedudz)
4. Accept that CC and SUG estimates may be inaccurate due to HawkEye issues

**Not urgent** — Minute Maid fence works fine as the default visual. Only matters if we want park-specific accuracy for away games or other orgs.
