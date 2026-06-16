---
name: sandro-pereira-gcid-fix
description: "Sandro Pereira's slack_channels.csv row uses gc_id 179059, NOT the 212486 baked into his channel names. Do NOT \"correct\" the mismatch."
metadata: 
  node_type: memory
  type: project
  originSessionId: 80d99e25-f921-487d-b79d-9d0ec72cb30c
---

## The mismatch is intentional

`slack_channels.csv` row for Sandro Pereira (May 14 2026 fix `b464288`):

```
179059,Sandro Pereira,zzz_pereira_sandro_212486,zzz_pereira_sandro_21-...@astros.org.slack.com,C03S2DWAG2J,coach,C04K8FKQPJB
```

- `groundcontrol_id` column = **179059** (correct, verified against `Astros.Players`)
- `channel_name` column suffix = **_212486** (cosmetic Slack label, frozen)
- `channel_id` C03S2DWAG2J = zzz channel
- `z_channel_id` C04K8FKQPJB = z channel

## Why: Channel names are frozen labels

The channel was originally created in Slack with `_212486` in the name
because at the time (Feb 5 2026 import) the importer guessed that
suffix was Sandro's gc_id — turned out to be his ebis_id or a stale
id. Renaming the Slack channel would break any links coaches have
saved, so the channel name stays as-is and only the CSV gc_id column
is corrected.

## Why: 179059 is the real gc_id

`Astros.Players WHERE last_name='Pereira' AND first_name='Sandro'`
returned 3 rows:
- **179059** (ebis_id 829824, mlbam_id 808014, DOB 2005-09-30, B/T: S/R) ← REAL
- -1147473 (NULL metadata) — tracking stub
- -1124108 (NULL metadata) — tracking stub

## How not to break this

- **DON'T** swap 179059 back to 212486 because the channel names say `_212486`. They're independent.
- **DON'T** rename the Slack channels to use `_179059` (would break coach bookmarks; no benefit since gc_id column is the routing key).
- **DO** preserve the mismatch on any future audit / cleanup of `slack_channels.csv`.

## Sibling players potentially affected

The Feb 5 2026 import commit `861410d` warned:
*"IDs extracted from channel names (may be groundcontrol_id or ebis_id — needs verification against roster."*

So OTHER players may also have stale gc_ids matching their channel
name suffix but NOT matching their real `Astros.Players` row. Sandro
is the only one caught so far. Symptom to watch for: a specific
player whose PDF delivery silently fails while siblings work.

## Cross-references

- Fix commit: `b464288` (`feature/pd-goals`) + worktree syncs
  `8793412` / `336a42a` / `7f2c70a`
- Rule: `.claude/rules/slack-channels-sync.md` → "Channel name suffix ≠ gc_id" section (May 14 2026)
- Detection SQL: `Astros.Players` name lookup template in that rule
