---
name: No arbitrary gates or labels
description: NEVER add minimum sample gates, "practice only" labels, or other restrictive assumptions without explicit user direction
type: feedback
originSessionId: 8111e053-287a-4210-aa90-212cee65f81f
---
NEVER add arbitrary minimum sample gates (e.g., HAVING COUNT >= 10) or restrictive labels (e.g., "Practice Data Only") without explicit user direction.

**Why:** User was frustrated when blast leaderboard had a minimum 10-swing gate and "Practice Data Only" labels that were never requested. These assumptions narrowed the output and mischaracterized the data source.

**How to apply:** When building new reports or queries, include ALL data unless the user specifies a filter. If you think a gate would be useful, ask — don't add it. Same for characterizing data sources — describe what it IS (BlastMotion sensor data), not what you assume it's limited to.
