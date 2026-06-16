---
name: NEVER rename zzz_ to z_ in slack_channels.csv
description: When adding a z_ channel for a player, ALWAYS add a NEW row. NEVER modify/rename the existing zzz_ row. Both rows must exist — zzz_ is the old channel, z_ is the new channel.
type: feedback
originSessionId: 6e112ece-a6dd-485d-86db-b836478bf5e1
---
NEVER rename a zzz_ channel_name to z_ in slack_channels.csv. Always ADD a separate z_ row.

**Why:** zzz_ and z_ are different Slack channels. zzz_ is the legacy channel, z_ is the new channel. Both are used by different delivery pipelines. Renaming destroys the zzz_ channel mapping.

**How to apply:** When user says "add z_playerName channel GxxxxID", add a NEW row with that z_ channel name and ID. Leave the existing zzz_ row untouched.

**Incident:** Apr 15, 2026 — renamed Cesar Salazar's zzz_ row to z_ instead of adding a new row. Caught and fixed immediately.
