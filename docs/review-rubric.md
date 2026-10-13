# Review rubric

Apply this to every PR: the author before opening it, the reviewer after.
Every question is yes or no. A "no" blocks the merge unless the PR body
explains it. The rules behind each question are in `docs/engineering.md` and
`docs/design.md`.

## 1. Coherence: does it fit the design?

- [ ] The PR stays on one line: one app's targets, or SuiteUI, never two?
- [ ] State and logic live in the Model; views only read it and call its
      methods, and `scripts/ci` printed no app-state failure?
- [ ] The Model is Linux-safe (Foundation only, value types, `Sendable`)?
- [ ] Engine work goes through creative-core (and its commands for document
      edits), not a copy inside the Model?
- [ ] Names match the ones already used for the same idea?
- [ ] New files are owned by a C4 component: each new `Sources/` file is in
      exactly one component's `paths` in `docs/c4/model.json`, and that
      component's description still says what it holds?
- [ ] If the line's core loop (open or create, see, edit with each shown tool,
      undo, save) doesn't work end to end yet, does this PR build a missing
      step of it rather than polish or a panel (CLAUDE.md, Journeys first)?

## 2. Duplication: does it reuse what exists?

- [ ] The view is built from SuiteUI, and a missing component became a
      `needs-ui` issue plus a plain placeholder, not a private copy?
- [ ] `scripts/ci` printed no jscpd failure, and the threshold was not raised?
- [ ] No near-copy (same logic, renamed) of code in another app or in SuiteUI?

## 3. Correctness: can it crash or lose work?

- [ ] No crash-prone construct, unchecked index or division by a possible zero?
- [ ] A throwing call is handled, or a comment says why it cannot fail?
- [ ] Document edits are undoable?

## 4. Design: does it follow the HIG rules in docs/design.md?

- [ ] Glass only on controls that float over content; content surfaces flat;
      no glass on glass?
- [ ] Uses the system component when one exists (docs/design.md, Component
      order), and SuiteUI before anything custom?
- [ ] No hand-rolled look-alike of a system control or a SuiteUI component,
      and `scripts/ci` printed no design lint failure?
- [ ] Semantic colors and text styles from SuiteUI tokens; no hard-coded
      color for a system role?
- [ ] Every icon-only control has a tooltip and an accessibility label?
- [ ] Every button, tool and menu item the PR shows does something, or is
      disabled with a tooltip saying why (`unavailableHelp`), and the line's
      `<X>ToolsTests` passes?
- [ ] The new action is reachable from the menu bar or a shortcut, not only a
      toolbar button (or the PR says why not yet)?
- [ ] Both Light and Dark snapshots look right?

## 5. Proof: would we notice a regression?

- [ ] Each Model test asserts a concrete result that would fail if the code
      returned a default value?
- [ ] A bug fix comes with a test that failed before the fix?
- [ ] New visible state has a snapshot, and the PR body lists the PNGs it
      changed?
- [ ] A user-facing feature adds or extends its app's journey test in
      `UITests/<X>JourneyTests.swift`, and the PR body lists the `ui-screens`
      PNGs that show it?
- [ ] Both CI jobs (`Linux`, `macOS`) are green on the rebased branch?
