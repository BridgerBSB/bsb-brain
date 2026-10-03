/* ============================================================================
   Christian Vazquez gc_id discrepancy check
   ----------------------------------------------------------------------------
   Symptom: catcher postgame keeps delivering Vazquez to the overflow channel
   (pd-automation-test) instead of his zzz coach channel C03SSJMQ6SV.

   Diagnosis: shared/deliver.py resolves z_channel_id -> zzz fallback -> overflow.
   Vazquez HAS a valid zzz channel in slack_channels.csv (gc_id 14727), so he
   should hit the ZZZ FALLBACK. The only way he lands in overflow is if the
   gc_id parsed from his PDF FILENAME != 14727 -- i.e. the catcher report names
   his file with a different groundcontrol_id than the CSV row carries.
   (Same "suffix != gc_id" class as Pereira / Salas in slack-channels-sync.md.)

   The catcher report names PDFs by the catcher's groundcontrol_id (= ev.c_id).
   So the id that actually catches his games IS the id delivery looks up, and
   the CSV must be set to match it.

   Run on the work laptop (DB access). Compare the two result sets.
   ============================================================================ */

-- 1) Identity: every Astros.Players row for Christian Vazquez.
--    The canonical player is the row with full metadata (non-null ebis_id +
--    mlbam_id + birthdate). Negative / metadata-less gc_ids are tracking stubs.
SELECT groundcontrol_id, ebis_id, mlbam_id,
       first_name, last_name, birthdate, bats, throws
FROM   Astros.Players
WHERE  last_name LIKE 'Vazquez%'
  AND  first_name LIKE 'Christ%'
ORDER  BY groundcontrol_id;

-- 2) Activity: which gc_id is ACTUALLY catching games this season.
--    This is the id the catcher report uses in the PDF filename, and therefore
--    the id delivery parses and looks up in slack_channels.csv.
--    -> Whatever c_id this returns is what the CSV gc_id column must equal.
SELECT ev.c_id              AS catcher_gc_id,
       p.first_name, p.last_name,
       COUNT(*)             AS pitches_caught,
       MIN(sv.sched_date)   AS first_game,
       MAX(sv.sched_date)   AS last_game
FROM   Astros.Events_View ev
JOIN   Astros.Schedule_View sv ON sv.sched_id = ev.sched_id
JOIN   Astros.Players p        ON p.groundcontrol_id = ev.c_id
WHERE  p.last_name LIKE 'Vazquez%'
  AND  p.first_name LIKE 'Christ%'
  AND  sv.sched_date >= '2026-01-01'
GROUP  BY ev.c_id, p.first_name, p.last_name
ORDER  BY pitches_caught DESC;

/* Expected outcomes:
   - If (2) returns 14727  -> CSV is already correct; bug is elsewhere
                              (re-check the [OVERFLOW] log line for the parsed id
                               and confirm --z-channel is actually being passed).
   - If (2) returns a DIFFERENT id -> that's the real id. Tell Claude the value;
                              fix = swap the gc_id column on Vazquez's row to it
                              across ALL 5 slack_channels.csv copies, keeping the
                              zzz_vazquez_christian channel_name + C03SSJMQ6SV as-is
                              (per slack-channels-sync.md "channel name suffix != gc_id"),
                              and add Vazquez to the known-mismatches table in that rule. */
