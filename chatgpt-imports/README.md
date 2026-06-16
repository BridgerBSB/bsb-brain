# ChatGPT Imports

Drop your exported ChatGPT history here and it gets tagged + backlinked into the
graph alongside your rules and memory.

## How to export from ChatGPT

1. ChatGPT → Settings → **Data controls** → **Export data** → confirm.
2. You'll get an email with a `.zip`. Inside is `conversations.json` (every
   chat) plus an HTML viewer.
3. Drop the unzipped folder into `chatgpt-imports/raw/` here.

## What happens on ingest (later step)

A small pass (mirrors the "onboard" pattern from the Eric Tech video) will:

- split `conversations.json` into one markdown note per conversation,
- add frontmatter (date, title, topic tags),
- add `[[wikilinks]]` to related vault notes so old ChatGPT threads connect to
  your current work,
- keep the raw export untouched in `raw/` as the source of truth.

Static/raw exports stay verbatim; long threads get a short summary header so
they're scannable without reading the whole thing.

> Not built yet — this is the next-up ingest step once you've dropped an export
> in. Ping me with the export in `raw/` and I'll wire the conversion.
