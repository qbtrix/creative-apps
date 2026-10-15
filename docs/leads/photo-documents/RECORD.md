# photo-documents lead record

Issue: #1074 · Packet: docs/blueprints/photo/features/photo-documents.md
Run: act-1a1404bf04c-bp6m · Session: claude/photo-documents-lead-ezrcev · Started: 2026-10-15T10:40Z
Stage: 3 wave 5
Base: f9846c957abb8b0caeadf6360459e2be3de0592d
Next: wait for D-8, the perf fix and the D-5 debug-guard PR; check the macOS run that contains #1226 (first real compile of D-6/D-7); then wave 6 (D-9)

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
| D-8 | 5 | Save status in top bar, edited dot, Saving…/Opening… notes; snapshots | A/PhotoTopBar.swift, A/PhotoWindow+File.swift, ST/PhotoDocumentsSnapshots.swift | PhotoDocumentsSnapshots | #1228 | open |
| D-9 | 6 | PhotoAutosave + wiring | A/PhotoAutosave.swift, A/PhotoWindow+File.swift, ST/PhotoAutosaveTests.swift | PhotoAutosaveTests | – | waits D-4a, D-4b, D-8 |
| D-10 | 7 | App delegate: Open Recent/Finder opens, unsaved prompt on close/quit | A/PhotoApp.swift, A/PhotoWindow+File.swift, ST/PhotoUnsavedPromptTests.swift | PhotoUnsavedPromptTests | – | waits D-9 |
| D-11 | 8 | Journeys PJ-1, PJ-1b, PJ-2, PJ-4 | UT/PhotoJourneyTests+Documents.swift | macOS run | – | waits D-10, photo-journey-kit (#1073) |
| D-12 | 8 | Journeys PJ-3, PJ-P3 (feature-done if last) | UT/PhotoJourneyTests+Recovery.swift, UT/PhotoJourneyTests+PerfDocuments.swift | macOS run | – | waits D-10, photo-journey-kit (#1073) |

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

## Decisions
- Waves have at most 2 independent tasks, so each wave runs as one worktree subagent per task (lead.md stage 3), not build-wave.js.
- gh CLI has no valid token in this container; agents open PRs and add the fast-lane label through the GitHub MCP tools.
- Swift was missing from the container; installed with scripts/cloud-setup.sh (6.3.3) before wave 1.
- Agent branches are flat (lead/photo-documents-<id>): git refuses lead/photo-documents/<id> next to the lead branch.
- Kept the packet's waves unchanged: every listed wait is a real code dependency (packet "Links").

## Open
- photo-journey-kit (#1073) is still building; D-11 and D-12 wait on it.
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
- D-5 debug guard pushed as lead/photo-documents-d-5-debug (38c6952), no PR yet: local scripts/ci red only on Flare p95 timing tests (also red on plain origin/dev here, under this container's parallel agent load). Lead reruns the gate when the container is quiet.
- CI run 38782884668 (f9846c9): macOS compiles D-6/D-7 app code; red only on PhotoCompositeCostTests timing ratio (not ours; noted on dev-red #763). No snapshots/journeys ran, so no screens yet.
- D-8 state for D-9: EnvironmentValues.photoSaveStatus set in PhotoFileArea.body from model.saveStatus(autosaved: false, saveFailed: files.saveFailed); D-9 swaps `false` for its autosave flag. PhotoWindowEdited(edited:) sets isDocumentEdited. Keep layers? (system confirmationDialog) can't be snapshotted; photo-not-saved-*.png instead.
- Attribution footers removed by hand from #1226's body and from comments on #763 and #1074 (the comment tool appends them too).
