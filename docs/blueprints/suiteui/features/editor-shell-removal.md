# Feature packet: editor-shell-removal

**Feature:** once Design and Photo run in `SuiteWindow`, nothing uses
`EditorShell`, `EditorTopBar` (with `EditorBarItem`, `EditorBarMenu` and
`EditorBarDivider`) or `ToolbarGroup`'s `.rail` style. This feature deletes
them, their tests and the tokens only they read, then rewrites
`docs/design.md`'s Editor shell section for the one shell the suite now has.
It is subtraction first, then the docs.
**Line:** `line:suiteui` · **Wave:** 3 (`../../suite/features/shell-parity-waves.md`) · **Lead branch:** `lead/editor-shell-removal`
**Blueprint:** `docs/blueprints/suiteui.md` section 6 (Captain decision
2026-10-15).

**Covers:** the deletion half of the 2026-10-15 decisions. It has no issue
of its own; every PR says "Part of the editor-shell-removal feature".

**Depends on:** the Design shell-parity and Photo shell-parity feature
issues, both closed. Its `Depends on:` line names the Photo one, since that
issue waits on #812 and so closes last, and the body also names the Design
one. Before ER-1 starts, the lead runs
`grep -rn "EditorShell\|EditorTopBar\|EditorBar\|\.rail" Sources Tests UITests`
on its base and records the hits in RECORD.md. The only hits allowed are
the files this packet deletes or edits, plus one historical comment it
leaves alone: `Tests/AppAuditTests/Checks/DisabledDim.swift` names
`EditorBarLabelStyle` as the case that check was written for. Editing a
`Checks/` file is a fast-lane audit trigger, so its comment stays. Any
other hit stops the lead, which comments on the feature issue naming the
file. (Design's and Photo's file headers stopped naming `EditorShell` in
DS-3 and PS-3.)

**The one `docs/design.md` edit** of the shell-parity work is ER-2. No
other shell-parity task touches that file.

## Journey steps

No new journey. The journeys that prove this feature are the ones already
on `dev` once wave 2 is in:

1. [ER-2, ER-J1] Every journey of all five apps runs green on the dev macOS run that ER-2
   (`feature-done`) triggers.
2. [ER-1, ER-J2] `SuiteJourneyTests+EditorWindow` and `SuiteJourneyTests+Parity`
   (editor-in-window) run green and shoot the four tool apps in one shell
   with one tool box.

## Screens and states

Nothing on screen changes, because the deleted code must already be
unused. The PNGs that show it: the `suiteui-launch`, `design-shell-open`,
`photo-shell-open` and `parity-*` journey shots, compared with the previous
green run; `suiteui-editor-shell-light.png` and `-dark.png` go with their
test. `snapshot()` only writes PNGs, so "unchanged" isn't a test: the
lead compares the run's `*-launch.png` shots with the previous green run by
eye and records any difference as a finding. What fails automatically is
the build and every journey.

## Contract slice

Removed from the public API of `SuiteUI`:

```swift
EditorShell, EditorTopBar, EditorBarItem, EditorBarMenu, EditorBarDivider   // Sources/SuiteUI/EditorShell.swift, EditorTopBar.swift
ToolbarGroup.Style (and the `style:` parameter of both inits)                // the floating capsule is the only look
SuiteSize.editorTopBar, .windowControlsInset, .editorBarDivider             // read only by EditorTopBar
SuiteFont.editorBar, .editorTitle                                           // read only by EditorTopBar
Journey.expectEditorShell()                                                 // UITests/Journey.swift
```

`SuiteSize.editorPanelWidth` stays. It is the width of an editor's
inspector content (`SuiteWindow(inspectorWidth:)` in Design and Photo) and
of every inspector snapshot. Its doc comment is reworded to say so.

## Pseudocode

```
ER-1  git rm EditorShell.swift EditorTopBar.swift SuiteEditorShellSnapshots.swift SuiteEditorBarDimmingTests.swift
      ToolbarGroup: drop Style, the `style:` parameters, the rail branch of `body` and `well`; the palette is always the glass capsule
      EditorShellTests: drop `editorShellFitsTheWindowMinimum` (the ruler, zoom and tooltip tests stay); fix the file's header
      Journey.swift: drop expectEditorShell(); Place.window's comment no longer mentions an editor shell
      SuiteEnvironment.swift and Tokens.swift: comments only (Tokens.swift lines 15 and 138 name EditorShell)
ER-2  Tokens.swift: drop the five tokens; reword editorPanelWidth's comment as the editor's inspector content width
      TokensTests: drop the editorTopBar lines; keep the window-minimum check over the columns
      docs/design.md: Editor shell → "Canvas editors" (SuiteWindow + EditorDetail + floating palette + sidebar list + inspector width);
                      Surfaces: every window follows the system appearance; Window structure: no EditorShell alternative;
                      the token rows for the five tokens go
```

## Tasks

Every task is one PR to `dev`, at most 400 changed lines and 15 files, with
the lines `Belt-Lead:`, `Feature: editor-shell-removal`, `Fast-Check: pass`
and `Head:`, and the label `fast-lane`. ER-2 also carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| ER-1 | – | Delete the editor shell, its top bar family, the `.rail` style, their tests and the journey's old launch check | `Sources/SuiteUI/EditorShell.swift` (deleted), `Sources/SuiteUI/EditorTopBar.swift` (deleted), `Sources/SuiteUI/ToolbarGroup.swift`, `Sources/SuiteUI/SuiteEnvironment.swift` and `Sources/SuiteUI/Tokens.swift` (comments only), `Tests/AppSnapshotTests/SuiteEditorShellSnapshots.swift` (deleted), `Tests/AppSnapshotTests/SuiteEditorBarDimmingTests.swift` (deleted), `Tests/SuiteUITests/EditorShellTests.swift`, `UITests/Journey.swift` | – (both app features closed) | ~380 lines, mostly deletions; 8 files |
| ER-2 | – | Delete the tokens only the top bar read, and rewrite `docs/design.md` for one shell | `Sources/SuiteUI/Tokens.swift`, `Tests/SuiteUITests/TokensTests.swift`, `docs/design.md` | ER-1 | ~180, 3 |

## Build waves

- Wave 1: ER-1. Independent in this wave: ER-1 alone.
- Wave 2: ER-2 (`feature-done`; the one `docs/design.md` edit, rule (a)).
  Independent in this wave: ER-2 alone.

Longest chain: ER-1 → ER-2 (2). ER-2's tokens are read by the views ER-1
deletes, so ER-2 can't build before ER-1 merges.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| ER-1 | `grep -rn "EditorShell\b\|EditorTopBar\|EditorBarItem\|EditorBarMenu\|EditorBarDivider\|\.rail\b\|expectEditorShell" Sources Tests UITests` finds nothing outside `Tests/AppAuditTests/Checks/DisabledDim.swift`'s comment; `scripts/ci` `CI: PASS`; the dev macOS run builds every app and every journey is green; the remaining `EditorShellTests` green; every journey green | something still uses a deleted type, or a journey loses a control |
| ER-2 | `grep -rn "editorTopBar\|windowControlsInset\|editorBarDivider\|editorBar\b\|editorTitle" Sources Tests docs/design.md` finds nothing; `TokensTests` green on the dev run; `docs/design.md` names no deleted type (`grep -n "EditorShell\|EditorTopBar\|\.rail" docs/design.md` finds nothing) and describes `SuiteWindow`, `EditorDetail`, the floating palette, the sidebar slot, `SidebarActionRow` and `inspectorWidth` | a token survives with no reader, or the rules still describe a shell that no longer exists |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Geometric | unchanged from wave 2: the Design and Photo shell journeys' `expectShellGeometry()` stays green at 1024 × 768 | the dev run after ER-1 |
| Light and dark | the `-dark` journey shots of Design, Photo and SuiteUI look the same as the previous green run's (the lead's review, recorded in RECORD.md) | the dev run's `ui-screens` |
| Audit at or under baseline | every app at or under `UITests/audit-baseline.json`; `suiteui` 0 | the dev run after ER-2 |
| Contact sheet | the `parity-*` shots show four apps, one shell, one tool box | done check |

## Done check

- **Journeys green.** The dev macOS run triggered by ER-2 (`feature-done`)
  is green across all five apps and SuiteUI.
- **Audit zero new.** No count over the baseline for any app.
- **Contact sheet.** Comment `Belt-Contact-Sheet: <run link>` on the
  feature issue, with the `parity-*-window` and `parity-*-palette` shots
  side by side, and a line saying that `EditorShell`, `EditorTopBar` and
  `.rail` are gone.
