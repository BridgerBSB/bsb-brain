-- Ground the switch to official MLBAM stats for PA/IP. Run + paste back.
SET NOCOUNT ON;

-- A. YTD batting: how is `level` coded? how is `gm_type` coded (regular season)?
SELECT DISTINCT level FROM MLBAM.YTD_Player_Batting_Stats ORDER BY level;
SELECT DISTINCT gm_type FROM MLBAM.YTD_Player_Batting_Stats ORDER BY gm_type;

-- B. Does official YTD match GC2 for Yordan (75884)? Expect DSL=57, A=139, A+=252, etc.
SELECT yb.season, yb.level, yb.gm_type, SUM(yb.pa) AS pa
FROM MLBAM.YTD_Player_Batting_Stats yb
JOIN Astros.Players p ON p.mlbam_id = yb.player_id
WHERE p.groundcontrol_id = 75884
GROUP BY yb.season, yb.level, yb.gm_type
ORDER BY yb.season, yb.level;

-- C. Official pitching season stats columns (for IP).
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='MLBAM' AND TABLE_NAME='YTD_Player_Pitching_Stats'
ORDER BY ORDINAL_POSITION;

-- D. team_id -> org for the YTD rows (confirm the MLBAM.Teams join we already use).
--    (level char from A above tells me if I even need per-game GameLog windowing.)
