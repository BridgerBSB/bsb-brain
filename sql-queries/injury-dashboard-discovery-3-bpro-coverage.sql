-- ============================================================
-- INJURY DASHBOARD — discovery round 3: is Injury_Data_BPro CURRENT + league-wide?
-- ============================================================
-- Round-2 found SportsMed.Injury_Data_BPro = a full BP injury ledger
-- (body_part, side, injury, severity, days, games, date_on/off, surgery,
-- reaggravation), keyed on groundcontrol_id. Samples were all pre-2005
-- (physical row order only). This decides whether BPro becomes the PRIMARY
-- source (re-base the app on it) or stays a historical/body-part enrichment
-- alongside TR_HISTORY for the current season.
--
-- THE DECIDERS:
--   (a) Does it have 2024/2025/2026 rows? (recency)
--   (b) How many distinct players + orgs per recent season? (league-wide?)
--   (c) Are body_part / injury / side populated on RECENT rows? (not just old)

-- ============================================================
-- §1 — Row volume by year (recency) — last 15 years
-- ============================================================
SELECT YEAR(date_on) AS yr,
       COUNT(*)                     AS n_records,
       COUNT(DISTINCT groundcontrol_id) AS n_players,
       SUM(CASE WHEN body_part IS NOT NULL AND body_part <> '' THEN 1 ELSE 0 END) AS n_with_bodypart,
       SUM(CASE WHEN date_off IS NULL THEN 1 ELSE 0 END) AS n_open
FROM SportsMed.Injury_Data_BPro
WHERE date_on >= '2011-01-01'
GROUP BY YEAR(date_on)
ORDER BY yr DESC;

-- ============================================================
-- §2 — Org spread for recent seasons (league-wide check)
-- ============================================================
-- BPro has no org column — derive org from the player's team at date_on via
-- TR_HISTORY POST_ORG_LK is heavy; simplest league-wide proxy = distinct
-- players that also appear in MLBAM this season. Quick proxy: just confirm
-- the player pool is large + maps to Astros.Players (league-wide ids).
SELECT TOP 30
       b.groundcontrol_id,
       a.first_name + ' ' + a.last_name AS player,
       COUNT(*) AS n_injuries_2024plus
FROM SportsMed.Injury_Data_BPro b
LEFT JOIN Astros.Players a ON a.groundcontrol_id = b.groundcontrol_id
WHERE b.date_on >= '2024-01-01'
GROUP BY b.groundcontrol_id, a.first_name, a.last_name
ORDER BY n_injuries_2024plus DESC;

-- ============================================================
-- §3 — Recent sample (eyeball body_part/injury/side populated NOW)
-- ============================================================
SELECT TOP 40
       b.groundcontrol_id,
       a.first_name + ' ' + a.last_name AS player,
       b.date_on, b.date_off, b.trans, b.days, b.games,
       b.side, b.body_part, b.injury, b.severity,
       b.surgery_date, b.reaggravation
FROM SportsMed.Injury_Data_BPro b
LEFT JOIN Astros.Players a ON a.groundcontrol_id = b.groundcontrol_id
ORDER BY b.date_on DESC;

-- ============================================================
-- §4 — body_part + injury value distributions (for the body-map buckets)
-- ============================================================
SELECT body_part, COUNT(*) AS n
FROM SportsMed.Injury_Data_BPro
WHERE date_on >= '2020-01-01'
GROUP BY body_part
ORDER BY n DESC;

SELECT injury, COUNT(*) AS n
FROM SportsMed.Injury_Data_BPro
WHERE date_on >= '2020-01-01'
GROUP BY injury
ORDER BY n DESC;

-- ============================================================
-- HOW TO REPORT BACK
-- ============================================================
-- §1 is the decider: if 2024/2025/2026 have real row counts with
--   n_with_bodypart populated -> BPro becomes PRIMARY (re-base the app:
--   body-map + stored days/games + diagnosis + recurrence, all 30 orgs).
-- If recent years are empty/sparse -> BPro is historical-only; keep
--   TR_HISTORY stints for current season + use BPro for body-part enrichment.
-- Paste §1 in full + a few §3 recent rows + the §4 distributions.
