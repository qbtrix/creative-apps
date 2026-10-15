# Photo features: waves

The Photo v2 blueprint (`docs/blueprints/photo.md`, merged in #768) grouped
into features, one feature-lead session each. This file covers the
blueprint's waves 0, 1 and 2, which have packets; waves 3 and 4 are listed at
the end and get packets once wave 2 has landed. A wave starts when
everything it waits on has merged. Two features in the same wave never own
the same file. Each packet lists its tasks, owned files and acceptance tests.

| wave | feature | PV | packet | covers | tier | waits on (this repo) | waits on (creative-core) | feature issue |
|---|---|---|---|---|---|---|---|---|
| 0 | The seams: contracts, fakes, services, state, routing, file splits | PV-0 | `photo-seams.md` | – | p1 (by dependency) | nothing | nothing | filed after this packet PR merges |
| 0 | Shared journey helpers | PV-0 (journey part) | `photo-journey-kit.md` | – | p1 (by dependency) | #333 (QH-4; suite-harness #778 closes it with task SH-7) | nothing | file when ready |
| 1 | Save and reopen with layers, Open Recent, unsaved state, recovery | PV-1 | `photo-documents.md` | – | p1 | photo-seams (journey tasks only: photo-journey-kit) | nothing | file when ready |
| 1 | Cut, Copy, Paste, Duplicate, Merge Down, Flatten | PV-2 | `photo-edit.md` | – | p1 | photo-seams (journey tasks only: photo-journey-kit) | nothing | file when ready |
| 1 | Typed crop size and aspect lock; the perf journeys | PV-3 | `photo-crop.md` | #544 | p1 | photo-seams (journey tasks only: photo-journey-kit) | nothing | file when ready |
| 2 | Adjustment layers | PV-6 | `photo-adjustment-layers.md` | #580 | p1 | photo-edit (hands over `PhotoCommands+Layer.swift`) | nothing (CR-5 optional) | file when ready |

The blueprint's PV-0 is two features here: its journey part (moving
`writeTestPhoto` into a second journey file) is the only part that waits on
SuiteUI, so it runs as photo-journey-kit beside photo-seams instead of
holding the seams back. The perf journeys PJ-P1 and PJ-P2 moved to
photo-crop (CP-7), the first feature with a second journey file and a series
of its own.

## File when ready

Each feature issue is filed once everything in its "waits on" cell is closed
(each feature: its `feature-done` PR merged and its CI run green), with labels
`feature-lead`, `line:photo` and its tier, a link to its packet, the issues it
covers, one `Depends on:` line naming those issues, and the lead contract
below. The lead playbook (`docs/factory/lead.md`, stage 0) stops a lead whose
`Depends on:` issue is still open, and Belt launches a lead as soon as its
issue exists, so filing earlier would only start leads that stop.

| feature | title | tier | file when these are closed | `Depends on:` line |
|---|---|---|---|---|
| photo-seams | Feature: photo-seams | p1 | nothing (file after this packet PR merges) | `Depends on: none` |
| photo-journey-kit | Feature: photo-journey-kit | p1 | #333 (closed by suite-harness SH-7) | `Depends on: #333 (QH-4 journey files)` |
| photo-documents | Feature: photo-documents | p1 | photo-seams' issue | `Depends on: #<photo-seams> (photo-seams)` |
| photo-edit | Feature: photo-edit | p1 | photo-seams' issue | `Depends on: #<photo-seams> (photo-seams)` |
| photo-crop | Feature: photo-crop | p1 | photo-seams' issue | `Depends on: #<photo-seams> (photo-seams)` |
| photo-adjustment-layers | Feature: photo-adjustment-layers | p1 | photo-edit's issue | `Depends on: #<photo-edit>` |

A wave-1 feature does not wait on photo-journey-kit as a whole: only its
journey tasks (D-11, D-12, E-9, E-10, CP-5, CP-7) use the kit's helper, and
each packet tells the lead to build everything else first and, if the kit
is still open then, record the wait and keep its heartbeat until it closes
(blueprint 4.1: the model and view tasks don't wait on #333). The kit itself
waits only on #333, not on the rest of suite-harness.

The three wave-1 features run side by side: their owned files are disjoint
(checked in "Files across the waves").

## What each waits on outside Photo

| need | where | who makes it | until then |
|---|---|---|---|
| A second Photo journey file compiles (#333 QH-4) | `project.yml`, `UITests/Journey.swift` | suite-harness #778, task SH-7 | photo-journey-kit waits on #333; the wave-1 journey tasks wait on the kit |
| Save status in `EditorTopBar` (#339 S6) | `Sources/SuiteUI/EditorTopBar.swift` | editor-chrome EC-4 (SuiteUI wave 2, filed after #778) | photo-documents shows a plain label; the swap is a `line:photo` follow-up |
| Status pills, warning pill (#340 S7) | `Sources/SuiteUI/ViewerStatusBar.swift` | editor-chrome EC-6 | photo-seams uses today's `statusPill(.warning)` for "Preview data" |
| `LayerList` with a leading symbol and trailing accessory | `Sources/SuiteUI/LayerList.swift` | lists-and-layers LL-5 plus a new `needs-ui` issue photo-seams' lead files | photo-adjustment-layers keeps today's `List` rows with the symbol |
| `FrameProbe` (#330), goldens (#331, #332) | SuiteUI harness | suite-harness #778 | "within 100 ms" marks and PF-13 goldens are report-only; PNGs for eyes |
| Anything in creative-core | – | – | no wave-0 to wave-2 feature needs an engine change |

No feature here edits `Sources/SuiteUI/**`, `project.yml`,
`UITests/Journey*.swift`, `UITests/Journey+Input.swift` or
`Tests/AppSnapshotTests/AppSnapshotTests.swift`.

## Why this order

- **The seams alone first.** photo-seams edits Photo's five shared files
  once, so every later feature owns its own. Its own tasks form one chain
  because each app task needs the Model types before it (packet, Tasks).
- **The kit beside it.** It touches only `UITests/PhotoJourneyTests.swift`
  and its new `+Fixtures` file, which photo-seams never touches, and it
  needs #333 rather than any seam.
- **Every p1 next** (`docs/priorities.md`: nothing `p2` starts on a line
  while a `p1` is open and unblocked). photo-documents, photo-edit and
  photo-crop are independent. photo-adjustment-layers shares
  `PhotoCommands+Layer.swift` with photo-edit, so it starts as soon as
  photo-edit is done, without waiting for the other two.

## Files across the waves

- **Wave 0.** photo-seams owns every file in its task table (the contracts,
  fakes, services, `Live/` stubs, the workspace, history, stroke, selection,
  render, image-ops and straighten files it edits, the window, intent,
  commands, editor, panel and overlay splits, `PhotoApp.swift`, and the
  tests and snapshots it names). photo-journey-kit owns
  `UITests/PhotoJourneyTests.swift` and `UITests/PhotoJourneyTests+Fixtures.swift`.
  No path is in both.
- **Wave 1.** photo-documents: `M/PhotoDocumentFile.swift`,
  `M/PhotoRecovery.swift`, `M/Live/LiveDocuments.swift`, `M/Live/PhotoZip.swift`,
  `M/Live/LiveArchive.swift`, `M/Live/LiveRecovery.swift`,
  `A/PhotoWindow+File.swift`, `A/PhotoCommands+File.swift`, `A/PhotoTopBar.swift`,
  `A/PhotoPackageIO.swift`, `A/PhotoAutosave.swift`, `A/PhotoApp.swift`, its
  tests and `UT/PhotoJourneyTests+Documents.swift`, `+Recovery.swift`,
  `+PerfDocuments.swift`. photo-edit: `M/PhotoClipboard.swift`,
  `M/PhotoLayerOps.swift`, `M/Live/LiveEdit.swift`, `M/Live/LiveMerging.swift`,
  `A/PhotoWindow+Edit.swift`, `A/PhotoCommands+Edit.swift`,
  `A/PhotoCommands+Layer.swift`, `A/PhotoPasteboard.swift`, its tests and
  `UT/PhotoJourneyTests+Edit.swift`, `+LayerOps.swift`. photo-crop:
  `M/PhotoCropSize.swift`, `M/Live/LiveCrop.swift`, `A/PhotoWindow+Crop.swift`,
  `A/CropOptions.swift`, `A/CropOverlay.swift`, its tests and
  `UT/PhotoJourneyTests+Crop.swift`, `+Perf.swift`. No path is in two.
  Every wave-1 test file name is new and distinct.
- **Wave 2.** photo-adjustment-layers: `M/PhotoAdjustmentLayer.swift`,
  `M/PhotoLayerComposite.swift` (from photo-seams), `M/Live/LiveAdjustmentLayers.swift`,
  `A/PhotoWindow+AdjustmentLayer.swift`, `A/PhotoAdjustTab.swift`,
  `A/PhotoLayersTab.swift`, `A/PhotoCommands+Layer.swift` (from photo-edit),
  `A/AdjustmentsInspector.swift`, `A/CurvesSection.swift`, its tests and
  `UT/PhotoJourneyTests+AdjustmentLayers.swift`, `+PerfAdjustmentLayers.swift`.
- **Hand-overs to later waves:** `M/PhotoLayerComposite.swift`,
  `A/PhotoLayersTab.swift` and `A/PhotoCommands+Layer.swift` to PV-5;
  `A/AdjustmentsInspector.swift` and `A/CurvesSection.swift` to PV-10;
  `A/PhotoCommands+Edit.swift` to PV-7; `UT/PhotoJourneyTests+Perf.swift`
  stays photo-crop's (PV-5 and PV-7 add their own perf files).
- **Nobody** in waves 0 to 2 edits `docs/c4/model.json` or `docs/design.md`.
  `photo-model-sources` and `photo-app-sources` (paths = the target folders)
  already own every new file, so the C4 gate passes. The blueprint's PV-0
  task "C4 description" is dropped from photo-seams.

## Review of #768: where each note went

| note | where |
|---|---|
| Section 0 base refresh | one-line fix in `docs/blueprints/photo.md` (creative-core `dev` 4cac701, `main` cfad97f); the packets cite it |
| Overlay marks queried as elements | photo-seams note 1: each mark is an identified, non-control accessibility element (S-10b) |
| PF-3 "bit for bit" through 8-bit `ClipboardImage` | photo-edit note 1: within 1/255 |
| `-PhotoRecoveryDir`, where recovery I/O sits, Flare's shape, PJ-3's damaged file | photo-documents notes 1–3 (`M/Live/LiveRecovery.swift`; `fileServices`; `PhotoAutosave` in Flare's shape; a damaged file is removed with no offer, as Flare does) |
| Merge Down and Flatten call the per-layer hook | photo-seams note 2, photo-edit note 2, photo-adjustment-layers note 1 |
| 8.3 unowned needs before wave 3 | (1) photo-seams note 3 (`hover` from `onPointer`); (2) and (3) below, "Later waves" |
| PV-5 could run in wave 3 | "Later waves" |
| `docs/design.md` and `docs/priorities.md` edits have no owner | the supervisor owns both, with the C4 and look sections it folds in; #544 and #580 relabelled from `p2` to `p1` (blueprint question 2) when this packet PR was opened |
| PJ-7's error state; failed save has no journey | photo-edit note 3 (`-PhotoFixture layered`); photo-documents PJ-1b |
| QB-F2 has no number or test | each packet's quality table: `PhotoDragRoutingTests.refusalIsImmediate`, `PhotoCropSizeTests.dragUpdatesEveryEvent` (PB-8), `PhotoDocumentFileTests.statusFollowsEdits`, `PhotoClipboardTests.nothingToCopyIsImmediate`, `PhotoAdjustmentLayerTests.adjustDamagesAtOnce` |
| Schedule risk: #333, CR-1 to CR-4, CR-2 | #333 is photo-journey-kit's wait; CR items, "Later waves" |

## Open captain calls

| call | where it bites | packets' default |
|---|---|---|
| Blueprint Q1, the `.ora` format | photo-documents | accepted as recommended: OpenRaster, stored entries, `photo/document.json`; Photo reads only files that carry it |
| Q6, #274 (open and save panel plumbing) | photo-documents owns `PhotoWindow+File.swift` | hold #274 until photo-documents is done |
| Q7, exported `.ora` type (`scripts/bundle-apps`, protected) | Finder double-click | left out; Open, Open Recent and drop work |
| Q9, polish beside p2 | wave 3 | unchanged |

## Later waves (no packet yet)

| wave | feature | covers | waits on | notes from the review |
|---|---|---|---|---|
| 3 | PV-4 history tab and brush cursor | #644, #588 | waves 1 and 2 | draws the ring from photo-seams' `hover`, so it owns `BrushCursorOverlay.swift` and never `PhotoEditor.swift` |
| 3 | PV-7 transform and flip | – (a `gap` issue filed with its packet) | waves 1 and 2; creative-core CR-1 | CR-2 (an exact flip) is a pixel copy small enough to live in Photo's `Live/LiveTransform.swift`, so only CR-1 waits on core. Its single-layer preview (PB-10) needs a render file and a canvas file; its packet adds its own `M/PhotoTransformPreview.swift` (the layer's picture for the preview, from its own tiles) and draws it in `A/TransformOverlay.swift` (its own), so it never takes `M/PhotoLayerComposite.swift`, which goes to PV-5 |
| 3 | PV-8 export size, TIFF, HEIC | – (a `gap` issue) | waves 1 and 2 | photo-documents routes Save through `ImageFormat(fileName:)`, so adding `.tiff` and `.heic` in `PhotoImageFile.swift` makes them writable with no edit to `PhotoDocumentFile.swift` or `PhotoWindow+File.swift` |
| 3 | PV-9 eyedropper | – (a `gap` issue) | waves 1 and 2 | – |
| 3 | PV-10 polish | #79, #252, #253, #289; moves #255, #586 to SuiteUI | waves 1 and 2 | – |
| 3 (was 4) | PV-5 selections and masks | #421 | photo-adjustment-layers; creative-core CR-3, CR-4 | it shares no file with the other wave-3 features once PV-7 keeps its preview in its own files (row above), so it need not wait for all of wave 3; masks rank earliest in the course outlines. The wave-3 packets must re-check this with a script over their task tables |

The PV-1, PV-2, PV-7, PV-8 and PV-9 `gap` issues of blueprint 8.1 are not
filed: each feature issue here (or its later packet) stands for that work,
and a second issue per feature would be a duplicate.

## Critic round

One read-only critic agent tried to refute the six packets: task size, owned
files overlapping within a wave or inside a feature without a chain, the
shared-file rule and protected paths, tests that can't fail, closed or
duplicate issues, facts against `dev`, and the review notes of #768. It found
5 blocking, 12 major and 13 minor problems; all are fixed in the packets.

| # | sev. | finding | fix |
|---|---|---|---|
| 1 | blocking | S-6a's `.eyedropper` breaks switches in `PhotoStroke.swift`, `PhotoIntent.swift` and `PhotoPanel.swift` it didn't own | S-6a owns those three files, adds empty arms and the fallback help "Not built yet (PV-9)." |
| 2 | blocking | `LiveServicesTests` asserted every `.live` member is `NotBuilt`, so each wave-1 feature would break a file only photo-seams owns | it asserts "nil, or exactly that member's NotBuilt text" |
| 3 | blocking | no file outside `PhotoWorkspace.swift` could make a layer id (paste, duplicate, adjustment layers, fixtures, a loaded document) | S-6a makes `insertLayer` internal and adds `reserveLayerIDs(after:)`; D-3, E-3, AL-3 test fresh ids |
| 4 | blocking | photo-documents needed `@State` and modifiers on `PhotoWindow.swift`, which no wave-1 feature owns | S-8a gives every area an identity `ViewModifier` in its own file; photo-documents keeps all its window state in `PhotoFileArea` |
| 5 | blocking | S-10b changed `StrokePacer`'s moves, built in `PhotoWindow.swift`, which it didn't own | S-10b owns `PhotoWindow.swift` (in the chain) |
| 6 | major | S-6a used `currentStepID` (S-6b) and tested `isDirty` (owned by no task) | `isDirty` and the `savedStepID` line move to S-6b |
| 7 | major | S-7b's geometry-hook calls sat in files it didn't own | the hook is declared in S-6a (delete calls it); S-7c calls it from Apply Crop; S-7b from Image Size, Rotate, Straighten |
| 8 | major | S-8a named intent types from files S-8b creates | S-8a creates all nine area files as stubs |
| 9 | major | the rail reads `PaletteTool.unavailableHelp` from the enum, so the Eyedropper would look enabled on `.live`; S-7a dropped the live check | `PhotoRailTool` (S-10a) carries `toolHelp`; "I" doesn't pick a disabled tool; S-7a keeps "acts or has help" on `.live` |
| 10 | major | waves.md gave `PhotoLayerComposite.swift` to PV-5 and PV-7 in one wave | PV-7's preview goes in its own `M/PhotoTransformPreview.swift` |
| 11 | major | PJ-1b's flat save never reached the locked folder | the journey adds a layer first, so Save writes a new document there |
| 12 | major | waves.md said #544 and #580 were already `p1` | relabelled when the PR was opened |
| 13 | major | the kit waited on all of #778 and every wave-1 feature on the kit | the kit waits on #333; wave-1 features depend on photo-seams only, and only their journey tasks wait on the kit |
| 14 | major | S-7a weighted only Delete and Fill by the selection, not the dabs, leaving PV-5 to edit unowned files | new S-7c routes every dab, Delete and Fill through `selectionCoverage` |
| 15 | major | Apply Crop's `.defaultAction` would apply the crop on Return in a crop field | CP-4 removes it; PJ-8 asserts the crop stays pending |
| 16 | major | an opened PNG had no file kind once `start()` reset it | D-3 adds `openImage`, which sets it; the window opens through it |
| 17 | major | `AdjustmentSettings` isn't `Codable` and its file is frozen after S-6a | S-6a adds `Codable` |
| 18 | minor | PB-20's 16 ms debug gate read as converting pixels on the main actor | it is the copy-on-write value copy; conversion runs off main |
| 19 | minor | 16,000,000 paste cap against the 16,777,216 open limit, rounding past it | `maxOpenPixels`, sides rounded down: 5016 × 3344, "Pasted at 84%." |
| 20 | minor | KT-1 counted eleven helper calls | seven |
| 21 | minor | the blueprint still said `main` 4cac701 in two places | fixed (sections 0.3 and 5) |
| 22 | minor | S-8a's Return/Escape check belonged to S-10b | moved |
| 23 | minor | `PhotoMenu` already carries the workspace; the flat `.selectAll` must stay | S-9 and S-8a say so |
| 24 | minor | PJ-P3's large document pointed at a fixture on fakes | it writes a 4000 × 3000 photo and saves it |
| 25 | minor | `PhotoPasteboard` took no pasteboard but its test used a private one | a `pasteboard:` parameter, `.general` by default |
| 26 | minor | the copy focus rule covered sheets only | also any text view that is first responder |
| 27 | minor | AL-8's done check named journeys of features it doesn't wait on | "those merged by then" |
| 28 | minor | three QB-F2 tests appeared only in the quality tables | each is in its task's acceptance |
| 29 | minor | the `limit` fixture is about 4 GB and unused | left out of S-5 |
| 30 | minor | E-2 compared a Float merge with the 8-bit render | the render after equals the render before |

Checked clean by the critic: no file owned by two features in one wave and
no shared file between unchained tasks inside a feature (a script over every
task table); no task touches `Sources/SuiteUI/**`, `project.yml`,
`UITests/Journey*`, `AppSnapshotTests.swift`, `docs/c4/model.json`,
`docs/design.md` or a protected path; every file named as edited or
unchanged exists; #544, #580, #333, #778, #339, #340 and #273 are open and
covered once; `CanvasViewport.onPointer`, `statusPill(.warning)`,
`ScrubField`, `ChoiceChips` and `InspectorAction` exist; the crop, paste,
history and zip arithmetic holds; Command-J and Command-E are free; no
product names.


## Longest build chain

Each packet was re-cut to `docs/factory/packets.md` (shared docs in one
final task, a task waits only on merged code it needs, each wave lists its
independent tasks). Longest depends-on chain in tasks, before and after;
a chain over 3 has its reason in the packet's Build waves section.

- photo-adjustment-layers: 7 before, 4 after.
- photo-crop: 5 before, 4 after.
- photo-documents: 10 before, 8 after.
- photo-edit: 5 before, 5 after.
- photo-journey-kit: 1 before, 1 after.

## The lead contract

Every feature lead and every task below codes against this. It is handed
verbatim to every session, and each feature issue carries it.

1. **Feature issue.** One GitHub issue per feature, labels `feature-lead` and `line:<app>`. Body links the packet `docs/blueprints/<app>/features/<feature>.md` and has one `Depends on:` line.
2. **Run.** Belt runs one cloud session per feature issue (a lead), from the trusted launch folder, with the repo's Auto settings (creative-apps#733, creative-core#263). A lead holds one in-flight slot however many PRs it opens.
3. **Status channel.** The lead pushes `docs/leads/<feature>/RECORD.md` and `timeline.tsv` to branch `lead/<feature>` after every stage. Belt reads the branch's last commit time; nothing else is polled besides PRs and issue comments.
4. **Swarm PRs.** Base `dev`, label `fast-lane`, at most 400 lines and 15 files. Body lines: `Belt-Lead: <run id>`, `Feature: <feature>`, then `Fast-Check: pass` and `Head: <full sha>` after `scripts/ci` passes. The lane merges them. Nobody merges into dev by hand or by an agent.
5. **Review policy (decision for the captain).** `Belt-Lead:` PRs do not need the `belt/review` status. The lead's own critic panel is the review. Only `Belt-Run:` and `Belt-Test:` PRs keep it.
6. **Done.** All three: a `Belt-Lead:` PR labelled `feature-done` has merged; the CI run it triggered on dev is green; the lead commented on the feature issue with a line starting `Belt-Contact-Sheet:` and the run link.
7. **Stall.** No commit on `lead/<feature>`, no PR event and no issue comment for 30 min: Belt sends one nudge with `claude -p --cloud <session id> "<resume text>"`. A second stall: relaunch with a resume brief that says "read RECORD.md, continue from the last stage". A third: label the issue `needs-human` and stop.
8. **Timeouts.** Lead runs: 8 h wall clock, no 1 h no-PR rule. Task runs keep today's 4 h and 1 h.
9. **Brief rules.** Step one checks out the integration branch and verifies the base SHA. Set the repo-local identity "Prakash Dalai" / `86671543+prakashUXtech@users.noreply.github.com`. No attribution line anywhere, comments included. Fixers run the full harness before handing back. The Anatomy loop stops after 2 clean rounds or 4 rounds total; once a round is clean, add no new critics. One critic lens is first-use clarity: "what does each number and label mean to someone new?". Agents never treat a chat message as a reason to stop or skip a merge; questions go to the supervisor.
