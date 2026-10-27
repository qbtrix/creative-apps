# clipboard-interop lead record

Issue: #4512 (was #3753) · Packet: docs/blueprints/suiteui/features/clipboard-interop.md
Run: act-1a1786024b0-c5o9 (line lead: clipboard-interop, area-selection, fill-heal; resumed 2026-10-26T13:26Z) · earlier: act-1a175f7cb67-l7rh (line lead: clipboard-interop, area-selection, fill-heal; resumed 2026-10-26) · earlier: act-1a1705bc1ae-pb09 · Session: claude/feature-lead-suiteui-ebo2et · Resumed: 2026-10-25T00:03Z
Stage: 3 wave check
Base: afef017c27a56ec18983e58672a8a15c94083ce4 (origin/dev = origin/main)
Next: wait for the lane to batch #5116 (re-integrated at 0e1cc330, Fast-Check pass) and the other CB PRs; on merge, check main runs for Belt-Slice-Done.
Polled: 2026-10-27T09:29Z · lane queue checked; dev-red open






## Status now
Run act-1a1695ebfeb-d54n, 2026-10-23T15:30Z; supersedes the tables' PR/state columns.
- Unparked by the supervisor (2026-10-23, contract-first waits, lead.md rule 12): a wait is met once the other feature's contract slice merged; build on its fakes with a Wire line.
- Wave 1 (this run): CB-6 (CB-design), CB-8 (CB-flare), CB-10 (CB-halo) building, one PR each, on placed-images PL-a's fakes where PL-m's bodies aren't there.
- CB-12 (CB-library) blocked: shared-thumbnails ST-a not merged (no contract to build on). CB-13/14 (CB-photo): shared-codecs SC-photo checked next wave.
- CB-a, CB-m, CB-s, CB-u merged; test halves CB-5 #4302, CB-7 #4306, CB-9 #4317, CB-11 #4316 merged.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CB-a | SuiteClipItem gains the app's own layer bytes, the live coder and the shell bridge are declared as stubs, and their tests are written and disabled. | CB-1, CB-2 | MJ-CB | editor-kernel, command-catalog (built, `depends`) | no | 0 | merged | – | – |
| CB-m | The coder orders representations richest first (own type, SVG, PNG, TIFF, text), picks the best item a target app can take and says why Paste is off, and the CLI's pasteboard folder round-trips every item. | CB-3, CB-4 | MJ-CB | CB-a | no | 0 | merged | – | – |
| CB-s | One SuiteShell bridge writes and reads the coder's items on the system pasteboard with no source metadata and no polling timer. | CB-4b, CB-4c | MJ-CB | CB-a | no | 0 | merged | – | – |
| CB-u | SuiteUI has one Copy As submenu (PNG, SVG, the app's own type) and Paste as Image built from the catalog's specs, each item off with the coder's reason as its help, reachable from the gallery's menus page on the fakes. | CB-u1, CB-u2 | SJ-CB | CB-a | yes | 0 | merged | – | – |
| CB-design | Design's Copy writes its layers, a PNG of the selection at 2x and an SVG beside them, and Paste of a plain image or SVG places it as a picture at the view's centre. | CB-5, CB-6 | DJ-CB | CB-a (CB-5); CB-m, CB-s, CB-u and placed-images:PL-m (CB-6); design/placed-images PD-m and design/pen-paths DP-m (cross-line); shared files, after adopt-kernel-unsaved-prompt:UP-design (CB-6), area-selection:AR-design (CB-6) | yes | 0 | building | – | – |
| CB-flare | Flare's Copy writes its layers, a PNG of the selection at the playhead and an SVG frame beside them, Paste of an image or SVG places it, and its 4 Hz pasteboard poll is gone. | CB-7, CB-8 | FJ-CB | CB-a (CB-7); CB-m, CB-s, CB-u and placed-images:PL-m (CB-8); flare/svg-place PF-m and flare/pen-paths FP-m (cross-line); shared files, after frame-rates:FR-flare (CB-8) | yes | 0 | building | – | – |
| CB-halo | Halo's Edit > Copy Frame writes the viewer's frame as PNG, and Paste of an image or SVG adds a placed image layer at the playhead. | CB-9, CB-10 | HJ-CB | CB-a (CB-9); CB-m, CB-s, CB-u and placed-images:PL-m (CB-10); halo/placed-images PH-m and halo/file-flow HF-m (cross-line); shared files, after frame-rates:FR-halo (CB-10) | yes | 0 | building | – | – |
| CB-library | Library's Copy writes the selected photo as a full-size PNG with its develop settings applied and as a file URL, with no location data. | CB-11, CB-12 | LJ-CB | CB-a (CB-11); CB-m, CB-s (CB-12); #3160 and library/file-flow LF-m (cross-line); shared files, after shared-thumbnails:ST-m (CB-12) | yes | 0 | planned | – | – |
| CB-photo | Photo's Copy and Paste run through the shared bridge with the same bytes it writes today, and Paste of an SVG places it rasterized at the canvas centre. | CB-13, CB-14 | PJ-CB | CB-m, CB-s, CB-u; shared-codecs:SC-photo (`PhotoPasteboard.swift`); photo/file-flow PF-m (cross-line); shared files, after area-selection:AR-photo-m (CB-14) | yes | 0 | planned | – | – |
| CB-z | Design's, Flare's and Photo's own pasteboard files are deleted with the baseline shrunk by three lines, RJ-X72 and RJ-X73 pass, and the feature is built. | CB-15, CB-16 | MJ-CB, DJ-CB, FJ-CB, PJ-CB | every adopt slice; area-selection:AR-z (CB-15, `canonical-baseline.txt`) | yes | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CB-1 | CB-a | 1 | Contract as stubs. `SuiteClipItem.appLayers(SuiteTypeID, Data)`; `SuitePasteboardCoding` (representations, best item, refusal) returning the fake's answers; ... | `Sources/SuiteModel/Values/Clip.swift`, `Sources/SuiteModel/Pasteboard/SuitePasteboardCoding.swift`, `Sources/SuiteModel/Pasteboard/PasteboardFolder.swift`, `Sources/SuiteShell/PasteboardBridge.swift`, `Sources/SuiteKernel/Commands/CopyAsCommands.swift` | SuiteModel builds on Linux; `CommandShapeTests` passes with the new specs | – | planned |
| CB-2 | CB-a | 2 | `SuitePasteboardCodingTests` and `PasteboardFolderTests` written, disabled by name (`waits on CB-3`) | `Tests/SuiteModelTests/SuitePasteboardCodingTests.swift`, `Tests/SuiteModelTests/PasteboardFolderTests.swift` | compile, disabled | – | planned |
| CB-3 | CB-m | 3 | Coder bodies: the order, the best item per app, the refusal sentence; turns on `SuitePasteboardCodingTests` | `Sources/SuiteModel/Pasteboard/SuitePasteboardCoding.swift`, `Tests/SuiteModelTests/SuitePasteboardCodingTests.swift`, `Tests/mutations/SuiteModel.SuitePasteboardCoding.json`, `docs/c4/parts/creative-apps/suite-model/suite-pasteboard.json` | `SuitePasteboardCodingTests`: a Design copy offered to Photo picks PNG; to Design picks its own layers; SVG offered to Flare picks `.vector`; text alone refuses Paste with a sentence; `PasteboardFolderTests` round-trips each item | – | building |
| CB-4 | CB-m | 3 | `PasteboardFolder` body (one file per type, the CLI's `--pasteboard <dir>`); the live slot (`pasteboardIsLive = true`); turns on `PasteboardFolderTests` | `Sources/SuiteModel/Pasteboard/PasteboardFolder.swift`, `Sources/SuiteShell/Live/PasteboardSlot.swift`, `Tests/SuiteModelTests/PasteboardFolderTests.swift`, `Tests/mutations/SuiteModel.PasteboardFolder.json` | `PasteboardFolderTests`: each item kind round-trips; an unknown file is ignored; the slot reports live | – | building |
| CB-4b | CB-s | 3 | `PasteboardBridgeTests` (macOS, a private named pasteboard), disabled (`waits on CB-4c`) | `Tests/SuiteUITests/PasteboardBridgeTests.swift` | compiles, disabled | – | planned |
| CB-4c | CB-s | 4 | `PasteboardBridge` body, lifted from `PhotoPasteboard`'s writer: PNG plus TIFF re-encoded with no source metadata, SVG as `public.svg-image`, own types as da... | `Sources/SuiteShell/PasteboardBridge.swift`, `Tests/SuiteUITests/PasteboardBridgeTests.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-pasteboard.json` | `PasteboardBridgeTests`: a written PNG reads back as the same bytes and carries no GPS or MakerNote; two writes in a row bump the change count; nothing polls (no `Timer` in SuiteShell) | – | planned |
| CB-u1 | CB-u | 3 | Reachable first: the gallery's Menus page gains Edit > Copy As and Paste as Image over `FakePasteboard`; `CopyAsMenu` builds the items from `CopyAsCommands` ... | `Sources/SuiteUI/CopyAsMenu.swift`, `Sources/SuiteUI/Gallery/GalleryMenus.swift`, `Tests/SuiteUITests/CopyAsMenuTests.swift` | `CopyAsMenuTests`: three Copy As items in order, each with its command id; with text on the fake pasteboard Paste as Image is off and its help is the coder's sentence | – | building |
| CB-u2 | CB-u | 4 | The gallery journey and the render budget row | `UITests/SuiteJourneyTests+Clipboard.swift`, `Tests/AppSnapshotTests/RenderBudgetCopyAsMenuTests.swift` | `SuiteClipboardJourneyTests.testCopyAsMenuInGallery`; `RenderBudgetCopyAsMenuTests.openMenuInOneBody` | – | building |
| CB-5 | CB-design | 3 | Design, test first. `DesignPasteboardAdapterTests`, disabled; the journey, skipped; RJ-X72's job folder, disabled | `Tests/DesignModelTests/DesignPasteboardAdapterTests.swift`, `UITests/DesignJourneyTests+Edit.swift`, `Tests/RealJobs/suite/copy-design-paste-photo/copy-design-paste-photo.jobs.json` | compiles, disabled; `scripts/jobs check` | – | planned |
| CB-6 | CB-design | 5 | `DesignPasteboardAdapter.swift` (own bytes, `DesignRasterizer` PNG, `DesignSVG` SVG; paste image to `place.image`); the canvas and Layers hooks call the brid... | `Sources/DesignModel/DesignPasteboardAdapter.swift`, `Sources/DesignApp/DesignEditMenu.swift`, `Sources/DesignApp/DesignWindow.swift`, `Tests/DesignModelTests/DesignPasteboardAdapterTests.swift`, `UITests/DesignJourneyTests+Edit.swift`, `Tests/mutations/DesignModel.DesignPasteboardAdapter.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/AfterGlowCLITests/Golden/apps/design.list-commands.json` | `DesignPasteboardAdapterTests`: copy of a red rectangle offers own, SVG and a 2x PNG of its bounds; paste of a 300×200 PNG adds one placed-image layer at 300×200 pt centred in the view; `DesignEditJourneyTests.testCopyOutPasteImageIn` | #4904 | pr-open |
| CB-7 | CB-flare | 3 | Flare, test first. `FlarePasteboardAdapterTests`, disabled; the journey, skipped | `Tests/FlareModelTests/FlarePasteboardAdapterTests.swift`, `UITests/FlareJourneyTests+Edit.swift` | compiles, disabled | – | planned |
| CB-8 | CB-flare | 5 | `FlarePasteboardAdapter.swift` (own bytes, `StageRasterizer` PNG at the playhead, the SVG frame writer; paste to `place.image` or svg-place's `place.svg`); E... | `Sources/FlareModel/FlarePasteboardAdapter.swift`, `Sources/FlareApp/FlareWindow+Edit.swift`, `Sources/FlareApp/FlareStageContextMenu.swift`, `Tests/FlareModelTests/FlarePasteboardAdapterTests.swift`, `UITests/FlareJourneyTests+Edit.swift`, `Tests/mutations/FlareModel.FlarePasteboardAdapter.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json` | `FlarePasteboardAdapterTests`: copy at frame 12 offers own, SVG and PNG of frame 12; paste SVG adds svg-place's layers; `FlareEditJourneys.testCopyOutPasteImageIn` | #4902 | pr-open |
| CB-9 | CB-halo | 3 | Halo, test first. `HaloPasteboardAdapterTests`, disabled; RJ-X73's job folder, disabled; the journey, skipped | `Tests/HaloModelTests/HaloPasteboardAdapterTests.swift`, `UITests/HaloJourneyTests+Edit.swift`, `Tests/RealJobs/suite/paste-screenshot/paste-screenshot.jobs.json`, `Tests/RealJobs/suite/paste-screenshot/input/screenshot.png` | compiles, disabled; `scripts/jobs check` | – | planned |
| CB-10 | CB-halo | 5 | `HaloPasteboardAdapter.swift` (the frame through `HaloFramePNG`; paste to halo/placed-images' layer at the playhead); `edit.copy-frame` and `edit.paste` in H... | `Sources/HaloModel/HaloPasteboardAdapter.swift`, `Sources/HaloApp/HaloEditMenu.swift`, `Sources/HaloApp/HaloWindow+Edit.swift`, `Tests/HaloModelTests/HaloPasteboardAdapterTests.swift`, `UITests/HaloJourneyTests+Edit.swift`, `Tests/mutations/HaloModel.HaloPasteboardAdapter.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/AfterGlowCLITests/Golden/apps/halo.list-commands.json` | `HaloPasteboardAdapterTests`: Copy Frame at frame 30 writes the composition's size; paste adds one layer whose in point is the playhead; `HaloEditJourneyTests.testCopyFramePasteImage` | #4905 | pr-open |
| CB-11 | CB-library | 3 | Library, test first. `LibraryPasteboardAdapterTests`, disabled; the journey, skipped | `Tests/LibraryModelTests/LibraryPasteboardAdapterTests.swift`, `UITests/LibraryJourneyTests+Copy.swift` | compiles, disabled | – | planned |
| CB-12 | CB-library | 5 | `LibraryPasteboardAdapter.swift` (the rendered photo through export's pipeline, metadata stripped as in a clean export; the file URL); `edit.copy` in Library... | `Sources/LibraryModel/LibraryPasteboardAdapter.swift`, `Sources/LibraryApp/LibraryCommands.swift`, `Tests/LibraryModelTests/LibraryPasteboardAdapterTests.swift`, `UITests/LibraryJourneyTests+Copy.swift`, `Tests/mutations/LibraryModel.LibraryPasteboardAdapter.json`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/AfterGlowCLITests/Golden/apps/library.list-commands.json` | `LibraryPasteboardAdapterTests`: a photo with exposure +1 copies as the developed pixels, no GPS; `LibraryJourneyTests.testCopyPhotoOut` | – | planned |
| CB-13 | CB-photo | 5 | Photo, oracle first. `PhotoPasteboardAdapterTests` from today's `PhotoPasteboard` behaviour (PNG and TIFF out, any image in, RJ-X05's no-metadata), then `Pho... | `Sources/PhotoModel/PhotoPasteboardAdapter.swift`, `Sources/PhotoApp/PhotoWindow+Edit.swift`, `Tests/PhotoModelTests/PhotoPasteboardAdapterTests.swift`, `Tests/mutations/PhotoModel.PhotoPasteboardAdapter.json` | `PhotoPasteboardAdapterTests`; `PhotoEditJourneyTests.testPasteFromAnotherApp` unchanged; RJ-P35 and RJ-X05 green | – | planned |
| CB-14 | CB-photo | 6 | `edit.paste-as-image` in Photo's catalog and Edit menu (paste a vector as pixels by name) | `Sources/PhotoApp/PhotoCommands+Edit.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/AfterGlowCLITests/Golden/apps/photo.list-commands.json` | `CommandPathTests`; the CLI golden lists it | – | planned |
| CB-15 | CB-z | 7 | Delete the transports. Removes `DesignPasteboardBridge.swift`, `FlarePasteboard.swift` (and its watch) and `PhotoPasteboard.swift`; `scripts/check-dup-logic ... | `Sources/DesignApp/DesignPasteboardBridge.swift`, `Sources/FlareApp/FlarePasteboard.swift`, `Sources/PhotoApp/PhotoPasteboard.swift`, `Tests/canonical-baseline.txt` | every app builds; `scripts/check-dup-logic` (baseline shrank by 3); the five journeys | – | planned |
| CB-16 | CB-z | 8 | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/clipboard-interop.wave.json` | `scripts/waves check`; `scripts/jobs check` | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-26T02:14Z: Run act-1a175f7cb67-l7rh resumed. #5116 and #5125 got needs-rebase; fixing by merging origin/dev (catalog keeps both sides: crop specs plus copySpec) and regenerating goldens.
- 2026-10-23: wave 1 PRs: CB-8 #4902 (11 files, +292/-47; Paste as Image stays out of Flare, edit.copy-as added; LiveStageBudgetTests.nestedDrawListWithinBudget failed locally under load, outside the gate, watch it), CB-6 #4904 (12 files, +303/-57; catalog PNG is clear on Linux, JPEG paste-as-image refused, paste centres on the page), CB-10 #4905 (11 files, +294/-35; Halo owns its pasteboard menu group; two count tests outside its file list gained one line each). The server footer was stripped from all three bodies.
- 2026-10-23 (act-1a1695ebfeb-d54n): feature issue is #3753 per the brief (#4512 also tracks it); PRs carry `Refs #3753`.
- 2026-10-23: wave 1 = CB-6, CB-8, CB-10 with LS-1 (layer-styles); owned files are disjoint. AN-flare-m waits a wave because it shares FlareCommandCatalog, flare.txt and the flare golden with CB-8.
- Base is origin/dev, PRs target dev: the brief names main as the integration branch, but CLAUDE.md and lead.md say never branch from or target main (the lane retargets main PRs to dev).
- One combined wave plan across anchor-parenting, frame-rates and clipboard-interop (rule 19); one PR per slice (rule 22), test commit first.
- Wave 1 is the three contract slices FR-a, AN-a, CB-a: kernel/model stubs plus disabled tests, disjoint files.
- Status channel is lead/suiteui-<feature> with docs/leads/suiteui-<feature>/ (the names Belt reads); the earlier lead/<feature> branches are superseded.
- Slice branches are named lead/<feature>-<slice> because lead/<feature> blocks lead/<feature>/<slice>.
- Wave 2 slices (CB-m, CB-u) build stacked on their wave-1 slice branch and push without a PR; the lead opens each PR once its parent has merged, so the stacked PR never carries the parent's diff past the size cap.

## Wire
- [ ] Wire: placed-images:PL-m (CB-6, CB-8, CB-10 build on PL-a's place fakes where a body is missing; swap in when it merges)
- [ ] Wire: area-selection:AR-design (built on AR-a's fakes in CB-6; swap in when it merges)
- [ ] Wire: adopt-kernel-unsaved-prompt:UP-design (built on UP-a in CB-6; swap in when it merges)
- [ ] Wire: design/placed-images:PD-m (CB-6 pastes a plain rectangle named after the picture until PD-m's picture layer)
- [ ] Wire: flare/svg-place:PF-5 (CB-8: enable pastedSvgAddsItsGroupsAsLayers and the journey's paste-in step)
- [ ] Wire: flare/svg-place:PF-6 (CB-8: delete FlarePasteboardAdapter's private placeCatalog once PlaceCommands is in Flare's catalog)

## Open
- Adopt slices wait on placed-images:PL-m, shared-codecs:SC-photo, shared-thumbnails:ST-m, area-selection AR-design/AR-photo-m/AR-z, adopt-kernel-unsaved-prompt:UP-design, frame-rates FR-flare/FR-halo, plus cross-line app slices. Rechecked before each starts.
- dev-red #3856 fixed on dev by #4008; wave-1 slices merged dev and re-gated.
- CB-a at 96562f1fa (dev merged): dev #4050 moved both Library timing tests into perf-suites; merged dev and re-gating serially (serialgate.sh).
- CB-m before CB-a merges is 524 lines against dev, over the cap: open it only after CB-a merges.
- 2026-10-22T16:36Z recheck (act-1a16474bd3a-i9ae): CB-a, CB-m, CB-s, CB-u merged; test halves CB-5, CB-7, CB-9, CB-11 merged. Still blocked:
  - CB-6 (Design): area-selection AR-design (only #4120's disabled test), design/placed-images PD-m, design/pen-paths DP-m.
  - CB-8 (Flare): flare/svg-place PF-m (FlarePlace+Kernel still throws notBuilt "svg-place PF-5").
  - CB-10 (Halo): halo/placed-images PH-m (no Halo place target on dev).
  - CB-12 (Library): shared-thumbnails ST-m and library/file-flow LF-m not shown built.
  - CB-13 (Photo): shared-codecs SC-photo (no SC-3/SC-4 commits). CB-14: AR-photo-m.
  - CB-15/16: every adopt slice, AR-z.
- 2026-10-22T21:32Z recheck from sources: frame-rates is built (FR-flare, FR-halo met). CB-6/8/10 still wait placed-images:PL-m (packet planned); CB-12 shared-thumbnails:ST-m (planned); CB-13 shared-codecs:SC-photo (planned); CB-14 area-selection:AR-photo-m (planned). The earlier run's supervisor answer (park) stands: parked until upstream adopt slices land; rechecked each wave.
- 2026-10-27T05:56:32Z Resume, run act-1a17be7afb7-bht9: CB-library #5116 merged to dev (02:42Z). CB-flare #4902, CB-design #4904, CB-halo #4905 needs-rebase: merged origin/dev (CLI goldens merged by command id; Halo catalog/tests take dev's file-flow specs then CB-10's pair). Gating serially. #5149 (CB-13), #5125 (CB-14) clean, waiting on lane (dev-red #5818).
- 2026-10-27T06:04:31Z Check-in: CB-library #5116 is in dev ad29aeaf; scoped suiteui run 40457997886 on it in progress (Belt-Slice-Done when green). #4902/#4904/#4905 merges done locally, gates queued after UP-halo. dev-red #5818 open (not ours).
