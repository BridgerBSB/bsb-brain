-- ============================================================================
-- BAT SPEED AT CONTACT — Refactor Validation (Apr 26 2026)
-- ============================================================================
-- Purpose: Sanity check the new SCV-derived at-contact bat speed against
--          publicly known MLB benchmark (~71.5 mph from Savant 2024).
--
-- Pipeline mirrors what the apps now compute:
--   * Source: groundcontroltracking.tracking.swing_contact_values via plays
--   * Formula: SQRT(batvx² + batvy² + batvz²) * 0.681818 = mph
--   * Cleaning per data-cleaning.md §3:
--       Step 1 — Top 90% per player (drop bottom 10%)
--       Step 2 — Hard floor 57 mph (no upper cap)
--       Step 3 — 2.5σ per-player trim   (skipped here — Python-side in app;
--                                         omission produces ~0.2 mph noise vs
--                                         displayed values; acceptable for
--                                         league-aggregate sanity)
--   * Min 20 contact rows per batter
--
-- If MLB pool reads ~70-73 mph: ✅ refactor is sound.
-- If outside that band:          ❌ inspect SQL leaks, JOIN keys, level filter.
-- ============================================================================

DECLARE @season int = 2026;   -- swap to 2025 if 2026 sample too thin

-- ----------------------------------------------------------------------------
-- Stage 1: Per-pitch contact-event speed pool, MLB only, regular season
-- ----------------------------------------------------------------------------
WITH contact_events AS (
    SELECT
        pv.batter_id,
        SQRT(POWER(scv.batvx_con, 2)
           + POWER(scv.batvy_con, 2)
           + POWER(scv.batvz_con, 2)) * 0.681818 AS bat_speed_mph
    FROM Astros.Pitches_View pv
    JOIN groundcontroltracking.tracking.plays tp
        ON tp.sched_id = pv.sched_id
       AND tp.astros_pitch_id = pv.pitch_id
    JOIN groundcontroltracking.tracking.swing_contact_values scv
        ON scv.sched_id = tp.sched_id
       AND scv.tracking_play_id = tp.tracking_play_id
    JOIN Astros.Schedule_View sv
        ON pv.sched_id = sv.sched_id
    WHERE sv.level_code = 'mlb'
      AND sv.year = @season
      AND sv.sched_type = 'R'
      AND scv.batvx_con IS NOT NULL
      AND pv.pitch_id > 0
),
-- ----------------------------------------------------------------------------
-- Stage 2: Per-player p10 cutoff (Step 1 — competitive swings filter)
-- ----------------------------------------------------------------------------
player_p10 AS (
    SELECT DISTINCT
        batter_id,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY bat_speed_mph)
            OVER (PARTITION BY batter_id) AS p10_cutoff,
        COUNT(*) OVER (PARTITION BY batter_id) AS n_contacts
    FROM contact_events
),
-- ----------------------------------------------------------------------------
-- Stage 3: Apply Step 1 + Step 2 (top 90% + 57 mph floor)
-- ----------------------------------------------------------------------------
cleaned_events AS (
    SELECT
        ce.batter_id,
        ce.bat_speed_mph
    FROM contact_events ce
    JOIN player_p10 pp ON pp.batter_id = ce.batter_id
    WHERE ce.bat_speed_mph >= pp.p10_cutoff
      AND ce.bat_speed_mph >= 57
      AND pp.n_contacts >= 20         -- min 20 raw contact rows per player
),
-- ----------------------------------------------------------------------------
-- Stage 4: Per-player average (the unit aggregated into the pool)
-- ----------------------------------------------------------------------------
per_player AS (
    SELECT
        batter_id,
        AVG(bat_speed_mph) AS avg_bat_speed_mph,
        COUNT(*)           AS n_clean_contacts
    FROM cleaned_events
    GROUP BY batter_id
    HAVING COUNT(*) >= 5              -- min 5 after cleaning
)

-- ============================================================================
-- RESULT 1: MLB pool aggregate (the headline number — should land near 71.5)
-- ============================================================================
SELECT
    @season                                  AS season,
    'mlb'                                    AS level,
    COUNT(*)                                 AS n_qualified_batters,
    CAST(AVG(avg_bat_speed_mph) AS decimal(5,2)) AS pool_mean_bat_speed_mph,
    CAST(STDEV(avg_bat_speed_mph) AS decimal(5,2)) AS pool_stdev_bat_speed_mph,
    CAST(MIN(avg_bat_speed_mph)  AS decimal(5,2)) AS slowest_qualified,
    CAST(MAX(avg_bat_speed_mph)  AS decimal(5,2)) AS fastest_qualified
FROM per_player;

-- ============================================================================
-- RESULT 2: Top 25 individual batters (sanity check — Stanton/Judge/Sanchez
--           archetypes should appear here at ~78-82 mph; if they're missing or
--           values look off, JOIN keys or level filter are wrong)
-- ============================================================================
WITH contact_events AS (
    SELECT pv.batter_id,
           SQRT(POWER(scv.batvx_con,2) + POWER(scv.batvy_con,2)
              + POWER(scv.batvz_con,2)) * 0.681818 AS bat_speed_mph
    FROM Astros.Pitches_View pv
    JOIN groundcontroltracking.tracking.plays tp
        ON tp.sched_id = pv.sched_id AND tp.astros_pitch_id = pv.pitch_id
    JOIN groundcontroltracking.tracking.swing_contact_values scv
        ON scv.sched_id = tp.sched_id AND scv.tracking_play_id = tp.tracking_play_id
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE sv.level_code = 'mlb' AND sv.year = @season AND sv.sched_type = 'R'
      AND scv.batvx_con IS NOT NULL AND pv.pitch_id > 0
),
player_p10 AS (
    SELECT DISTINCT batter_id,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY bat_speed_mph)
            OVER (PARTITION BY batter_id) AS p10_cutoff,
        COUNT(*) OVER (PARTITION BY batter_id) AS n_contacts
    FROM contact_events
)
SELECT TOP 25
    p.first_name + ' ' + p.last_name AS batter,
    pp.batter_id,
    pp.n_contacts,
    CAST(AVG(ce.bat_speed_mph) AS decimal(5,2)) AS avg_bat_speed_mph
FROM contact_events ce
JOIN player_p10 pp ON pp.batter_id = ce.batter_id
LEFT JOIN Astros.Players p ON p.groundcontrol_id = pp.batter_id
WHERE ce.bat_speed_mph >= pp.p10_cutoff
  AND ce.bat_speed_mph >= 57
  AND pp.n_contacts >= 20
GROUP BY p.first_name, p.last_name, pp.batter_id, pp.n_contacts
HAVING COUNT(*) >= 5
ORDER BY avg_bat_speed_mph DESC;

-- ============================================================================
-- OPTIONAL — RESULT 3: GC2-canonical comparison (BIP-only filter)
-- Uncomment the WHERE clause line in Stage 1 to restrict to BIP only:
--    AND pv.pitch_result_id IN (12, 13, 14, 18, 19, 20)
-- Should produce a slightly higher pool mean (fouls drag avg down — defensive
-- 2K fouls especially). Documents the GC2-vs-Astros divergence.
-- ============================================================================

-- ============================================================================
-- TROUBLESHOOTING — if pool mean reads outside ~70-73 mph:
--   < 57 mph    → Cap leak: someone left `<= 87` somewhere (unlikely now), or
--                 0.681818 conversion missing (data is in FPS not MPH)
--   57-65 mph   → Floor leak: bottom-10% trim not applied per-player; many
--                 check swings dragging avg (57 mph floor too permissive)
--   65-70 mph   → Sample skew: 2026 too early; try @season = 2025 (full year)
--   73-78 mph   → Foul filter wrong: BIP whitelist accidentally still active
--                 (would be GC2-canonical, not Astros standard)
--   > 78 mph    → JOIN bug: pulling wrong rows; check JOIN keys character-
--                 for-character against pd-goals/src/percentiles.py:1768-1776
-- ============================================================================
