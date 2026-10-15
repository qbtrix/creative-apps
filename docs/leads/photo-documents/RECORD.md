# photo-documents lead record

Issue: #1074 · Packet: docs/blueprints/photo/features/photo-documents.md
Run: act-1a1404bf04c-bp6m · Session: claude/photo-documents-lead-ezrcev · Started: 2026-10-15T10:40Z
Stage: 4 round 1
Base: 6018826c90376f7b4ea46336d85e8da510c90f4d
Next: wait for fix D (recovery dir) and fix C (restore off main) to merge; round 2 on the CI run that contains them

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| D-1 | 1 | Stored-entry zip writer/reader with CRC-32 | M/Live/PhotoZip.swift, MT/PhotoContainerTests.swift | PhotoContainerTests | #1196 | merged |
| D-3 | 1 | Workspace side: snapshot, documentPackage, openDocument, openImage, didSave, saveAction, fileKind(forName:), needsDocument, saveStatus | M/PhotoDocumentFile.swift, MT/PhotoDocumentFileTests.swift | PhotoDocumentFileTests | #1197 | merged |
| D-2 | 2 | LiveArchive encode/decode; LiveDocuments.archive() | M/Live/LiveArchive.swift, M/Live/LiveDocuments.swift, MT/PhotoDocumentRoundTripTests.swift | PhotoDocumentRoundTripTests | #1201 | merged |
| D-4a | 2 | autosaveDue, recoveryEntry, restore, RecoveryOffer | M/PhotoRecovery.swift, MT/PhotoRecoveryTests.swift | PhotoRecoveryTests | #1200 | merged |
| D-4b | 3 | LiveRecovery folder I/O; LiveDocuments.recovery(directory:) | M/Live/LiveRecovery.swift, M/Live/LiveDocuments.swift, MT/LiveRecoveryTests.swift | LiveRecoveryTests | #1210 | merged |
| D-6 | 3 | PhotoPackageIO off-main read/write; PF-1 through ImageIO | A/PhotoPackageIO.swift, ST/PhotoPackageIOTests.swift | PhotoPackageIOTests (macOS) | #1212 | merged |
| D-5 | 4 | Budgets PB-18/19/20 | MT/PhotoDocumentsBudgetTests.swift | PhotoDocumentsBudgetTests | #1225 | merged |
| D-7 | 4 | Save routing, Keep layers?, open .ora/flat, errors, Not saved, fileServices, Open Recent | A/PhotoWindow+File.swift, A/PhotoCommands+File.swift | V5/V6, app-state rule | #1223 | merged |
| D-8 | 5 | Save status in top bar, edited dot, Saving…/Opening… notes; snapshots | A/PhotoTopBar.swift, A/PhotoWindow+File.swift, ST/PhotoDocumentsSnapshots.swift | PhotoDocumentsSnapshots | #1228 | merged |
| D-9 | 6 | PhotoAutosave + wiring | A/PhotoAutosave.swift, A/PhotoWindow+File.swift, ST/PhotoAutosaveTests.swift | PhotoAutosaveTests | #1230 | merged |
| D-10 | 7 | App delegate: Open Recent/Finder opens, unsaved prompt on close/quit | A/PhotoApp.swift, A/PhotoWindow+File.swift, ST/PhotoUnsavedPromptTests.swift | PhotoUnsavedPromptTests | #1232 | merged |
| D-11 | 8 | Journeys PJ-1, PJ-1b, PJ-2, PJ-4 | UT/PhotoJourneyTests+Documents.swift | macOS run | #1235 | merged |
| D-12 | 8 | Journeys PJ-3, PJ-P3  | UT/PhotoJourneyTests+Recovery.swift, UT/PhotoJourneyTests+PerfDocuments.swift | macOS run | #1234 | merged |

Waves (packet's Build waves, checked against dev at 00e546a):
- Wave 1: D-1, D-3 — independent of each other.
- Wave 2: D-2 (needs D-1's PhotoZip), D-4a (needs D-3's openDocument/documentPackage) — independent of each other.
- Wave 3: D-4b (needs PhotoZip; edits LiveDocuments.swift after D-2), D-6 (needs LiveArchive and snapshot()) — independent.
- Wave 4: D-5 (times D-4a + D-4b), D-7 (needs PhotoPackageIO and the recovery folder) — independent.
- Wave 5: D-8 (needs D-7's dialog and failed-save flag; same PhotoFileArea).
- Wave 6: D-9 (feeds autosaved into D-8's status; same PhotoFileArea).
- Wave 7: D-10 (Don't Save on Quit discards through D-9).
- Wave 8: D-11, D-12 — independent; both also wait on photo-journey-kit #1073.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38792928305 (c93a7f8, D-7..D-9) | red: ui-test timeout 45 min; 11 Photo journeys red | photo contrast 1 > 0 (_NS:58 = restore alert text) | attribution diagnoser | 9 ours: restore alert from shared recovery dir (#1230) blocks later journeys; 2 not ours (crop #1202, edit #1218 -> #763) | fix D recovery dir; A ids; B Open Recent | no |

## Decisions
- Waves have at most 2 independent tasks, so each wave runs as one worktree subagent per task (lead.md stage 3), not build-wave.js.
- gh CLI has no valid token in this container; agents open PRs and add the fast-lane label through the GitHub MCP tools.
- Swift was missing from the container; installed with scripts/cloud-setup.sh (6.3.3) before wave 1.
- Agent branches are flat (lead/photo-documents-<id>): git refuses lead/photo-documents/<id> next to the lead branch.
- Kept the packet's waves unchanged: every listed wait is a real code dependency (packet "Links").

## Open
- photo-journey-kit (#1073) closed (#1199); D-11 and D-12 wait only on D-10.
- D-2 notes: layer-<i> counts every layer bottom-up from 1; maxOpenPixels (16 MP) is checked after PNG decode.
- QB-L12 gap: PhotoPackageIO.read returns a PhotoPackage and openDocument decodes PNGs on main; D-7 must decode off main (or a fix adds a Model openDocument(snapshot:)).
- D-7 may add openDocument(_ snapshot:name:) to PhotoDocumentFile.swift so the window decodes off main (QB-L12); same line, D-3's merged file.
- D-7 state for D-8..D-10: window holds `@State var files = PhotoFileSession()` (@MainActor @Observable) passed to PhotoFileArea(model:files:perform:); fields keepLayers: ImageFormat?, saveFailed: Bool, working: PhotoFileWork? (.saving/.opening), recentFiles + noteRecent/clearRecent; FileIntent .saveDocument/.flatten/.clearRecent; FocusedValues.photoRecentFiles. PhotoWindow.swift edited (2 lines) to hold the session.
- Open Recent reads Photo's own UserDefaults list `PhotoRecentFiles` (bundle declares no document types; the bundle script is protected).
- QB-L12 gap closed by D-7: openDocument(_ snapshot:name:) added; window decodes off main.
- dev macOS red since #1210 (runs 38774988270, 38776323445, 38777072611): LiveRecovery.swift:94 passes &Bool to fileExists(atPath:isDirectory:) (ObjCBool on Darwin). Ours; fixer PR in flight. Until it lands, no macOS signal for D-6/D-7 app code (build stops in PhotoModel). Tracked on dev-red #763.
- #1226 (fix LiveRecovery ObjCBool) merged f9846c9. #1224 (another session, same line) left to the lane.
- D-5 #1225 merged with heavy debug passes (~6 min on Linux CI) and release misses (save 12.3 s, open 4.1 s, autosave 15.2 s vs 2 s). Follow-ups in flight: debug-guard PR (D-5 builder), perf fixer (lead/photo-documents-perf).
- The GitHub PR tool appends a "Generated by Claude Code" footer to PR bodies; every brief now strips it after creating the PR (done by hand on #1226).
- D-5 debug guard: PR #1231 (18c3760), scripts/ci PASS on dev c93a7f8; footer stripped.
- CI run 38782884668 (f9846c9): macOS compiles D-6/D-7 app code; red only on PhotoCompositeCostTests timing ratio (not ours; noted on dev-red #763). No snapshots/journeys ran, so no screens yet.
- D-8 state for D-9: EnvironmentValues.photoSaveStatus set in PhotoFileArea.body from model.saveStatus(autosaved: false, saveFailed: files.saveFailed); D-9 swaps `false` for its autosave flag. PhotoWindowEdited(edited:) sets isDocumentEdited. Keep layers? (system confirmationDialog) can't be snapshotted; photo-not-saved-*.png instead.
- Attribution footers removed by hand from #1226's body and from comments on #763 and #1074 (the comment tool appends them too).
- D-9 for D-10: files.autosave: PhotoAutosave? (startAutosave), files.recoveryOffer; FileIntent .restore(RecoveryOffer), .discardRecovery. Clean close discards on onDisappear; didSave hook removes the file. Quit: willQuit per dirty window before asking; Don't Save -> discard(); Save -> save().
- Fix-batch item: PhotoAutosave.restore decodes on main (QB-L12); add Model restore(from snapshot) using openDocument(_ snapshot:name:) and decode off main in PhotoAutosave.
- design.md says "alerts never at launch" but the packet/PJ-3 require the restore alert; D-9 followed the packet (Decision).
- D-10 for journeys: unsaved alert "Do you want to save the changes made to the document “beach.png”?" / "Your changes will be lost if you don't save them."; buttons Save (photo.unsaved.save, default), Don't Save (photo.unsaved.dontSave), Cancel (photo.unsaved.cancel); NSAlert sheet. WindowGroup id "photo". Text in PhotoModel/PhotoUnsavedPrompt.swift.
- Fix-batch item: Open Recent with no window shows an empty submenu (menu reads the focused window's list); fall back to the saved PhotoRecentFiles list and route through D-10's open queue.
- feature-done goes on a separate final PR (wave.json status built) after the Anatomy loop, not on D-12; D-11/D-12 are plain journey PRs.
- Perf fix #1233 (f160f36): release save 13.8 s -> 1.6 s, open 4.2 s -> 0.6 s, autosave 16 s -> 3.3 s (alone, quiet). PB-20 still over: disk write of the ~190 MB raw-codec test file + LiveMerging.flatten ~0.5 s. Candidate gap issue if not closed by round 4.
- Fix-batch item (audit): Keep layers? buttons (Save as Photo Document / Flatten into PNG / Cancel) and the top bar's document menu have no accessibility identifiers; add photo.file.keep-layers.* ids.
- Early fix batch started from builders' findings (before round 1 CI): A ids on Keep layers?/document menu (lead/photo-documents-fix-ids), B Open Recent with no window (lead/photo-documents-fix-recent). C restore off main waits on A (both touch PhotoWindow+File.swift).
- D-11 journeys quit + relaunch to use Open Recent (no-window menu was empty); fix B makes the packet's path work.
- Lesson: journeys must isolate every persistent folder the app writes (recovery dir); an alert left by one journey blocks clicks and sheets for every later launch.
- Merged in round 1: #1233 perf, #1234 D-12, #1235 D-11, #1239 fix B, #1240 fix A. #1236 (another session) raised the macOS job to 90 min.
