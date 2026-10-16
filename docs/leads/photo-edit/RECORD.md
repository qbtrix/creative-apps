# photo-edit lead record

Issue: #1075 · Packet: docs/blueprints/photo/features/photo-edit.md
Run: act-1a144817472-xzgv (was act-1a1429c8810-2gls, act-1a13fcb7db6-e1sg) · Session: session_01NRtuLXL2My6shBUxxvDYQE (relaunch; first lead session_016oJAmpWVjb6Qzg26PPT8aW) · Started: 2026-10-15T13:38Z
Stage: 5 finish (round 3 = the feature-done CI run)
Base: 9e3c5f8e23708b834bded120d35d9db5acf4a7f3
Next: wait for a scoped: photo CI run (asked the supervisor on #1075); PJ-5/6/7 are quarantined for full runs (owner #1075, expires 2026-10-18). Green -> Belt-Contact-Sheet; red -> round 4 fix

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| E-1 | 1 | `LiveClipboard`: copy weighted by mask, trimmed; placement | `M/Live/LiveEdit.swift`, `MT/LiveClipboardTests.swift` | `LiveClipboardTests` | #1167 | merged |
| E-6 | 1 | `PhotoPasteboard` read and write (macOS) | `A/PhotoPasteboard.swift`, `ST/PhotoPasteboardTests.swift` | `PhotoPasteboardTests` | #1166 | merged |
| E-2 | 2 | `LiveMerging` through `PhotoLayerComposite` | `M/Live/LiveMerging.swift`, `M/Live/LiveEdit.swift`, `MT/LiveMergingTests.swift` | `LiveMergingTests` (PF-4) | #1173 | merged |
| E-3 | 2 | Workspace Cut, Copy, Paste | `M/PhotoClipboard.swift`, `MT/PhotoClipboardTests.swift` | `PhotoClipboardTests` (PF-3, QB-F2) | #1174 | merged |
| E-4 | 3 | Duplicate Layer, Merge Down, Flatten and help | `M/PhotoLayerOps.swift`, `MT/PhotoLayerOpsTests.swift` | `PhotoLayerOpsTests` | #1181 | merged |
| E-7 | 3 | Edit menu Cut/Copy/Paste, focus rule, edit intents | `A/PhotoWindow+Edit.swift`, `A/PhotoCommands+Edit.swift` | `PhotoEditMenuTests` | #1182 | merged |
| E-5 | 4 | Budgets PB-15, PB-16 | `MT/PhotoEditBudgetTests.swift` | `PhotoEditBudgetTests` | #1193 | merged |
| E-8 | 4 | Layer menu Duplicate/Merge Down/Flatten; "Merging…"; snapshots | `A/PhotoWindow+Edit.swift`, `A/PhotoCommands+Layer.swift`, `ST/PhotoEditSnapshots.swift` | `PhotoEditSnapshots` | #1188 | merged |
| E-9 | 4 | Journeys PJ-5, PJ-6 | `UT/PhotoJourneyTests+Edit.swift` | macOS run | #1218 | merged |
| E-10 | 5 | Journey PJ-7 (`feature-done`) | `UT/PhotoJourneyTests+LayerOps.swift` | macOS run | #1213 | merged |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38776323445 (0dc8dda) | red: macOS build fails in LiveRecovery.swift (photo-documents; fixed on dev by #1226) | – | – | – | – | no |
| 1 (panel) | 38767265986 (d95c756) screens + current code | – | photo at baseline but crop contrast (not ours) | clarity, journey, design, layout, controls, quality | 12 (3 major), list lost with stalled session | – | – |
| 1 (panel rerun) | 38799320916 snapshots + code @ b555f56 | red, not ours | photo contrast 1, identifier 16 | same 6 | 13 (4 major: F0 bounds readout, F3 PJ-5 bounds, F10 PB-15, F11 Merging…) see round1-findings.md | r1-b1..b5 | no |
| 1c | 38799320916 (3dc283e) | red: Photo journeys blocked by the photo-documents restore offer at launch (fixed on dev by #1241); our PJ-5/6/7 never reached their steps | – | – | – | – | no |
| 3c | 38878109062 (ab9e264, full) | green; 24 Photo journeys pass; PJ-5/6/7 skipped (quarantined) | photo identifier 22 ≤ 23 | – | – | – | pending PJ-5/6/7 |
| 3b | 38867245345 (a56bbe3, full) | red, not ours (Halo audit); every other Photo journey passed; PJ-5/6/7 skipped: quarantined for full runs by the supervisor until a scoped photo run | – | – | – | – | – |
| 3 | 38855142429 (1c309d9, feature-done CI) + 38854622691 (scoped photo) | red, not ours: PhotoBrushDisplayTests 119/119 events over budget (creative-core #320 row copies, filed creative-core#334; not #1291), macOS stops in AppSnapshotTests, journeys not run | – | – | – | – | – |
| 2 | 38835566584 (81f3288) | red: ours = Linux PhotoEditBudgetTests copy-vs-merge ordering (4.15 s > 3.93 s); PJ-5 Paste reason not read; PJ-6 placement check; PJ-7 Merge Down reason not read. Not ours: Halo, Library, PhotoDocuments testSaveLayeredDocumentAndReopen | Photo audit: no Photo audit failure in the log | CI failures only (journeys must pass before the panel can judge their screens) | 4 | #1279 (r2-budget), #1281 (r2-edit), #1284 (r2-layerops) | no |
| 1b | 38782884668 (f9846c9) | red: our PhotoCompositeCostTests 4.6× > 4× bound on macOS (unit step, journeys not run) | – | – | flaky bound | #1229 (8×) | – |

## Decisions
- Round 1 batches: b1 inspector bounds + copy refusal (Model), b2 PJ-5/PJ-6 bounds checks, b3 Edit/Layer menu (symbols, Select All, no-window, non-image paste), b4 PB-15 copy speed, b5 async merge with Merging… (closes gap #1191) + flatten note. F9's model part and F2's LiveEdit part dropped to keep files disjoint.
- Waves as the packet's Build waves; checked against dev 28f1df2: `LiveEdit.swift` stub, `EditContracts.swift`, `PhotoWindow+Edit.swift` and `PhotoCommands+Layer.swift` exist as photo-seams left them; no file named in the task table exists yet except those stubs.
- Each wave has 2 independent tasks (wave 4 has 3 but E-9 waits on #1073), so builders run as worktree subagents started together, not build-wave.js.
- E-2 waits on E-1: same file `LiveEdit.swift`. E-3 waits on E-1: PF-3 copies on `.live`. E-4 waits on E-2: its `.live` merges read `services.merging`. E-7 waits on E-3, E-6: it calls both. E-8 waits on E-4, E-7: calls E-4, extends E-7's `EditIntent`. E-5 waits on E-3, E-4: times them. E-9/E-10 wait on photo-journey-kit #1073 (open).
- The container had no Swift; installed the pinned toolchain with `scripts/cloud-setup.sh` so the gate runs here.
- Builder branches are `lead/photo-edit-<task>`: git can't make `lead/photo-edit/<task>` beside `lead/photo-edit`.
- `photo-app-sources` C4 part doesn't mention the pasteboard yet (E-6 kept to its files); E-7 updates that description.
- E-3 tests the 6000×4000 paste by size math plus a scaled-down real resize (24 MP lanczos3 took 116 s in debug); E-5 must time it in release.
- C4 descriptions: E-4 updates photo-model's part (Live services, Cut/Copy/Paste, layer ops); E-7 updates photo-app's (pasteboard, edit menu).
- `NotBuiltClipboard`/`NotBuiltMerging` in photo-seams' `NotBuilt.swift` are now unused; left in place (not this feature's file).
- E-4 added a 5-line `PhotoEdit.group` case to `PhotoHistory.swift` so Flatten (layers + adjustments) is one undo step (QB-F3); Merge Down reports the lower layer as `.cropped(merged bounds)` to `layerGeometryChanged` (PV-5 to confirm).
- E-7 replaced the system pasteboard group: Paste stays enabled with only text on the pasteboard (so ⌘V works in fields; on the image it says "Nothing to paste."); refusals use the window's `problem` alert, not `pasteRefusal`; system Edit > Select All gone (Select > All keeps ⌘A).
- E-8 may edit `PhotoCommands+Edit.swift` (textAction switch) and `PhotoCommands.swift` (PhotoMenu helps): E-7 put the edit helps and switch there.
- E-8 keeps the shortcuts in `PhotoLayerMenu.shortcut(_:)` so a test can read them; `textAction` gets selectors from an unimplemented `@objc protocol PhotoLayerActions` for the three layer intents (never reached: the Layer menu sends them to the window).
- The perf fixer may edit `PhotoLayerComposite.swift` (photo-seams file, next owner photo-adjustment-layers, not started): output bit for bit unchanged, no API change; the speed-up is this feature's budget.

## Open
- 11:40Z relaunch (run act-1a144817472-xzgv): lead/photo-edit rebuilt on origin/main 9e3c5f8 (it carried only docs/leads/photo-edit; the 690 old commits were squash-merged history), pushed with --force-with-lease. Full runs 38878109062 and 38887139934 green; still waiting a scoped photo run or the quarantine lift.
- PJ-5/6/7 quarantined (scope full, owner #1075, expires 2026-10-18; UITests/quarantine.json is protected). Asked the supervisor on #1075 for a scoped photo run.
- Blocked: creative-core#334 (needs-core). CoreRaster composite allocates per row since core #320; creative-apps CI builds core main, so dev is red on PhotoBrushDisplayTests and no Photo journey runs. Corrected on #763.
- 05:15Z: no Photo CI run came after the round-2 fixes (only design-scoped runs since 03:00), so the final feature-done PR #1317 (wave.json status built) is opened now; its full CI run judges round 3.
- Gap #1287: Photo menu help tags carry no text for accessibility (Halo's do); PJ-5 (#1281) checks the tag exists + the menu unit test, PJ-7 (#1284) reads the tooltip by Vision OCR.
- 02:50Z relaunch (run act-1a1429c8810-2gls): the first lead is still connected with its 3 round-2 fixers running in its container; this lead starts no duplicate fixers and adopts their PRs when they open.
- 01:58Z: the earlier session (Belt nudged it) found this branch moved on by the relaunched lead (silent since 21:49) and continues from here; its own round-1 panel duplicates were dropped. Its one extra: gap #1269, help text for the pre-existing Layer menu items (outside this feature).
- Run 38829075229 (a42b3cf, has r1 fixes): red on HaloTransportFitTests (Halo), Photo journeys not reached.
- Resume 20:42Z: the stalled session opened no fix PRs and did not record its 12 findings; the panel reruns on run 38799320916 (first run with the journeys and #1229).
- Round-1 candidates: (a) a 24 MP paste decodes and lanczos3-resizes on the main thread (E-9 waits 180 s for "Pasted at 84%."); (b) layer rows have no accessibility identifier and no layer-bounds readout (E-9, E-10 worked around); (c) E-9 adds a Hide step so the Cut is visible (3 undos, not 2).
- #1073 closed 16:50Z: E-9, E-10 started together (independent journey files). E-10 carries no `feature-done`; the final PR flips `photo-edit.wave.json` to built and carries it, after the Anatomy rounds.
- Run 38772608478 (cc01f2e): `PhotoCompositeCostTests` (from #1198) flaky on macOS (22.26 vs 22.14 ms bound): fix #1220 (ratio of two strips: counts picture copies, not timing; fails 16.2× on the old loop, passes 10/10).
- Run 38767265986 (d95c756): Photo audit contrast 5 over baseline 0, all on crop screens (photo-crop feature, #1076), not ours; Halo/Library journeys red (not ours).
- Perf blocker found by E-5 (#1193, release, 12 MP): Merge Down 56 s, Flatten 83 s (budget 400 ms), copy+paste 1.6 s (budget 120 ms). Cause: CoreRaster composite copies the whole backdrop per call, called once per tile. Fix #1198 (merged): Merge Down 171 ms, Flatten 247 ms alone / 496 ms beside the other budget test, copy+paste 401 ms. Copy+paste needs creative-core#309 (needs-core: bulk byte conversion, in-place composite). #1193 merged 2 s before the hold took (corrected on the PR).
- Run 38761014883 (86fe18c, has E-7 and E-8): Photo app compiles and Photo suites pass; red only on HaloViewerFidelityTests.keyedFrame6 (Halo line, dev-red #763).
- Gap #1191: "Merging…" on the canvas (merges are synchronous on the main actor); E-8 left it out.
- dev red (#763): run 38748468768 (3d42e80, contains E-1, E-6) fails macOS on LibraryApp `LibraryWindow+Cull/Loupe.swift` compiler crash, not this feature; #1175 fixes it. Run 38757068610 (111c440: E-1..E-3, E-6): Photo compiles, PhotoClipboardTests and PhotoPasteboardTests pass; it fails only on HaloViewerFidelityTests.keyedFrame6 (not ours).
- Builder branches are `lead/photo-edit-<task>`: git can't make `lead/photo-edit/<task>` beside `lead/photo-edit`.
- `photo-app-sources` C4 part doesn't mention the pasteboard yet (E-6 kept to its files); E-7 updates that description.
