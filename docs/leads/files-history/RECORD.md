# files-history lead record

Issue: #1499 · Packet: docs/blueprints/design/features/files-history.md
Run: act-1a14d285aef-3epc (line lead for design: shell-parity #1325, canvas-basics #1500, files-history #1499) · Session: claude/design-shell-parity-wlqm8c · Started: 2026-10-18T04:02Z
Stage: 2 building
Base: 6bb1f3f6072b1873c4827a682b9c1a750dac8f70
Next: wave 1 FH-2 (builder branch lead/files-history-FH-2). Then wave 2 FH-1, FH-3, FH-4 (DW-a is merged on dev).
Last check: 2026-10-18T04:02Z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FH-a | Saving and opening go through the live filing with the same bytes, the document knows when it is unsaved, and opening a bad file says exactly what is wrong. | FH-2, FH-1, FH-6 | J16 | design-contracts (built) | no | 0 | building | | – |
| FH-b | Undo in a text field undoes the typing, the window says when the file is saved, closing with unsaved changes asks first, and a 2,000-layer file opens within budget. | FH-3, FH-4, FH-5, FH-7 | J13, J14, P4 | FH-a (FH-3, FH-4, FH-7); design-window DW-a (merged) | yes | 0 | waits FH-2 | | |

Issues filed at stage 1: gap #2559 "Design: a journey for opening bad files" (FH-6 closes); follow-up #2560 "Design: adopt `EditorSaveStatus`" (depends on #1344, #339).

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FH-2 | FH-a | 1 | step serials, saved marker, isDirty, saveStateText, didSave, closePrompt, undoTarget | DesignHistory.swift, DesignFile.swift (didSave only), DesignDirtyTests.swift, DesignUndoTargetTests.swift, plan DesignModel.DesignHistory | DesignDirtyTests, DesignUndoTargetTests, Mutate | | building |
| FH-1 | FH-a | 2 | codec into LiveFiling, same bytes | Live/LiveFiling.swift, DesignFile.swift, DesignFilingTests.swift | DesignFilingTests | | waits FH-2 |
| FH-3 | FH-b | 2 | Edit > Undo/Redo route via undoTarget; close prompt | DesignCommands.swift, DesignClosePrompt.swift, DesignFileMenuSnapshots.swift | design-file-menu-close | | waits FH-2 |
| FH-4 | FH-b | 2 | save state in subtitle and design.status.save | DesignSaveStatus.swift, DesignFileSnapshots.swift | design-file-edited, design-file-saved | | waits FH-2 |
| FH-5 | FH-b | 3 | J13, J14 | UITests/DesignJourneyTests+Files.swift | journeys on the macOS run | | waits FH-3, FH-4 |
| FH-6 | FH-a | 3 | J16; closes #2559 | UITests/DesignJourneyTests+BadFiles.swift | journey | | waits FH-1 |
| FH-7 | FH-b | 3 | P4; J16 blueprint row; feature-done | UITests/DesignJourneyTests+PerfFiles.swift, docs/blueprints/design.md (J16 row) | P4 report, grep | | waits FH-1 |

Waves (packet's Build waves, checked against dev 6bb1f3f6):
- Wave 1: FH-2 alone (runs alongside canvas-basics CB-2: disjoint files).
- Wave 2: FH-1, FH-3, FH-4. All independent.
- Wave 3: FH-5, FH-6, FH-7 (feature-done, merged last).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- v3 loop: the packet has a Slices table.
- PRs target dev (CLAUDE.md; the lane retargets main to dev). The brief names main as the integration branch; main 0965457c was verified at start.
- Rule 20 (canonical first): dirty state and the save status belong to the kernel's DocumentSession (editor-kernel EK-session, not on dev), and undo to its History (EK-undo, not on dev). FH-2 adds no concept file: it extends DesignHistory.swift, which Tests/canonical-baseline.txt already lists, and keeps the saved marker a plain serial so adopt-kernel-undo (#1934) can swap it for the kernel's tokens. No Allow-Dup line is needed. Posted on #1499.
- FH-b is ui: true (FH-3, FH-4 change the window), so rules 15/17 apply: feel gate on its run, Mac-Finish-Wanted when done.
- Builder branches are lead/files-history-<task> (a lead/files-history/<task> ref can't sit beside this branch).

## Open
- None yet.

## Run act-1a14fd6514a-4hke (resumed 2026-10-18)

Resume point: Stage 3, wave 2 on dev@ae72cc6c.

- FH-2 merged as #2567 (slice FH-a).
- design-window DW-a has merged (#2163, #2168, #2213, #2214, #2217 and fixes), which unblocks FH-3 and FH-4.
- No open `finding` issue names files-history.
- Wave 2 builders: FH-1 (LiveFiling codec, same bytes), FH-3 (Undo routing and close prompt), FH-4 (save state in DesignSaveStatus).
- Wave 3, next: FH-5 (J13 and J14) once FH-3 and FH-4 merge; FH-6 (J16) and FH-7 (P4, feature-done) once FH-1 merges.
- FH-1: PR #2870 (head e72b3ae0, Mutate 5/5 DesignModel.LiveFiling).
- FH-4: PR #2866 (head 07210d46). It filed #2861 (`needs-ui`, `line:suiteui`) for the window's edited dot.
- FH-3: its builder stopped before the gate. A fixer is finishing it on lead/files-history-FH-3.
- The PR bodies were cleaned of the auto-added attribution footer through the GitHub MCP update. A REST PATCH re-adds it.
- Slice done lines: none yet.
