---
name: feedback-pdf-last-in-streamlit
description: PDF generation MUST be the LAST block in any Streamlit page script. Spinner above main content blocks the entire page paint until PDF render completes.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 80d99e25-f921-487d-b79d-9d0ec72cb30c
---

When working on ANY Streamlit page (`pages/*.py` in any of the 4 worktrees), the `with st.spinner("Generating PDF...")` + `generate_*_report(...)` + `st.download_button(...)` block MUST sit AFTER all main-flow `st.plotly_chart` / `st.dataframe` / `st.tabs` / `st.columns` calls in the same logical scope.

**Why:** Streamlit runs page scripts top-to-bottom. A spinner mid-script blocks paint of every widget below it until PDF rendering completes (5–30s of blank screen on player switch). User caught this May 14, 2026 on Arm Farm postgame — every interaction made him wait through the spinner before any data appeared. The canonical good pattern was already in `barrelsville/pages/5_KPI_Report.py:437` (`# --- PDF Download (charts first, PDF last — user sees data immediately) ---`) but other pages drifted.

**How to apply:**
1. When writing a NEW Streamlit page that includes a PDF download, put the PDF-gen block at the END of the relevant scope (end of `with tab1:`, or just before the footer in single-page modules).
2. Include the canonical comment block above the PDF gen so the next agent sees the intent:
   ```python
   # =====================================================================
   # PDF Download (charts first, PDF last — user sees data immediately)
   # See .claude/rules/pdf-last-in-script.md
   # =====================================================================
   ```
3. When AUDITING an existing page, don't trust "% through file" as a verdict — check whether each `with st.spinner(...)` is gated by:
   - `if st.button(...)` / `if st.sidebar.button(...)` → user-triggered, NOT a violator (the spinner only runs on click)
   - `if st.session_state.get(_fp) != _fp:` (fingerprint auto-gen) → eager regeneration, IS a violator if main content renders below
4. The relocated block must NOT depend on variables defined below the new location. Specifically, any "shared data prep" (arm angle dicts, sidebar selection mirrors) that's read by in-page charts should STAY in its original location near the top; only the actual `with st.spinner(...) + generate_*_report() + download_button` portion moves down.
5. Full rule: `.claude/rules/pdf-last-in-script.md`. Reference impl: `barrelsville/pages/5_KPI_Report.py:437`. Bug history: see `.claude/rules/.graduation-log.md` 2026-05-14 entry.

**Audit recipe** before claiming a new Streamlit PDF page is "done":
```bash
spinner_line=$(grep -n 'with st.spinner.*Generating PDF' pages/<page>.py | head -1 | cut -d: -f1)
sed -n "$((spinner_line - 10)),$((spinner_line))p" pages/<page>.py
# Confirm the spinner is gated by st.button() OR sits below all main content
```

**Pairs with:**
- [[never-round-until-display]] — similar "do X last" rule for display-layer concerns
- [[in-app-submission]] — Transition Report's form-submit pattern; same script-order rule applies (validate + render + submit handler last after sidebar/preview)
