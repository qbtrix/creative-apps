# cull-finish lead record

Issue: #3458 · Packet: docs/blueprints/library/features/cull-finish.md
Run: act-1a16953af22-wvhu (line lead, line:library) · resumed 2026-10-23 · earlier run act-1a15995d319-aamb
Stage: build, wave 3; #4844 (DR-6) merged on dev 0d4645bf at 2026-10-23T18:38:28Z; #4838 (head 110671fc) and #4899 (now 9 files/223 lines vs dev) on the lane. Checked 2026-10-24T01:56Z
Base: origin/dev 35a0b5e7
Next: lane merges #4838, #4844, #4899 (#4899 fits 400/15 once #4844 lands); then a scoped run app=library for Belt-Slice-Done DR-u (+Mac-Finish-Wanted) and DR-m; then DR-z (DR-9 journey, DR-10 docs incl. the ⌥⌘⌫ packet wording and excludedPaths wiring gap)

## Slices
| slice | behavior | tasks | waits on | ui | rounds | state | run |
|---|---|---|---|---|---|---|---|
| DR-a | contract: Trash service, label keys 6-9, Delete Rejects stubs, tests written disabled | DR-1, DR-2 | FC-a (on dev), MD-a (on dev) | no | 0 | done | 39507806909 |
| DR-u | confirm dialog, ⌥⌘⌫, Set Label 6-9; snapshots; journey skipped | DR-3, DR-4 | DR-a, FC-a, MD-d/e (met: MD-a merged) | yes | 0 | PR #4838 open | - |
| DR-m | label cull, deleteRejects body + undo, excludedPaths coding, LiveTrash | DR-5..DR-8 | DR-a; MD-c, MD-e (met: MD-a merged) | no | 0 | DR-6 #4844 merged, DR-7+8 #4899 open | - |
| DR-z | journey on, docs, C4, feature-done | DR-9, DR-10 | DR-u, DR-m | no | 0 | waiting | - |

## Tasks
| id | slice | wave | behavior | PR | state |
|---|---|---|---|---|---|
| DR-1 | DR-a | 1 | PhotoTrashing, FakeTrash, LiveTrash stub, services.trash, LibraryKey.label 6-9, deleteRejects stubs (Mutate 4/4) | #3623 | open, fast-lane |
| DR-2 | DR-a | 1 | disabled tests for DR-5/DR-6, never-deletes scan, delete-rejects real job (pending DR-8) | #3625 | open, stacked on #3623; CI: PASS on e0752118 |
| DR-5 | DR-m | 1 | keys 6-9 set Red/Yellow/Green/Blue as one step, never advance (40 lines, folded into DR-2's PR) | #3625 | merged daee0e736; Mutate 2/2 LibraryModel.LibraryCulling |
| DR-6 | DR-m | 2 | deleteRejects body, trashed undo step, excludedPaths fed to import; turns on LibraryDeleteRejectsTests | #4844 | merged 0d4645bf (largeBudget enabled, listed in Tests/perf-suites.txt per supervisor); Mutate 4/4 LibraryModel.LibraryDeleteRejects; protected path, supervisor lands |
| DR-7 | DR-m | 3 | excludedPaths in the catalog file (omitted when empty); photo.delete-rejects command | #4899 | open, fast-lane, stacked on #4844 (dr6 merged in); head f1071bc8; Mutate 6/6 LibraryModel.LiveCatalogCoding |
| DR-8 | DR-m | 4 | LiveTrash on FileManager.trashItem; RJ-L06 on | #4899 | open with DR-7; RJ-L06 stays pending: LibraryHeadless and LibraryWindow+Persist do not pass excludedPaths yet (folded into DR-z or a gap) |
| DR-3 | DR-u | 2 | Photo > Delete Rejected Photos… ⌥⌘⌫, confirmationDialog, Set Label names 6-9 | #4838 | open, fast-lane, head 110671fc (needs-fix fixed) (one PR with DR-4) |
| DR-4 | DR-u | 2 | snapshots, render budget, journey skipped (waits on DR-9) | #4838 | open, fast-lane (one PR with DR-3) |

## Wires
- [ ] Wire: metadata-more:MD-c (DR-7 built on dev's catalog coding; swap in when MD-c merges)
- [ ] Wire: metadata-more:MD-d (DR-3 built on dev's menus; swap in when MD-d merges)
- [ ] Wire: metadata-more:MD-e (DR-3, DR-6 built on dev's metadata fakes; swap in when MD-e merges)

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| - | - | - | - | - | - |

## Decisions
- Dependencies FC-a (LibraryUndoAdapter) and MD-a (LibraryServices) are on dev, so DR-1 starts now.
- DR-2's real job is marked `"pending": "DR-8"` with `"platforms": []`, the repo's existing mechanism for a job that waits; the packet's `waits_on: DR-8` means the same.
- The re-import check uses `beginImport()`'s skip set, so DR-6 adds trashed paths there.
- DR-a ships as two PRs (DR-1, DR-2): the packet sizes it near 320 lines plus fixtures.
- Waits outside this feature: DR-3 and DR-7 on AC-library's Belt-Slice-Done on #2999 (AC-l4 still waits on CC-u); DR-3 on metadata-more MD-d and MD-e, DR-6 on MD-e, DR-7 on MD-c (MD PRs #3545, #3569-#3582 open). DR-4 waits on DR-3; DR-8 on DR-7. Until those land, DR-5 is the only buildable DR task after DR-a.

- 2026-10-20T16:44Z: macOS build-only runs for this feature have been queued since ~14:25Z (runner backlog); lead keeps waiting, no action needed from the supervisor unless the queue is stuck.
- 2026-10-23: resumed by line lead act-1a16953af22-wvhu. The supervisor unparked this feature under contract-first waits (#4814): MD-a, metadata-more's contract slice, merged (run 39479914225), so the MD-c, MD-d and MD-e waits are met and get Wire lines. DR-6 and DR-u start now.
- 2026-10-23T16:33:18Z: the records moved to lead/library-cull-finish (docs/leads/library-cull-finish/), the branch Belt watches; lead/cull-finish is retired.
- 2026-10-23T16:33:18Z: Delete Rejected Photos takes ⌥⌘⌫, not the packet's ⌘⌫. Remove from Collection already holds ⌘⌫ in the Photo menu, and with both enabled one key would do two things. ⌥⌘⌫ is the platform's delete-from-library chord next to ⌘⌫ remove. DR-10 updates the packet text.
- 2026-10-23T16:33:18Z: DR-6's large budget test (300 rejects in 10,000) ships disabled: the gate fails any timing test not in Tests/perf-suites.txt, which only the supervisor edits. Ask: add LibraryModelTests.largeBudget there.
- 2026-10-23T16:33:18Z: testEveryMenuOpens (UITests/LibraryJourneyTests.swift) lists the Photo menu exactly; DR-9 adds the new item to it when it turns the journey on.
- 2026-10-23T16:35:10Z: 27 open line:library findings, none against this feature; asked the supervisor on #3458 whether they gate new waves. Counting only this feature's (0) until answered.
- 2026-10-23T17:32:30Z: supervisor answered on #3458 (6369907319): count only this run's findings; go on with wave 3; add `library LibraryModelTests.largeBudget` to Tests/perf-suites.txt inside #4844; ⌥⌘⌫ is fine, keep it in the shortcut catalog. Checked: Library has no shortcut catalog or conflict test (LibraryCommandCatalog's CommandSpec has no key field); by hand, ⌥⌘⌫ Delete Rejected Photos and ⌘⌫ Remove from Collection are the only delete keys, no clash. #4838 is 398/400 lines, so no catalog there; DR-10 fixes the packet's ⌘⌫ wording to ⌥⌘⌫.
- 2026-10-23T17:49:02Z: fixer A: #4844 head 52603087 adds `library LibraryModelTests.largeBudget` to Tests/perf-suites.txt (free-test form) and enables it, CI: PASS, Mutate 4/4. #4899 merged dr6 in, head f1071bc8, CI: PASS; shows 16 files/404 lines vs dev until #4844 lands. Asked the supervisor to land #4844 and whether a Library shortcut catalog should be a gap (#3458 6371186942).
- 2026-10-23T17:58:33Z: supervisor answer (#3458 6371335630, 6371346311): the supervisor lands #4844 as a merge commit after the Linux check and the local Mac gate; #4899 then rides the lane (its base is already dev, no retarget needed). Shortcut catalog is a suite-wide gap, #4945 (off this line). Decision ticked.
- 2026-10-23T18:14:47Z: #4838 got needs-fix from the batch macOS gate (supervisor 6371534274): LibraryCullFinishSnapshots.swift:16 'shoot' is inaccessible (LibraryFixtures.shoot is internal in LibraryModel). Fixed with `@testable import LibraryModel` (Design snapshots do the same with DesignModel), merged origin/dev, scripts/ci --changed CI: PASS, pushed 110671fc, Head line moved. Fix round 1 of 2 for DR-u.
- 2026-10-23T18:38:55Z: #4844 merged by the supervisor (merge commit 0d4645bf). #4899's diff against dev is now 9 files, 223 lines, within the lane's caps; its base is already dev.

- 2026-10-23T19:56Z DR-u fix round 2 of 2: #4838 head ad5deded builds Delete Rejected and Move to Trash from `deleteRejectsControlSpec` (command-path audit). Local `scripts/ci --changed` tests segfault in this container on plain dev too; no Fast-Check, the lane's Linux run is the proof.

- 2026-10-23T20:09Z #4838 split for the 400-line cap: head 84be0634 (310 lines). Pending follow-up PR from `feat/cull-finish-dr-u-tests` (RenderBudgetLibraryDeleteRejectsTests + LibraryJourneyTests+CullFinish) once #4838 is on dev.
