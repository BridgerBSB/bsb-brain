---
paths:
  - "**/slack_channels.csv"
  - "**/deliver*.py"
---
# Slack Channels CSV — Cross-Worktree Sync (BLOCKING)

When adding, editing, or removing rows in `slack_channels.csv`, you
MUST update ALL FIVE copies across ALL FOUR worktrees in the same
operation. Skipping any copy creates silent drift.

---

## Why this rule exists

**May 5, 2026 incident.** While adding 3 new player channel rows the
user asked to be propagated "to all worktrees," the
`intangibles/data/slack_channels.csv` copy was discovered to be **7
rows behind** the canonical `pd-goals/data/slack_channels.csv` — and
also carrying a stale `Cesar Salazar` row in the OLD single-row format
that the canonical had since split into separate `zzz_` + `z_` rows.

**Why nobody caught it:** `intangibles/src/deliver.py:47-49` checks the
**canonical FIRST** and only falls back to the intangibles-internal
copy if the canonical is missing:

```python
csv_path = Path(__file__).parent.parent.parent / 'pd-goals' / 'data' / 'slack_channels.csv'
if not csv_path.exists():
    csv_path = Path(__file__).parent.parent / 'data' / 'slack_channels.csv'
```

In normal operation the canonical IS always present in the worktree,
so the fallback never fires at runtime, so the drift was invisible
until somebody diffed the files.

`barrelsville/src/deliver.py` and `bullpen-report/src/deliver.py` have
the same fallback pattern but never created an internal copy, so
they're not at risk.

---

## All 5 file copies that must stay in sync

| Path | Worktree | Branch |
|---|---|---|
| `pd-goals/data/slack_channels.csv` | `bsb-resources` | `feature/pd-goals` |
| `pd-goals/data/slack_channels.csv` | `bsb-wt-bullpen` | `feature/bullpen-reports` |
| `pd-goals/data/slack_channels.csv` | `bsb-wt-hitting` | `feature/barrelsville` |
| `pd-goals/data/slack_channels.csv` | `bsb-wt-intangibles/astros-intangibles` | `feature/astros-intangibles` |
| `intangibles/data/slack_channels.csv` | `bsb-wt-intangibles/astros-intangibles` | `feature/astros-intangibles` (INTERNAL FALLBACK — must mirror canonical) |

Verify with:

```bash
wc -l \
  /c/Users/Owner/bsb-resources/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-bullpen/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-hitting/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-intangibles/astros-intangibles/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-intangibles/astros-intangibles/intangibles/data/slack_channels.csv
```

All five line counts MUST match after any edit.

---

## Update workflow (BLOCKING — every step required)

1. **Identify all rows to add / modify / remove.**
2. **Apply the change to ALL 5 files in the same operation.** Use
   `printf` + bash loop, NOT one-at-a-time editing — easy to miss the
   intangibles-internal copy.
3. **Preserve CRLF line endings.** The files use Windows line endings
   (`\r\n`). When appending via `printf`, use `\r\n` not `\n`. Verify
   with `tail -c 80 <file> | xxd | tail -3` if unsure.
4. **Verify line counts match across all 5 copies.**
5. **Commit + push on each worktree's feature branch.** Four commits,
   four pushes — one per branch.

### Reference: the canonical add operation

```bash
for f in \
  /c/Users/Owner/bsb-resources/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-bullpen/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-hitting/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-intangibles/astros-intangibles/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-intangibles/astros-intangibles/intangibles/data/slack_channels.csv; do
  printf '<gc_id>,<Player Name>,<channel_name>,,<channel_id>,coach,\r\n' >> "$f"
done
```

---

## Companion rules (BLOCKING context)

- `feedback_slack_channels_zzz_z.md` — NEVER rename `zzz_` to `z_` in
  slack_channels.csv. Always ADD a new `z_` row alongside an existing
  `zzz_` row (or vice versa).
- `pd-goals.md` — `data/slack_channels.csv` is the canonical channel
  mapping; "also used by ALL projects for player ID lookups."
- `delivery.md` — channel routing references this CSV; new channel
  rows must match the canonical schema:
  `groundcontrol_id, player_name, channel_name, channel_email, channel_id, channel_type, z_channel_id`.

---

## What NOT to do

- **Don't edit only the worktree you're currently on.** ALL FIVE files
  must get the change. The two-finger keyboard shortcut for "I'll fix
  the others later" guarantees drift.
- **Don't skip the intangibles-internal copy** because "it's just a
  fallback." If anyone removes pd-goals/ from a deployment bundle, the
  stale fallback kicks in and channels route to wrong / missing IDs.
- **Don't trust that runtime tests will catch drift** —
  `intangibles/data/slack_channels.csv` is a fallback that's never
  reached at runtime under current deploys, so drift in it is silent.
- **Don't introduce a SIXTH copy of this CSV anywhere.** Five copies
  is already too many; adding more compounds the sync problem
  geometrically.
- **Don't rename `zzz_` to `z_` (or vice versa).** Per
  `feedback_slack_channels_zzz_z.md`, ADD a new row instead. Renaming
  destroys delivery routing for code paths that key on the old
  channel_name.
- **Don't drop CRLF line endings on append.** The files are CRLF; mixed
  line endings will pass the `wc -l` check but can break downstream
  CSV parsers and `git diff` will show the whole file as touched.
- **Don't commit only one worktree** and tell yourself you'll do the
  rest tomorrow. Fix all four worktrees in the same session or open a
  TaskCreate to track the partial state.

---

## Long-term consolidation (deferred)

Two cleaner architectures exist; neither is shipped today:

1. **Delete `intangibles/data/slack_channels.csv`** entirely + remove
   the fallback path from `intangibles/src/deliver.py:49`. The fallback
   has never fired at runtime under any deploy we've ever run. Doing
   this drops the rule from FIVE files to FOUR, eliminating one drift
   surface.
2. **Publish the CSV to a Posit Connect pin** (same pattern as
   `pd_goals_data` and the tracker pins, see `tracker-parquet-pins.md`).
   All four apps read from one shared pin instead of four worktree
   copies. Eliminates the cross-worktree drift problem entirely.

Until either ships, this BLOCKING rule stands.

---

## Channel name suffix ≠ gc_id (BLOCKING — May 14 2026)

The CSV's `channel_name` field (e.g., `zzz_pereira_sandro_212486`) is a
**cosmetic Slack label**, not a routing key. Slack delivery uses the
`channel_id` column (`C03S2DWAG2J` etc.). The script's player-to-channel
lookup uses the `groundcontrol_id` column. **The numeric suffix in the
channel_name is whatever id was used WHEN THE CHANNEL WAS CREATED — it
can be stale.**

### What happened to Sandro Pereira

His row was originally keyed on gc_id `212486` — a stale value inherited
from the Feb 5 2026 import (`861410d`) whose commit message explicitly
warned: *"IDs extracted from channel names (may be groundcontrol_id or
ebis_id — needs verification against roster."* His real gc_id per
`Astros.Players` is `179059`. The channels themselves are named
`_212486` because that's what the Slack channel creator used.

After a roster refresh pushed Sandro's real gc_id through the postgame
script, `parse_gc_id_from_filename` started returning `179059` from
filenames like `Pereira_Sandro_2026-05-14_179059_Postgame.pdf`. The CSV
keyed on `212486` no longer matched → lookup fell through → delivery
silently dropped. Symptom: "it used to send to his zzz channel, now it
sends to neither."

Fix in commit `b464288` (+ 3 worktree syncs): one-byte edit, swap
`212486` → `179059` in the gc_id column. Channel name + channel IDs
left exactly as-is.

### How to spot this class of bug

If a player's PDF delivery silently fails BUT:
1. His row exists in the CSV with both channel IDs populated
2. The Slack bot is confirmed in his channels
3. Other players in the same CLI run deliver normally

→ **Suspect stale gc_id in his CSV row.** Verify via:
```sql
SELECT groundcontrol_id, ebis_id, mlbam_id, first_name, last_name,
       birthdate, bats, throws
FROM Astros.Players
WHERE last_name LIKE '<last>%' AND first_name LIKE '<first>%'
ORDER BY groundcontrol_id;
```
The row with full metadata (non-null `ebis_id` + `mlbam_id` +
`birthdate`) is the real player. Negative gc_ids are tracking stubs;
ignore them. If the result's gc_id differs from the CSV row's gc_id,
swap the CSV gc_id (only that field) and sync across all 5 copies.

### How to NEVER break Sandro's fix

When auditing `slack_channels.csv`, do NOT "correct" rows where the
`channel_name` numeric suffix doesn't match the `groundcontrol_id`
column. That mismatch is intentional for at least Sandro and possibly
others — the channel names are frozen in Slack (renaming them would
break links coaches have saved), while the gc_id column tracks the
real player.

**Currently known mismatches (do NOT swap back):**

| gc_id (correct) | channel_name suffix | Player | Notes |
|---|---|---|---|
| 179059 | _212486 | Sandro Pereira | Stale Slack channel label |
| 254779 | _284157 | Hector Salas | ONLY duplicate-row player with mismatched gc_ids. Fixed May 19 2026 across all 5 CSV copies. zzz channel `zzz_salas_hector_284157` preserved. |

If more get discovered, add them here in the same commit so future
audits leave them alone.

## Bug history

- **May 5, 2026** — User asked to add 3 player channel rows "to all
  worktrees." Discovery: intangibles-internal copy was 7 rows behind
  canonical, plus carrying 1 stale Salazar row in the deprecated
  single-row format. Fixed by byte-copying the canonical (in the same
  worktree) over the stale fallback. This rule was created to prevent
  the next occurrence.
