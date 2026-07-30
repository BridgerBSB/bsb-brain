---
paths:
  - "**/*tracker*.py"
  - "**/pages/*.py"
---
# Tracker Save Screen — Browser Print is the Only Working PDF Approach (BLOCKING)

LIVE on all 5 affiliate trackers as of 2026-05-21. The "💾 Save Screen"
button at the bottom of each tracker's sidebar opens the browser's native
print dialog → coordinator picks "Save as PDF" destination → file downloads.

This is the **only working PDF-export approach** we have found after 4
attempts. It has known limitations (browser captures only what's visible
on screen, not virtualized off-screen content). Live with them; the
alternative is "no PDF export at all."

---

## The 4 attempts — what we tried and why each failed

| # | Approach | Result | Why |
|---|---|---|---|
| 1 | **html2canvas + jsPDF** (inside Streamlit component iframe, targeting `window.parent.document`) | Garbage output — white sheet with jumbled text in top-left after 30+ sec capture | html2canvas clones the target node into its own iframe's document. Parent's stylesheets don't transfer to the iframe doc → cloned content has no styles → garbage render. |
| 2 | **window.print()** with @media print CSS hiding sidebar | Looks like the app BUT cut off off-screen rows + columns | Streamlit's `st.dataframe` is canvas-based `glide-data-grid` inside an iframe. The iframe has a fixed height; rows beyond the visible viewport are virtualized OUT of the DOM. Browser print engine snapshots iframes as-is → only DOM-present rows print. **Fixed in v5 by uncapping dataframe heights** so all rows are in DOM. |
| 3 | **Server-side reportlab + plottable** rebuilding the table from the source DataFrame | "Looks like shit, doesn't reflect the page that I was trying to save" (user feedback verbatim) | Server-side re-render is functionally different from the app — different fonts, different layout, different table renderer. Captures everything correctly but UX is wrong. |
| 4 | **HTML popup + auto-print** (open new browser window, write pandas Styler HTML into it, auto-trigger window.print() in popup) | Popup never opened — likely blocked by browser/Connect environment | Same-origin popup blockers on Posit Connect's environment interfered. Even after click-permitted, no popup appeared. |

After 4 attempts, settled on **#2 with uncapped dataframe heights**
because it's the only one that:
- Actually produces a PDF the user accepts
- Looks like the app (browser print captures the rendered Streamlit page directly)
- Works reliably across browsers + Posit Connect deployment

---

## What it does

1. User selects view (filters, columns, display mode) in the tracker
2. User clicks **💾 Save Screen** at bottom of sidebar
3. Page reruns with `_<X>_PDF_FLAG = True` in session_state
4. JS injection at end of page renders (only when flag set) fires:
   - Injects `@media print` CSS hiding Streamlit chrome (sidebar, header, toolbar, footer)
   - Calls `window.parent.print()` → browser opens print dialog
5. Coordinator picks "Save as PDF" destination → file downloads
6. `onafterprint` listener triggers page reload → flag cleared

**Filename** is set via `document.title` before print so most browsers
pre-fill it in the Save dialog:
- `catcher_<seasons>_<levels>_<YYYYMMDD-HHMM>.pdf`
- `br_<seasons>_<levels>_<YYYYMMDD-HHMM>.pdf`
- `of_<seasons>_<levels>_<YYYYMMDD-HHMM>.pdf` / `if_...` (Fielding dispatches both)
- `hitter_<seasons>_<levels>_<YYYYMMDD-HHMM>.pdf`
- `pitcher_<seasons>_<levels>_<YYYYMMDD-HHMM>.pdf`

---

## BLOCKING — never re-cap dataframe heights on tracker pages

Every `st.dataframe(...)` call on a tracker page MUST use `_df_height(n_rows)`
(returns natural height `35 * n_rows + 38`), NOT `min(N, 800)` or any
capped variant.

Capped dataframes virtualize off-screen rows out of the DOM. Browser print
captures only what's IN the DOM at print time. Capped + Save Screen =
truncated output.

**Canonical helper** (identical across all 5 tracker files):

```python
def _df_height(n_rows: int) -> int:
    """Dataframe full natural height — NO cap. Required for Save Screen to
    capture every row. See `rules/tracker-save-screen.md`."""
    return max(35 * int(n_rows) + 38, 100)
```

If a new sub-table is intentionally small (e.g., 7-row HOU breakdown),
the natural height is already small (`35 * 7 + 38 = 283px`) — no cap
needed. Don't reintroduce caps as an "optimization" — they break the
feature.

---

## File touchpoints per tracker (5 places per file)

| Tracker | File | Flag key |
|---|---|---|
| Catcher | `intangibles/src/catching_tracker_page.py` | `_C_PDF_FLAG` |
| BR | `intangibles/src/br_tracker_page.py` | `_BR_PDF_FLAG` |
| Fielding (OF + IF) | `intangibles/src/fielding_tracker_page.py` | `_F_PDF_FLAG` |
| Hitter | `barrelsville/pages/2_Affiliate_Tracker.py` | `_H_PDF_FLAG` |
| Pitcher | `bullpen-report/pages/3_Affiliate_Tracker.py` | `_P_PDF_FLAG` |

Each file has 5 touchpoints:

1. **Module-level helpers** (after imports, before render() or sidebar block):
   - `_<X>_PDF_FLAG` constant
   - `_df_height(n_rows)` — uncapped natural height
   - `_pdf_print_js(filename)` — JS that injects @media print CSS + calls `window.parent.print()`

2. **Sidebar end** (last entry in `with st.sidebar:` block):
   - `st.markdown("---")`
   - `if st.button("💾 Save Screen", ...): st.session_state[_X_PDF_FLAG] = True; st.rerun()`

3. **Every `st.dataframe(...)` call** uses `height=_df_height(len(X))` —
   NEVER `height=min(...)`. Typically 4-5 calls per tracker.

4. **End-of-render() (or end-of-script)** JS injection block:
   ```python
   if st.session_state.get(_X_PDF_FLAG):
       _pdf_fname = f"<tracker>_<seasons>_<levels>_<timestamp>.pdf"
       st.components.v1.html(_pdf_print_js(_pdf_fname), height=0)
   ```

5. **Imports**: `from datetime import datetime` (for the timestamp in filename).

---

## The canonical `_pdf_print_js` payload (byte-identical across 5 files)

Don't drift the JS between files — keep it identical. If you change one,
change all 5. See `slack-channels-sync.md` for the cross-worktree sync
pattern.

```python
def _pdf_print_js(suggested_filename: str) -> str:
    import json as _json
    fname_safe = _json.dumps(suggested_filename)
    return f"""
    <script>
    (function() {{
        const pwin = window.parent;
        const pdoc = pwin.document;
        const style = pdoc.createElement('style');
        style.id = 'bsb-pdf-print-style';
        style.innerHTML = `
            @media print {{
                [data-testid="stSidebar"], [data-testid="stHeader"],
                [data-testid="stToolbar"], [data-testid="stStatusWidget"],
                [data-testid="stDecoration"], header, footer {{
                    display: none !important;
                }}
                section.main, .main {{
                    margin: 0 !important; padding: 0 !important;
                    width: 100% !important; max-width: 100% !important;
                }}
                .main .block-container {{
                    padding: 0.25in !important; max-width: 100% !important;
                }}
                iframe {{
                    page-break-inside: auto !important;
                    height: auto !important;
                    min-height: 0 !important;
                }}
                tr, .stDataFrame {{ page-break-inside: avoid !important; }}
            }}
        `;
        pdoc.head.appendChild(style);
        const origTitle = pdoc.title;
        pdoc.title = {fname_safe}.replace(/\\.pdf$/, '');
        const cleanup = function() {{
            pdoc.title = origTitle;
            const s = pdoc.getElementById('bsb-pdf-print-style');
            if (s) s.remove();
            pwin.removeEventListener('afterprint', cleanup);
            setTimeout(function() {{ pwin.location.reload(); }}, 300);
        }};
        pwin.addEventListener('afterprint', cleanup);
        setTimeout(function() {{ pwin.print(); }}, 200);
    }})();
    </script>
    """
```

---

## Known limitations (be honest about these)

1. **Captures only what's currently on screen.** If the dataframe is tall
   AND uncapped, the whole tall page prints across multiple PDF pages —
   good. But if the user has scrolled horizontally to see hidden columns,
   the print captures wherever the scroll is now. Coordinator must
   scroll the table to show desired columns BEFORE clicking Save Screen.

2. **Sidebar excluded by design.** Filter context (which seasons,
   levels, display mode, etc.) is NOT in the printed output. We hide
   sidebar via @media print CSS. If coordinators need filter context in
   the PDF, they'd need to screenshot the sidebar separately — or we
   add a "filter context" header bar to the main page area (future
   enhancement, not built).

3. **Plotly charts render correctly** because browser print captures
   them as canvas snapshots.

4. **Page reload after print** — clears all transient session state
   (e.g., expanded sub-tabs, scroll position). Filter selections
   persist because they're URL-keyed via Streamlit's session_state +
   widget keys.

5. **First click may need popup permission.** Some browsers prompt the
   first time. After granting, subsequent clicks work.

---

## What NOT to do

- **Don't** add `height=min(..., N)` to any tracker `st.dataframe` call.
  Always `height=_df_height(len(X))`.
- **Don't** drop the `iframe { height: auto !important }` rule from the
  print CSS — it's load-bearing for letting iframes flow at full natural
  height during print.
- **Don't** rename the button to "Save as PDF" — the more honest label
  is "Save Screen" because that's literally what it does (screen
  capture via browser print). User direction 2026-05-21.
- **Don't** try html2canvas, jsPDF, or any browser-side capture library
  again. They fail the same way for the same reason (Streamlit
  iframe-component architecture + virtualized canvas). Documented
  failure modes above.
- **Don't** build a server-side reportlab PDF as a "fallback." The user
  has explicitly rejected this output (attempt #3) because it looks like
  a different report instead of the app.
- **Don't** try opening the styled HTML in a new window (attempt #4).
  Popup blockers on Posit Connect block it silently.
- **Don't** drift the `_pdf_print_js` payload between the 5 files. Keep
  byte-identical. Same discipline as `slack-channels-sync.md` — if you
  change one, sync all 5 in the same commit.
- **Don't** add the button to non-tracker pages without thinking. The
  pattern was built for the tracker leaderboard layout. Other Streamlit
  pages (postgame, KPI weekly, etc.) already have proper server-side
  PDF generators — use those, don't bolt this on.
- **Don't** suggest this as a 1-click solution. It's a 2-click flow
  (Save Screen button → "Save" in browser print dialog). Honest about
  it; coordinators understand.

---

## Cross-worktree sync (this rule file)

This rule lives in **all 4 worktrees**:
- `bsb-resources/.claude/rules/tracker-save-screen.md`
- `bsb-wt-bullpen/.claude/rules/tracker-save-screen.md`
- `bsb-wt-hitting/.claude/rules/tracker-save-screen.md`
- `bsb-wt-intangibles/.claude/rules/tracker-save-screen.md`

When this rule changes, sync all 4 byte-identical in lockstep. See
`slack-channels-sync.md` for the canonical sync mechanics.

---

## Bug history

- **2026-05-21 (this rule shipped)** — User asked for a button that
  saves the current tracker view as a PDF so coordinators stop pinging
  Zac for screenshots. After 4 failed PDF-export attempts (html2canvas /
  window.print / server-side reportlab / HTML popup), settled on
  window.print() with uncapped dataframe heights. Renamed button to
  "Save Screen" per user direction — more honest label. Propagated to
  all 5 affiliate trackers (Catcher, BR, OF, IF, Hitter, Pitcher) in
  one session. Rule documented + synced to 4 worktrees.

  Commit chain across worktrees:
  - `feature/astros-intangibles` `285be707` (Catcher rename) →
    `f560b4c2` (BR + Fielding + uncap)
  - `feature/barrelsville` `3d726f8d` (Hitter + uncap)
  - `feature/bullpen-reports` `013fe27e` (Pitcher + uncap)
  - All 4 worktrees: `tracker-save-screen.md` rule sync commit
    (pending — this one)
