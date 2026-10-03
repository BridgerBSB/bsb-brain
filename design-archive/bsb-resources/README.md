# Player Development Apprentice Handbook

Living markdown source for the apprentice onboarding PDF.

## Build

```bash
cd docs/handbook
make pdf      # produces pd-apprentice-handbook.pdf
make open     # build + open in default PDF viewer (Windows)
make clean    # remove the PDF
```

Requires `pandoc` + `xelatex` (TinyTeX bundles xelatex on Windows). Both
are already installed on the personal laptop:

- pandoc: `C:\Users\Owner\AppData\Local\Pandoc\pandoc.exe`
- xelatex: `C:\Users\Owner\AppData\Roaming\TinyTeX\bin\windows\xelatex.exe`

## File layout

- `template.tex` — xelatex header (Astros navy + orange branding,
  callout boxes, code styling, cover page command). Edit only when
  changing branding or adding new LaTeX commands.
- `Makefile` — chapter list + pandoc invocation. Add new chapters here.
- `SUMMARY.md` — the table-of-contents source for humans (mirrors the
  Makefile chapter order).
- `00-cover.md` … `15-reference.md` — the chapters themselves.
- `assets/` — Astros + affiliate logos, glossary PDFs, screenshots.

## Editing rules

- One chapter per file.
- H1 = chapter title (becomes a chapter break in the PDF).
- H2 = section. H3 = subsection. Don't go deeper than H4.
- Code blocks: triple-fence with the language tag (` ```sql `,
  ` ```python `).
- For BLOCKING / TIP / NOTE callouts, use pandoc fenced-div syntax:

  ```markdown
  ::: blocking
  This is a BLOCKING rule. Don't break it.
  :::

  ::: tip
  Useful pattern.
  :::

  ::: note
  Side comment.
  :::
  ```

- Cross-references: link by relative path
  (`[see Ch 6](06-data-cleaning-canon.md)`) — pandoc rewrites these
  as in-PDF anchors.

## Chapter conventions

- Lead each chapter with a short "what you'll learn" box.
- End each chapter with a "where to look next" pointer to relevant
  rules / files / SQL queries.
- Cite source files with `path/file.py:line` syntax so the reader can
  jump straight to the implementation.

## When to update what

| If you change … | Update … |
|---|---|
| A metric formula in `.claude/rules/gc2-metrics.md` | The matching section in Ch 5 (Metric Catalog) and any worked example in Ch 4 (GC2) |
| A new app page or feature | The relevant app chapter (7-10) and Ch 11 if it's cross-app |
| A new BLOCKING rule | Ch 14 (How To recipes) and the relevant app chapter |
| A new SQL query | Ch 12 (SQL Query Playbook) — at minimum a one-line index entry |

## Versioning

The handbook is a living document. Don't tag versions; just edit on
`main` (or `feature/pd-goals` while in development) and let the
apprentice rebuild the PDF whenever they want a current copy.

## Reading order for the apprentice

If they have one full day before they start, suggested order:

1. Ch 1 (Orientation) — 30 min
2. Ch 2 (Stack & Workflow) — 1 hr
3. Ch 3 (Database Tour) — 2 hr
4. Ch 4 (GC2 & Deviations) — 1 hr
5. Skim Ch 5 (Metrics) — 30 min, then keep handy as reference
6. Read Ch 6 (Data Cleaning) closely — 1 hr
7. Pick ONE app chapter (7-10) most relevant to first task — 1 hr
8. Skim Ch 11-15 in 30 min and bookmark them

About 7 hours of focused reading. The rest of the handbook is reference.
