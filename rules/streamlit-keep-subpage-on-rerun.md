# Streamlit: Changing the Sidebar Must KEEP You on the Same Tab/Subpage

**BLOCKING UX rule.** In any Streamlit app, when the user changes a sidebar
widget (dates, level, player, toggles), the app reruns top-to-bottom — and they
must **stay on the tab/sub-view they were on.** Getting kicked back to the first
tab on every sidebar change is unacceptable (Zac, 2026-06-17, on the postgame
Visuals tab snapping back to the report when dates changed).

---

## The gotcha

`st.tabs([...])` does **NOT** persist the active tab across reruns. Every rerun
(any widget change anywhere, including the sidebar) resets the tab group to the
**first** tab. So a user on "Visuals" who picks new dates gets thrown back to
"Postgame Report." This is `st.tabs` behavior, not a bug you can configure away.

## The fix — a keyed selector + `if` blocks (NOT st.tabs)

Replace the tab group with a **keyed widget** (state persists in `session_state`
via the `key`), and gate each view with an `if`:

```python
_view = st.radio("View", ["Postgame Report", "Visuals"],
                 horizontal=True, key="pg_view", label_visibility="collapsed")

if _view == "Postgame Report":
    ...   # report rendering

if _view == "Visuals":
    ...   # visuals rendering
```

Because the radio has a `key`, its value survives reruns → the user stays put.
(`st.segmented_control` with a `key` works the same way if you want a tab-y look.)

### Required: shared vars must be defined BEFORE the selector
With `st.tabs`, both `with tab:` bodies execute every run, so a later view could
lean on a variable assigned inside an earlier view's body. With `if` blocks, only
the selected view runs — so **any variable used by more than one view must be
computed ABOVE the selector** (data load, sidebar, selected ids, height, filtered
frames). Verify this before converting, or the non-default view throws `NameError`.
Heavy per-chart reruns (click-to-video) should still be scoped with `@st.fragment`.

---

## Reference impl

`barrelsville/pages/1_Postgame.py` — `_view = st.radio(..., key="pg_view")` then
`if _view == "Postgame Report":` / `if _view == "Visuals":`. Shared vars
(`selected_gc_id`, `_batter_height`, `filtered_pitch_df`) are all defined before
the selector. Converted from `st.tabs` 2026-06-17.

---

## What NOT to do

- **Don't** use `st.tabs` for a view switch on a page that has sidebar inputs —
  it resets on every rerun.
- **Don't** rely on a variable assigned inside one `if`-view block from another
  view block — hoist shared computation above the selector.
- **Don't** "fix" it by removing the sidebar reactivity — the sidebar SHOULD
  drive the data; the view selection just needs to persist.
- **Don't** forget the `key=` on the selector — without it, state doesn't persist.
