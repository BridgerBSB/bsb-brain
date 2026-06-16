---
name: Two video tables — Astros.Video_Network vs Astros.Video
description: GC2 has TWO distinct video tables. Most apps use Astros.Video_Network (string angle col). Catcher reports use Astros.Video (integer angle_id col). They can populate independently — one can be empty while the other has data for the same game.
type: reference
originSessionId: 576ada4c-1a2e-4e9a-89a0-e9fd305a6281
---
# Two video tables in GC2

Apr 23 2026 discovery while debugging why Justin Thomas (batter_id=170147) had NULL V-angle URLs in `Astros.Video_Network` for his 2026-04-22 game, but catcher reports for the same game still rendered video.

## Table 1: `Astros.Video_Network` (the one everyone knows)

- Columns: `sched_id`, `pitch_id`, `angle` (CHAR, e.g. `'V'`, `'A'`, `'M'`, `'5'`, `'G'`, `'E'`), `video_url`
- Used by: **Barrelsville** (hitting postgame), **Arm Farm** (pitcher postgame, bullpen, LVA), **Intangibles OF/IF/BR** (weekly, individual, daily, tracker)
- Fallback pattern: nested `ISNULL(vn_V.video_url, ISNULL(vn_A.video_url, ...))`
- Query file examples:
  - `barrelsville/src/video.py`
  - `bullpen-report/src/video.py`
  - `intangibles/src/br_data.py` (`_MLB_VIDEO` / `_MILB_VIDEO` constants + `_build_isnull`)
  - `intangibles/src/of_weekly_data.py`, `if_weekly_data.py`
- RND ingestion of a specific angle into this table can miss. Confirmed gap: V angle was NOT pushed for Thomas's 2026-04-22 game despite A/M/F/G/E/H all present.

## Table 2: `Astros.Video` (catcher reports only)

- Columns: `sched_id`, `pitch_id`, `angle_id` (INT, e.g. `1` = primary), `video_url`
- Used by: **Intangibles catcher reports only** (`intangibles/src/catcher_data.py`)
- Query pattern:
  ```sql
  LEFT JOIN Astros.Video vid
      ON vid.sched_id = pv.sched_id
     AND vid.pitch_id = pv.pitch_id
     AND vid.angle_id = 1
  ```
- This table populates independently. On the 2026-04-22 game where Video_Network was missing V, this table had data — that's why catcher reports still worked.

## Why this matters

When a user says "video is broken for [app]" and another says "video works for catcher", they may be hitting two different tables. Debug the specific table first, don't assume Video_Network covers everything.

## Open questions

1. What does `angle_id = 1` map to? (Is it a consistent angle like "primary broadcast"? Is there an angle_id = 2, 3, etc. for other perspectives?)
2. Is `Astros.Video` ingested by a different RND pipeline than `Astros.Video_Network`? (Seems so — they populate independently.)
3. Could we use `Astros.Video` as a fallback for the other apps when `Video_Network` has gaps? Would need to confirm coverage for MiLB / older games.
4. Is `Astros.Video` the "source of truth" that `Astros.Video_Network` is pivoted from? Or are they fully independent?

## How to diagnose

For any game where one video surface works and another doesn't, run BOTH of these and compare:

```sql
-- Astros.Video_Network: string angle per pitch
SELECT pv.pitch_id, vn.angle, vn.video_url
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Video_Network vn
  ON vn.sched_id = pv.sched_id AND vn.pitch_id = pv.pitch_id
WHERE pv.sched_id = @sched_id AND pv.batter_id = @batter_id;

-- Astros.Video: integer angle_id per pitch
SELECT pv.pitch_id, v.angle_id, v.video_url
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Video v
  ON v.sched_id = pv.sched_id AND v.pitch_id = pv.pitch_id
WHERE pv.sched_id = @sched_id AND pv.batter_id = @batter_id;
```
