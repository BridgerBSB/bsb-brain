---
paths:
  - "**/pages/*.py"
---
# PDF Generation Goes LAST in Streamlit Page Script (BLOCKING)

In any Streamlit page that builds a PDF, the **PDF-generation block
(`with st.spinner("Generating PDF...")` + `generate_*_report(...)` +
`st.download_button(...)`) MUST sit AFTER all main-flow data display
calls** (`st.plotly_chart`, `st.dataframe`, `st.columns`, `st.tabs`,
`st.pyplot`, etc.).

Streamlit runs page scripts top-to-bottom. The spinner blocks paint of
every widget below it until PDF rendering completes. Putting PDF gen
mid-script forces the user to wait 5–30s of black/loading screen
before any data appears. Putting it at the bottom lets every chart,
table, and KPI card paint immediately — the spinner just chugs quietly
under the already-rendered content.

---

## The antipattern signature

If you can answer YES to any of these for a Streamlit page, the page
is broken:

1. Does `with st.spinner("Generating PDF...")` (or any `with st.spinner(...generating...)`) appear in the file BEFORE the page's primary `st.plotly_chart` / `st.dataframe` / `st.tabs` calls in the same logical scope (same tab block, same conditional)?
2. Does the user have to wait for the spinner to clear before SEEING their selected player's stats / charts / table?
3. Is the spinner positioned in the sidebar setup region or in a "setup-then-render" middle section?

If yes to any → relocate the spinner block to the bottom of the
relevant scope.

---

## The canonical good pattern

From `barrelsville/pages/5_KPI_Report.py` (lines 430–449) — the
reference implementation. **All new Streamlit PDF pages must mirror
this shape:**

```python
# --- All main data rendering happens here ---
table_cols = st.columns([1, 1])
with table_cols[0]:
    _style_player_table(span_df, span_title)
with table_cols[1]:
    _style_player_table(season_df, season_title)

# ... any additional charts / KPI cards / etc.

# --- PDF Download (charts first, PDF last — user sees data immediately) ---
with st.spinner("Generating PDF..."):
    pdf_bytes, pdf_err = _generate_pdf(level_code, start_date_str, end_date_str, season)

if pdf_err:
    st.warning(f"PDF generation failed: {pdf_err}")
elif pdf_bytes:
    st.download_button(
        label="Download Report",
        data=pdf_bytes,
        file_name=f"<name>.pdf",
        mime="application/pdf",
        key="<unique_key>",
    )
```

The comment `# --- PDF Download (charts first, PDF last — user sees data immediately) ---`
is canonical. Keep it on new pages so the next agent reading the file
sees the intent.

---

## Reference implementations (audit benchmarks)

These four pages are confirmed correct as of May 14 2026. When in doubt
about a new page's structure, diff against one of them.

| Page | Spinner line | Lines after spinner | Why it's correct |
|---|---:|---:|---|
| `barrelsville/pages/5_KPI_Report.py` | 437 | 21 | Tables (430–434) render above; spinner near bottom |
| `bullpen-report/pages/5_Pitcher_KPI.py` | 443 | 21 | Mirrors KPI Report pattern |
| `barrelsville/pages/1_Postgame.py` | 1609 | 168 | Lines below = only `with tab2:` Daily Tracker (separate scope, intentional) |
| `intangibles/pages/4_Catching.py` | 1655 | 144 | Lines below = glossary expander only |

---

## The audit recipe (run before any commit touching pages/)

```bash
# Find every PDF-generating spinner across all worktrees
for f in <worktree>/<app>/pages/*.py; do
  spinner_line=$(grep -n 'with st.spinner.*[Gg]enerating PDF' "$f" | head -1 | cut -d: -f1)
  total=$(wc -l < "$f")
  if [ -n "$spinner_line" ]; then
    pct=$((spinner_line * 100 / total))
    echo "$f  spinner@$spinner_line/$total (${pct}%)"
  fi
done
```

If a page's spinner sits below 90% through the file, **read the actual
code** to confirm whether what's below the spinner is:

- **OK** — secondary tab scope (`with tab2:`) / footer / glossary
  expander / nothing
- **BAD** — main-flow charts, tables, plotly_chart, columns with data
  display

Mechanical % alone is a proxy, not a verdict. Always confirm by reading.

---

## The fix recipe (mechanical block relocation)

For each bad page:

1. **Identify the PDF block** — typically a contiguous span of ~50–100
   lines: fingerprint check (optional) → `with st.spinner(...)` → import
   `generate_*_report` → call it → `st.download_button(...)`. Include
   any helper data-fetch calls that exist solely to feed the PDF.

2. **Identify the relocation target** — the very last line of the
   relevant scope (usually `with tab1:` for tab-based pages, or the
   end of the file for single-scope pages, before any glossary
   expander or footer).

3. **Cut + paste the block.** No logic changes. Indentation must
   match the destination scope.

4. **Add the canonical comment** above the relocated block:
   ```python
   # --- PDF Download (charts first, PDF last — user sees data immediately) ---
   ```

5. **Verify** by running the audit recipe locally; spinner should now
   show ≥90% through file AND the lines below it should only be
   secondary-scope code.

6. **Test redeploy.** Pick a player → confirm all charts/tables paint
   immediately, spinner shows last, download button appears within a
   few seconds.

---

## Cross-references

- `barrelsville.md` — Streamlit page structure conventions
- `arm-farm.md` — Arm Farm app architecture
- `intangibles.md` — Intangibles app architecture
- `pd-goals.md` — PD Engine page architecture
- `in-app-submission.md` — separate pattern for form-submit PDFs (Transition Report); same script-order rule applies there too — submission handler runs LAST after all sidebar/preview rendering
- `slack-channels-sync.md` — cross-worktree sync pattern (this rule file must stay in sync across all 4 worktrees)

---

## Cross-worktree sync

This rule file lives in **all 4 worktrees** (`bsb-resources/`,
`bsb-wt-bullpen/`, `bsb-wt-hitting/`, `bsb-wt-intangibles/`). When
the rule changes, update all 4 in the same operation. See
`slack-channels-sync.md` for the sync mechanics — same pattern.

---

## Bug history

- **May 14, 2026** — User caught the antipattern after Arm Farm
  postgame felt slow on every player switch. Audit found 5 violators
  across 3 worktrees (Arm Farm Postgame, Barrelsville Advance,
  Barrelsville Blast Motion, Arm Farm Side Reports, Arm Farm
  Pitching Advance). Rule documented + 5 fixes shipped same session.
  Root cause: copy-paste from older sidebar-driven pages where the
  PDF block lived near the sidebar widgets, not from the canonical
  `5_KPI_Report.py` pattern.

---

## What NOT to do

- **Don't** put `with st.spinner("Generating PDF...")` near the top
  of a tab body or before the page's `st.plotly_chart` /
  `st.dataframe` rendering.
- **Don't** rely on `@st.fragment` to "fix" a misplaced spinner. The
  spinner-position rule is simpler, more reliable, and doesn't
  introduce fragment-state complexity.
- **Don't** assume fingerprint-cached PDF gen makes location
  irrelevant. Cache only skips the FIRST visit's regeneration — the
  block still runs (and renders the spinner) on every fresh page
  selection.
- **Don't** mix the PDF block into a sidebar `with st.sidebar:` scope.
  Sidebar runs before the main flow; PDF gen there blocks the entire
  page paint. Put the download button placeholder in the sidebar if
  needed, but generate + fill it from a block at the bottom of main.
- **Don't** ship a new Streamlit page (or any worktree's pages/ dir)
  without running the audit recipe against your own page first.
- **Don't** drop the canonical comment when refactoring. It's a
  tripwire for future agents.
