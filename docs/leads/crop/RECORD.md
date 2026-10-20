# crop lead record

Issue: #1553 · Packet: docs/blueprints/library/features/crop.md
Run: act-1a15995d319-aamb · resumed 2026-10-20T13:30Z (earlier runs act-1a1543fe41f-0zuy, act-1a1526bcdef-i2tx, act-1a147b718b0-qox5)
Stage: done (Belt-Contact-Sheet posted)
Base: f729e906 (origin/dev)
Next: none. All slices have Belt-Slice-Done on Linux check 39427742347 (f729e906); gaps #3617 (CR-8, #782), #3618 (CR-10, core), #3619 (release render, core rotate). Contact sheet posted https://github.com/qbtrix/creative-apps/issues/1553#issuecomment-6292546827

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CR-a | contract: crop catalog methods, CropLeveling slot, FakeCrop | CR-1, CR-2 | MJ6 | develop DV-a (done) | no | 0 | merged (Belt: done) | - | - |
| CR-b | real pixels: crop and straighten | CR-3, CR-4 | MJ6L | CR-a | no | 0 | done, gaps #3619 | 39427742347 | - |
| CR-c | Photo > Crop UI | CR-5, CR-6 | J6 | CR-a; develop inspector follow-up (CR-6) | yes | 0 | Belt: done; CR-6 still to ship (CR-d needs it) | - | - |
| CR-d | integrate on live services | CR-7, CR-8 | J6, P5 | CR-b; CR-c; #782 (CR-8) | no | 1 | done, gaps #3617 | 39427742347 | - |
| CR-e | Auto levels (core issue) | CR-9, CR-10 | MJ6A | CR-a; CR-b; creative-core issue and bump (CR-10) | no | 0 | Belt: done (skipped this run) | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CR-1 | CR-a | 1 | catalog crop methods on fakes; loupe uses the crop draft | LibraryCrop.swift, LibraryLoupeImage.swift (2 lines), LibraryCropTests.swift, mutation plans | LibraryCropTests.walkJ6OnFakes (MJ6) | #3142 | merged 71b157ab |
| CR-2 | CR-a | 1 | CropLeveling slot, leveler, levelHelp, FakeCropLeveling | Contracts/CropLeveling.swift, Fakes/FakeCropLeveling.swift, LibraryCropLevelingTests.swift | LibraryCropLevelingTests | #3152 | merged 2ed7b07a (09:08) |
| CR-3 | CR-b | 2 | LiveCrop render and budget tests, written disabled | Tests | LibraryCropRenderTests (disabled) | #3183 | merged 2b029480 |
| CR-5 | CR-c | 2 | cropMenu filled, R and Return; J6 written, skipped | LibraryWindow+Crop.swift, UITests/LibraryJourneyTests+Crop.swift | J6 (skip) | #3205 | merged b2078f5f |
| CR-0 | CR-c | 2 | #2983: pass the window's menu to LibraryInspector; DevelopInspector(model:menu:cropDraft:) | LibraryInspector, DevelopInspector, LibraryWindow call site | build only (macOS) | #3162 | merged 57d85dfd |
| CR-9 | CR-e | 2 | MJ6A, written disabled | LibraryCropLevelTests.swift | MJ6A (disabled) | #3206 | merged e8d48987 |
| CR-5b | CR-c | - | dropped this run: CR-6 reads `LibraryWindow.cropControls` (CR-5) instead of a spine `Photo.crop` | - | - | - | dropped |
| CR-4 | CR-b | 3 | LiveCrop over straightenCrop; LiveDevelop crops after tone | Live/LiveCrop.swift, Live/LiveDevelop.swift | MJ6L enabled | #3270 | head aec45080, macOS build 39263521636 success, awaiting lane; render row 1429–2059 ms release vs 120 ms (core rotate) |
| CR-6 | CR-c | 3 | overlay, CROP section, loupe artboard; snapshots | LibraryCropOverlay, CropInspector, LibraryLoupe, DevelopInspector, snapshots | J6 (F) | #3249 | macOS build 39260747712 failed (type checker gave up on LibraryCropSnapshots:39); fix round 1 576bbbee pushed 14:40Z (gate CI: PASS), Head line moved |
| CR-7 | CR-d | 4 | J6 live, step 10 relaunch; Closes #425 | UITests | J6 | - | branch lead/crop-CR-7 (e663628a + render slack), 1 file ~100 lines; PR after #3270 and #3249 merge |
| CR-8 | CR-d | 4 | P5 testCropDragLatency (report-only) | UITests/LibraryJourneyTests+PerfCrop.swift | P5 | - | gap #3617 |
| CR-10 | CR-e | 4 | LiveCrop conforms over core horizonAngle | Live/LiveCrop.swift | MJ6A enabled | - | gap #3618 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| - | - | - | - | - | - |

## Decisions
- This run (Belt act-1a1543fe41f-0zuy) owns CR-b and CR-d. Belt counts CR-a, CR-c and CR-e as done, but CR-6 (CR-c) never shipped and CR-7 needs it, so CR-6 ships under `Slice: CR-c` ahead of CR-7.
- CR-5b is dropped so the spine's LibraryMenus.swift stays untouched; CR-6 takes `LibraryWindow.cropControls`.
- PRs go to dev, per CLAUDE.md; main 6f9a2b88 (the brief's SHA, verified) is an ancestor of dev 6e70826b.
- Base is origin/dev, per CLAUDE.md ("never target main"). Main cc14022e (the brief's SHA, verified) is an ancestor of dev, and the lane retargets PRs aimed at main to dev.
- Rule 20: SuiteKernel has no crop module. The crop draft is an `Allow-Dup: Crop` exception with a canonical-baseline line, following export's precedent in #3090. The lift is gap #3117.
- No spine follow-up is needed: `LibraryWindow.menu` already merges `cropMenu: LibraryMenu.Photo` (toggleCrop, cropTitle, applyCrop, resetCrop). CR-5 fills `cropMenu`.
- S-L3 CropHandles is filed as #3116. The overlay uses plain handles until it lands.
- The creative-core horizonAngle issue was asked of the supervisor on #1553, because this session can't reach creative-core.

## Open
- CR-7: no view sets `library.catalog`, so step 10 waits for the readout or for catalog.json to hold IMG_0001's crop. The live run polls 6× longer because the loupe value follows a real render.
- Builder PR bodies carried an attribution footer; stripped from #3249 and #3270 at 14:25Z. Builder prompts must say: no footer. The PR body edit path re-appends the footer itself; the lane strips it from the squash, so it is left.
- The previous session's unpushed builds (CR-4, CR-5b, CR-6, CR-7) were lost with its container. From now on every builder pushes its branch as soon as its gate passes.
- Supervisor: file the creative-core horizonAngle issue (CR-10).
- CR-6 waits on #2983 (develop's inspector follow-up, open gap on line:library, not in progress). It is unblocked as task CR-0, built in wave 2 with `Refs #1553` and `Closes #2983`.
- CR-8 waits on #782 (S-L8, open). If that is still open at the end, CR-8 becomes a gap.
- Wave 2 starts before CR-a merges (never wait): builders branch from dev plus both CR-a branches, commit without pushing, and the lead rebases them onto dev (`git rebase --onto origin/dev <base>`) once the CR-a squashes land.
- CR-5 notes for CR-6: `LibraryMenu.Crop` is declared in LibraryWindow+Crop.swift and exposed as `LibraryWindow.cropControls` until CR-5b adds `Photo.crop`; J6 step 9 reads Reset Crop's reason from `library.controls`; `loupeAreaRender` is now internal.
- CR-9 note for CR-10: walkAutoStraighten also needs CR-4's LiveCrop; enable only after CR-4 and CR-10.
- Supervisor: add `library LibraryModelTests.LibraryCropBudgetTests` to Tests/perf-suites.txt (asked on #1553); CR-3's PR carries it until then (disabled, so the gate is safe).
