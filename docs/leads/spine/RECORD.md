# spine lead record

Issue: #1044 · Packet: docs/blueprints/library/features/spine.md
Run: act-1a13f18aaa0-lfw5 · Session: session_01DtSRhNqsphGfKkvV5eLsWW · Started: 2026-10-15T10:25Z
Stage: 3 wave 13
Base: a6c2135c8fe69127e98ad5a2b0b63d58284603f2
Next: wait for SJ-2 (feature-done) to merge and its CI run on dev; then Anatomy round 1

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| SP-1 | 1 | Shared values, notice and file-state texts, verbatim | Contracts/LibraryValues.swift, Contracts/StateValues.swift | LibraryValuesTests | #1094 | merged |
| SP-10 | 1 | `uniquingIDs` in two passes (closes #235) | LibraryCatalog.swift | LibraryPhotoIDTests | #1093 | merged |
| SP-11 | 1 | `CatalogHistory` value type | CatalogHistory.swift | LibraryHistoryTests | #1095 | merged |
| SA-1 | 1 | Pure split of the app into scene, window, browser, grid, inspector, DisplayImage+Image | LibraryApp/* (6 files) | next macOS run, PNGs unchanged | #1096 | merged |
| SP-2 | 2 | Develop values; PhotoItem grows path, pixelSize, develop, availability | Contracts/DevelopValues.swift, PhotoItem.swift | LibraryPhotoItemTests | #1103 | merged |
| SP-3 | 3 | Protocols (+ `initial` comment fix), SampleImage | Contracts/LibraryContracts.swift, SampleImage.swift | LibraryContractsTests | #1107 | merged |
| SP-4 | 4 | Fakes: support, platform, use cases (progress first) | Fakes/FakeSupport, FakePlatform, FakeUseCases | LibraryFakesTests | #1110 | merged |
| SP-5 | 4 | Fakes: loupe, develop, crop, exporter | Fakes/FakeRendering.swift | LibraryFakeRenderingTests | #1112 | merged |
| SP-6 | 5 | Eight live stubs, LibraryServices | Live/*, LibraryServices.swift | LibraryServicesTests | #1116 | merged |
| SP-7 | 6 | Stored properties, state enums, init(services:), hand-written == | LibraryCatalog.swift | LibraryCatalogTests | #1123 | merged |
| SP-12 | 6 | Launch arguments and fixtures | LibraryLaunch, LibraryFixtures, LibrarySample | LibraryLaunchTests | #1121 | merged |
| SP-8 | 7 | Cached `order`, Budget.swift | LibraryOrder.swift, LibraryCatalog.swift | LibraryOrderTests | #1127 | merged |
| SP-13 | 7 | Readouts, keys, controls JSON | LibraryReadouts.swift, LibraryKeys.swift | LibraryReadoutsTests, LibraryKeysTests | #1128 | merged |
| SA-2 | 7 | One Window scene, services from launch args, platform stubs | LibraryApp.swift, LibraryWindow.swift, Platform/* | macOS testLaunchShowsWindowShell | #1130 | merged |
| SP-9 | 8 | Leave the loupe when the collection hides its photo (only if #217 unmerged) | LibraryCatalog.swift | LibraryCollectionSwitchTests | #1138 | merged |
| SP-14 | 8 | recordEdit, undo, redo, titles, endCoalescing | CatalogHistory.swift | LibraryHistoryTests | #1139 | merged |
| SA-3 | 8 | LibraryMenu per area, every v1 menu item with help | LibraryMenus, LibraryCommands, LibraryWindow | J10 | #1140 | merged |
| SA-4 | 9 | Nine area files, hooks, menu: params, key routing | LibraryWindow*, Browser, Grid, Loupe | J0 step 3, existing journeys | #1142 | merged |
| SA-5 | 10 | Import Folder… empty state, notice slot, Preview pill, export sheet | Browser, StatusBar, ExportSheet, Window | LibraryShellSnapshots | #1150 | merged |
| SA-6 | 10 | Inspector tabs/header, Develop/Crop stubs, crop overlay, loupe value | Inspector, DevelopInspector, CropInspector, CropOverlay, Loupe | LibraryShellSnapshots, loupe journey | #1147 | merged |
| SA-7 | 11 | library.controls, identifiers, spine snapshots | LibraryControls, Window, LibraryShellSnapshots | snapshots | #1154 | merged |
| SJ-1 | 12 | Four journeys on samples, J0, J10 | UITests/LibraryJourneyTests.swift | macOS journeys | #1152 + #1158 | merged |
| SJ-2 | 13 | J11, LibraryFiles helpers (feature-done) | UITests/LibraryJourneyTests+Shell/+Files | J11 |  | building |

## Waves
Taken from the packet's Build waves; checked against dev bcf5a09.
- W1: SP-1, SP-10, SP-11, SA-1 — all independent.
- W2: SP-2 (needs SP-1's PixelSize). W3: SP-3 (needs SP-2's DevelopSettings).
- W4: SP-4, SP-5 — independent (both need SP-3 only).
- W5: SP-6 (needs both fake files). W6: SP-7 (needs SP-6, SP-10, SP-11), SP-12 (needs SP-6) — independent.
- W7: SP-8 (needs SP-7, SP-12's `large`), SP-13 (needs SP-7), SA-2 (needs SA-1, SP-12) — independent.
- W8: SP-9 (needs SP-8), SP-14 (needs SP-8, SP-11), SA-3 (needs SA-2, SP-13) — independent.
- W9: SA-4 (needs SA-2, SA-3, SP-13, SP-14). W10: SA-5, SA-6 (both need SA-4) — independent.
- W11: SA-7 (needs SA-5, SA-6). W12: SJ-1 (needs SA-7). W13: SJ-2 (needs SJ-1; feature-done).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 0 (pre-loop) | 38726261412 (2b98fdb) | red: macOS build | – | – | SA-1 #1096: LibraryInspector calls mutating methods on a let model | fixer lead/spine-fix-inspector | no |

## Decisions
- Builder branches are `lead/spine-<id>`, not `lead/spine/<id>`: git can't hold `lead/spine` and `lead/spine/<x>` refs together.
- #333 is closed and project.yml compiles `UITests/<target>*.swift`, so SJ-2 puts J11 in `LibraryJourneyTests+Shell.swift` and helpers in `+Files.swift`.
- SA-1 leaves out `DisplayImage+Image.swift`: `DisplayImage` lands in SP-1 in the same wave, so SA-2 adds it.
- The cloud GitHub write path appends a `---` / Generated-by footer to PR bodies after the Head: line; the lane strips attribution from the squash (fast-lane.sh) and merged wave 1 with it, so builders leave it.
- SP-11's `CatalogHistory.push` does the coalescing itself; SP-14's recordEdit calls `push` (the pseudocode's `history.top.after = after` can't compile on a read-only `top`).
- SP-10 adds a second case [a, a, a#2] because the packet's example already passed on the old code.
- `gh` GraphQL is blocked in cloud sessions: builders open PRs with `gh api` REST (POST pulls, then POST issues/<n>/labels).
- W4 is split into W4a SP-4 then W4b SP-5: FakeRendering's fakes call FakeBehavior (FakeSupport.swift, SP-4's file), so SP-5 needs SP-4 merged; the packet marked them independent.
- Lesson for app builders: a split-out view with `let model: LibraryCatalog` must take mutations as closures (the catalog is a struct); SA-1 broke the macOS build this way. Every later SA prompt says so.
- #1120 (fix for SA-1's let-model break) merged 11:48; the next macOS run on dev proves it.
- SA-2 also adds DisplayImage+Image.swift (moved from SA-1) and a Model init that applies LibraryLaunch (showsTestValues is internal(set), so the app can't set it).
- SP-9 runs: #217 still open at wave 8 start (12:12Z).
- SP-14 leaves setRating/setFlag/setLabel/clickStar outside the undo history (their files weren't in SP-14's list); the cull feature routes them through cull/recordEdit in wave 2, as blueprint 5.7 says.
- Commented once on #217 that #1138 supersedes it.
- SA-4 kept LibraryLoupe(photo:position:menu:...) rather than (model:menu:), so SA-6 owns the one loupe call line in LibraryBrowser.swift (passing the loupe value and crop draft); SA-5 leaves that line alone. They run in parallel; a lane conflict gets a rebase.
- SJ-1 split: SJ-1a (the four existing journeys on -LibraryFixture samples/empty + File > Load Sample Photos) runs now, ahead of SA-5, because SA-5 removes the content's Load Sample Photos button those journeys click; #1150's fast-lane label is off until SJ-1a merges. SJ-1b (J0, J10) stays in wave 12.
- SJ-2 ships without feature-done: the Anatomy loop needs a CI run first, and its fixes (or, if clean, a packet status-line PR) form the feature's last PR, which carries feature-done.

## Open
- PR #217 (fix for #156) is open at stage 0; SP-9 lands only if it is still unmerged when wave 8 starts.
- Run 38731305776 (7f61259): LibraryApp compiles after #1120; macOS still red on Halo's HaloPlaybackDriverTests.swift:18 circular reference (#1097), reported on #763, not this feature's.
- Run 38734211999 (35a875b, has SA-2): Library compiles, no Library test failures; macOS red only on HaloViewerFidelityTests.keyedFrame6 (Halo line).
- Run 38737961079 (79bd068, has SA-3/SA-4): Library compiles, no Library snapshot/test failures; red only on Halo tests (HaloPlaybackDriverTests, HaloViewerFidelityTests); UI journeys did not execute in that job, so Library journeys are unproven until the Halo red clears.
