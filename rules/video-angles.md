# Video Angles — Two Tables + the V Column Standard (BLOCKING)

## Two video tables — what they are and when each populates

GC2 has **two** pitch-keyed video tables. They are NOT redundant — same pitches
can appear in one and not the other. Every app that renders ▶ links must
understand this split.

| Table | Column | Angle values | URL host | Coverage |
|---|---|---|---|---|
| `Astros.Video` | `angle_id` (int) | `1` (CF broadcast), `2` (CF backup) | `sporty-clips.mlb.com` (MLB Advanced Media) | **MLB games: always.** **MiLB: Astros-home games only** (HawkEye venues). NULL on Astros-away MiLB. |
| `Astros.Video_Network` | `angle` (char) | `'v'`, `'a'`, `'M'`, `'5'`, `'G'`, `'E'`, `'F'`, `'H'`, `'B'`, `'C'`, `'I'`, `'J'`, `'K'`, `'X'`, `'W'`, `'6'`, `'7'` | `gcweb02.astros.com` (Astros internal) | Broad but inconsistent — RND can miss individual angles on any game (V has been repeatedly missing in 2026). |

**Key mapping, verified 2026-04-24 by URL diff on sched_id 1296891 (MLB):**
- `Astros.Video.angle_id = 1` ⇢ equivalent pitch as `Video_Network.angle = 'a'` (CF broadcast)
- `Astros.Video.angle_id = 2` ⇢ equivalent pitch as `Video_Network.angle = 'v'` (CF backup)

Despite the equivalence, the **URL strings differ** — `Astros.Video` gives
`sporty-clips.mlb.com` URLs (MLB-hosted, IT-approved for player phones,
personal devices, Sporty Clips app), while `Video_Network` gives
`gcweb02.astros.com` URLs (Astros internal, blocked on most personal devices
except V / sometimes A).

## The V-column standard (ALL APPS, ALL SCRIPTS)

Every "V" column that ships to players (Arm Farm pitcher postgame, Barrelsville
hitter postgame, Intangibles BR/OF/IF weekly + individual, Arm Farm Daily
Tracker chart click-to-video) uses this **three-tier fallback chain**:

```sql
ISNULL(av.video_url,                       -- 1. Astros.Video angle_id=1  (PRIMARY)
  ISNULL(vn_v.video_url, vn_a.video_url))  -- 2. VN 'v' → 3. VN 'a'       (FALLBACK)
```

Required JOINs:
```sql
LEFT JOIN Astros.Video av
    ON av.sched_id = pv.sched_id AND av.pitch_id = pv.pitch_id AND av.angle_id = 1
LEFT JOIN Astros.Video_Network vn_v
    ON vn_v.sched_id = pv.sched_id AND vn_v.pitch_id = pv.pitch_id AND vn_v.angle = 'v'
LEFT JOIN Astros.Video_Network vn_a
    ON vn_a.sched_id = pv.sched_id AND vn_a.pitch_id = pv.pitch_id AND vn_a.angle = 'a'
```

**Why this order:**
1. **`Astros.Video` first** — sporty-clips is the only source that reliably
   plays on player phones regardless of IT policy. Catcher reports have always
   used this and they've been the one surface that never breaks for home games.
2. **`Video_Network 'v'` second** — personal-device-safe when RND ingests it,
   but they routinely miss it. Covers Astros-AWAY MiLB games where sporty-clips
   is empty.
3. **`Video_Network 'a'` third** — CF broadcast feed, often available when V
   isn't, still plays on phones (A is the other IT-approved angle). Last-resort
   safety net.

**What this chain fixes (2026-04-22 incident):** RND skipped the V angle in
`Video_Network` for Justin Thomas's game. V column showed empty for all his
at-bats. Catcher reports for the same day worked because they pull from
`Astros.Video`. After this fix, hitter/pitcher/fielder V columns also pull
from `Astros.Video` first — they work on the same games catcher reports do.

## Side / Main / CF Edge columns — UNCHANGED

This rule applies **only to the V column**. The existing Main/Side chains
(base-aware for BR, level-aware MLB/MiLB) stay as-is — they serve team-device
viewing where all angles are available. `Astros.Video` only has angles 1 and
2 (both CF), so it can't replace side-angle needs.

Intangibles BR's 8 pre-computed chains (`_MLB_MAIN_1B`, `_MILB_SIDE_2B`, etc.)
are untouched. Same for OF/IF position-aware chains.

## Reference implementations (canonical, keep in sync)

| App | File | Location |
|---|---|---|
| Arm Farm pitcher postgame | `bullpen-report/src/postgame_data.py` | `_PITCH_LOG_QUERY` v_url SELECT + `av` JOIN |
| Arm Farm Daily Tracker + chart click-to-video | `bullpen-report/src/video.py` | `get_pitch_videos` query `cf_angle_url` |
| Barrelsville hitter postgame | `barrelsville/src/video.py` | `get_pitch_videos` query `cf_angle_url` |
| Intangibles BR | `intangibles/src/br_data.py` | `_V_FALLBACK` constant + `_video_joins` |
| Intangibles OF weekly | `intangibles/src/of_weekly_data.py` | same pattern |
| Intangibles IF weekly | `intangibles/src/if_weekly_data.py` | same pattern |
| Intangibles catcher postgame | `intangibles/src/catcher_data.py` | (reference — always used `Astros.Video` alone) |

## Things NOT to do

- **Never use `Astros.Video` alone** for hitter/pitcher/fielder video — it's
  NULL on Astros-away MiLB games. Must have `Video_Network` fallback.
- **Never use `Video_Network` alone** for player-facing V — RND misses V
  angle regularly, and `'a'` fallback alone isn't as device-safe as sporty-clips.
- **Never use `.dbo.`** on either table — they're `Astros.Video` and
  `Astros.Video_Network`, full stop. See `db-columns.md`.
- **Never flatten the chain to one ISNULL nested 5 deep** — sticking to the
  3-tier standard means a future maintainer can spot the pattern at a glance
  and know which failure mode kicks each tier.

## Status: interim fix while we wait on RND + MLB API

**Current state (as of 2026-04-24):** this 3-tier chain is a **stopgap**. The
root problem is RND's inconsistent V-angle ingestion into `Video_Network`.
While we wait for RND to fix their pipeline, we're leaning on MLB's
sporty-clips (via `Astros.Video`) for Astros-home + all MLB games, and
falling back to Astros-internal V/A for Astros-away MiLB.

**Parallel track — MLB Stats API:** we're investigating pulling video
URLs directly from **MLB's Stats API** (or equivalent MLBAM-hosted endpoint)
as a future primary source. Advantages:
- Same sporty-clips URLs that already work on personal devices
- Coverage wouldn't depend on whether a game happens to be at an
  HawkEye-equipped Astros-home venue
- Decouples us from RND's internal ingestion timing

If/when the MLB API path lands, it should slot in ABOVE `Astros.Video` in the
chain (or replace it entirely if coverage is strictly wider). The existing
3-tier chain still works as a fallback during transition.

**When RND fixes V ingestion** (the eventual permanent win): this chain
keeps working without rewrite — `Astros.Video` still takes precedence for
MLB/home games, and `Video_Network V` becomes more reliable for away games.
We can prune or reorder tiers as evidence comes in.

## Diagnostic query — which tier resolved per pitch

```sql
SELECT pv.sched_id, pv.pitch_id,
    CASE
      WHEN av.video_url IS NOT NULL THEN 'Astros.Video (sporty-clips)'
      WHEN vn_v.video_url IS NOT NULL THEN 'Video_Network v (astros internal)'
      WHEN vn_a.video_url IS NOT NULL THEN 'Video_Network a (astros internal)'
      ELSE 'NO VIDEO'
    END AS resolved_tier,
    ISNULL(av.video_url, ISNULL(vn_v.video_url, vn_a.video_url)) AS final_url
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Video av
    ON av.sched_id = pv.sched_id AND av.pitch_id = pv.pitch_id AND av.angle_id = 1
LEFT JOIN Astros.Video_Network vn_v
    ON vn_v.sched_id = pv.sched_id AND vn_v.pitch_id = pv.pitch_id AND vn_v.angle = 'v'
LEFT JOIN Astros.Video_Network vn_a
    ON vn_a.sched_id = pv.sched_id AND vn_a.pitch_id = pv.pitch_id AND vn_a.angle = 'a'
WHERE pv.sched_id = @sched_id AND pv.pitch_id > 0;
```

## History

- **2026-04-22** — Justin Thomas (batter_id 170147) V column all-NULL on
  `Video_Network`. RND skipped V angle ingestion. Catcher reports same day
  for same game worked — `Astros.Video` had data.
- **2026-04-24** — Traced: catcher reports use `Astros.Video angle_id=1`
  (sporty-clips). Confirmed angle_id=1 ≡ angle='a' on MLB game 1296891.
  Confirmed Astros.Video is MLB-home/Astros-home populated (Vasquez catcher
  1299428 had 131/131; Thomas/Schiavone 1295097 had 0). Shipped the three-tier
  fallback across all apps: Arm Farm (commits `ff5abc6`, `d011ae1`),
  Barrelsville (`b8852fb`), Intangibles (`9940087`).
