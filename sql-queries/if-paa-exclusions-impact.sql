-- =============================================================================
-- IF PAA/EO Exclusions Impact Test — before/after per-fielder
-- =============================================================================
-- Purpose: Measure how much each IF fielder's PAA/EO changes under the
-- description-based exclusion rules.
--
-- Exclusion rules (IF only — pos_id IN (3,4,5,6)):
--   GATE: Only act on rows where dcbp.paa < 0 (player is being docked).
--         If paa >= 0 on a matching play, row is left intact.
--
--   Group A — P-primary plays → zero paa AND out_prob AND drv for
--             ALL IF pos_ids (3,4,5,6):
--     "singles on a ground ball to pitcher"
--     "singles on a soft bunt ground ball to pitcher"
--     "deflected by pitcher"
--
--   Group B — 1B missed catch → FLIP PAA SIGN (negative → positive) for
--             pos_ids 4/5/6 only. KEEP 1B (pos_id 3) unchanged.
--             DO NOT zero out_prob. DO NOT zero drv. Credit the scramble.
--     "reaches on a missed catch error by first baseman"
--
-- Output: one row per IF fielder with current vs filtered PAA/EO and delta.
--
-- NOTE: Simplified PAA/EO = SUM(paa) / SUM(out_prob). No paaeo_offset calibration
-- applied — the DELTA is what matters here (offset cancels out).
-- =============================================================================

WITH per_row AS (
    SELECT
        sv.level_code,
        pm.ORG_LK AS org,
        pg.groundcontrol_id AS fielder_gcid,
        p.first_name + ' ' + p.last_name AS fielder_name,
        pg.pos_id,
        dcbp.paa,
        dcbp.out_prob,

        -- Group A flag: pitcher-primary play, gets full row zeroed
        CASE
            WHEN pg.pos_id IN (3,4,5,6)
                 AND dcbp.paa < 0
                 AND (ev.play_by_play LIKE '%singles on a ground ball to pitcher%'
                   OR ev.play_by_play LIKE '%singles on a soft bunt ground ball to pitcher%'
                   OR ev.play_by_play LIKE '%deflected by pitcher%')
                THEN 1
            ELSE 0
        END AS is_zapped_a,

        -- Group B flag: 1B-muff, non-1B IF get PAA sign flipped (credit for scramble)
        CASE
            WHEN pg.pos_id IN (4,5,6)
                 AND dcbp.paa < 0
                 AND ev.play_by_play LIKE '%reaches on a missed catch error by first baseman%'
                THEN 1
            ELSE 0
        END AS is_flipped_b

    FROM Astros.Events_View ev
    INNER JOIN Astros.Schedule_View sv
        ON ev.sched_id = sv.sched_id
    INNER JOIN Astros.Players_Games pg
        ON ev.sched_id = pg.sched_id
        AND pg.pos_id <> 0
    INNER JOIN Astros.Players p
        ON pg.groundcontrol_id = p.groundcontrol_id
    INNER JOIN MLB_eBis.PP_MASTER pm
        ON p.ebis_id = pm.player_id
        AND pm.ORG_LK IS NOT NULL
        AND pm.ORG_LK <> 'boc'
    INNER JOIN Astros.Defense_Combined_By_Pos dcbp
        ON ev.sched_id = dcbp.sched_id
        AND ev.event_id = dcbp.event_id
        AND pg.pos_id = dcbp.pos_id
        AND pg.groundcontrol_id = dcbp.groundcontrol_id
    WHERE sv.year = 2026
      AND sv.sched_type = 'R'
      AND sv.gc2_level_id NOT IN ('14','6','22','8','23')
      AND pg.pos_id IN (3,4,5,6)
      AND dcbp.out_prob IS NOT NULL
)
SELECT
    org,
    CASE WHEN org = 'hou' THEN 1 ELSE 0 END AS is_hou,
    fielder_gcid,
    fielder_name,
    CASE pos_id WHEN 3 THEN '1B' WHEN 4 THEN '2B'
                WHEN 5 THEN '3B' WHEN 6 THEN 'SS' END AS pos,
    COUNT(*)                                 AS n_plays_total,
    SUM(is_zapped_a)                         AS n_plays_zapped_groupA,
    SUM(is_flipped_b)                        AS n_plays_flipped_groupB,

    -- Current (no filter)
    CAST(SUM(paa)      AS decimal(10,3))     AS sum_paa_current,
    CAST(SUM(out_prob) AS decimal(10,3))     AS sum_out_prob_current,
    CAST(
        CASE WHEN SUM(out_prob) > 0
             THEN SUM(paa) / SUM(out_prob)
             ELSE NULL
        END
    AS decimal(8,4))                         AS paa_eo_current,

    -- Filtered
    --   PAA:      Group A → 0, Group B → -paa (flip), else unchanged
    --   OutProb:  Group A → 0, Group B → unchanged, else unchanged
    --   (DRV same logic as OutProb — not in this simplified ratio)
    CAST(SUM(
        CASE
            WHEN is_zapped_a = 1 THEN 0
            WHEN is_flipped_b = 1 THEN -paa
            ELSE paa
        END
    ) AS decimal(10,3)) AS sum_paa_filtered,
    CAST(SUM(
        CASE WHEN is_zapped_a = 1 THEN 0 ELSE out_prob END
    ) AS decimal(10,3)) AS sum_out_prob_filtered,
    CAST(
        CASE WHEN SUM(CASE WHEN is_zapped_a = 1 THEN 0 ELSE out_prob END) > 0
             THEN SUM(
                CASE
                    WHEN is_zapped_a = 1 THEN 0
                    WHEN is_flipped_b = 1 THEN -paa
                    ELSE paa
                END
             ) / SUM(CASE WHEN is_zapped_a = 1 THEN 0 ELSE out_prob END)
             ELSE NULL
        END
    AS decimal(8,4)) AS paa_eo_filtered,

    -- Delta (filtered - current). Positive = fielder's PAA/EO improves.
    CAST(
        CASE WHEN SUM(out_prob) > 0
              AND SUM(CASE WHEN is_zapped_a = 1 THEN 0 ELSE out_prob END) > 0
             THEN (SUM(
                    CASE
                        WHEN is_zapped_a = 1 THEN 0
                        WHEN is_flipped_b = 1 THEN -paa
                        ELSE paa
                    END
                  ) / SUM(CASE WHEN is_zapped_a = 1 THEN 0 ELSE out_prob END))
                - (SUM(paa) / SUM(out_prob))
             ELSE NULL
        END
    AS decimal(8,4)) AS paa_eo_delta,

    -- Diagnostic: PAA amount recovered (Group A) + credited (Group B flip)
    CAST(SUM(CASE WHEN is_zapped_a = 1 THEN paa ELSE 0 END) AS decimal(10,3))
        AS paa_groupA_zapped_sum,   -- negative; we remove these penalties
    CAST(SUM(CASE WHEN is_flipped_b = 1 THEN -2 * paa ELSE 0 END) AS decimal(10,3))
        AS paa_groupB_credit_sum    -- positive; swing = 2 * |paa| (from -paa to +paa)

FROM per_row
GROUP BY org, fielder_gcid, fielder_name, pos_id
HAVING SUM(is_zapped_a) + SUM(is_flipped_b) > 0
ORDER BY
    CASE WHEN org = 'hou' THEN 0 ELSE 1 END,
    ABS(
        CASE WHEN SUM(out_prob) > 0
              AND SUM(CASE WHEN is_zapped_a = 1 THEN 0 ELSE out_prob END) > 0
             THEN (SUM(
                    CASE
                        WHEN is_zapped_a = 1 THEN 0
                        WHEN is_flipped_b = 1 THEN -paa
                        ELSE paa
                    END
                  ) / SUM(CASE WHEN is_zapped_a = 1 THEN 0 ELSE out_prob END))
                - (SUM(paa) / SUM(out_prob))
             ELSE 0
        END
    ) DESC
OPTION (RECOMPILE);

-- =============================================================================
-- USAGE
-- =============================================================================
-- Column guide:
--   n_plays_zapped_groupA   = rows where paa+out_prob+drv all go to 0
--   n_plays_flipped_groupB  = rows where paa sign flips (out_prob/drv stay)
--   paa_groupA_zapped_sum   = negative; total PAA penalty we REMOVED
--   paa_groupB_credit_sum   = positive; total PAA CREDIT we added via sign flip
--                             (equals 2 * |sum of flipped original PAA|)
--
-- Expected pattern per fielder:
--   Most 2B/3B/SS: both Group A zaps AND Group B flips contribute
--   Most 1B:       only Group A zaps (Group B flip skips pos_id=3)
--   HOU Sacco:     expected biggest mover; PAA/EO should improve meaningfully
--
-- Sanity checks:
--   - paa_groupA_zapped_sum must always be <= 0 (we only zero negatives)
--   - paa_groupB_credit_sum must always be >= 0 (flipped negatives become positive)
--   - paa_eo_delta must be >= 0 for every fielder (no one gets worse)
--     EXCEPTION: if a fielder had pure Group B flips (no Group A), their
--     delta could be large-positive — the sign flip is a 2x swing
-- =============================================================================
