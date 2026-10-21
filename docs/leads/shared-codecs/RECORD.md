# shared-codecs lead record

Issue: #3718 · Packet: docs/blueprints/suiteui/features/shared-codecs.md
Run: act-1a15fe5ef7c-rszn (resumes act-1a15e10a9c3-kwzx) · Started: 2026-10-21T10:20Z
Stage: 3 wave 1
Base: 11919406886e89e9e02adea13b113b66e852334d
Next: #4019 and #4020 wait on their queued macOS builds (runs 39664805180, 39664833728). SC-14 restacked on SC-13 4e6f468 (ac16760), gating; push and open its PR once #4019 merges. SC-2 after SC-1 and IM-a.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SC-f | one shared image-format list (SuiteImageFormats) every app and the CLI read | SC-13, SC-14, SC-15, SC-16 | photo open/export panels | – | yes | 0 | building | – | – |
| SC-a | core PNG parity proven; SuiteImageIO stubs in SuiteShell | SC-1, SC-2 | – | suite-imaging:IM-a (SC-2 only) | no | 0 | building | – | – |
| SC-photo | Photo's codec routes through SuiteImageIO | SC-3, SC-4 | rotated-photo | SC-a, photo/export-pack | no | 0 | planned | – | – |
| SC-halo | Halo frame PNG writes through core | SC-5, SC-6 | – | SC-a | no | 0 | planned | – | – |
| SC-library | Library decode/JPEG through SuiteImageIO | SC-7, SC-8 | – | SC-a, SC-f, SC-photo, library spine | no | 0 | planned | – | – |
| SC-raster | Design/Flare rasterizers write PNG through SuiteImageIO | SC-9, SC-10 | – | SC-a, SC-photo | no | 0 | planned | – | – |
| SC-z | HaloFramePNG retired, ImageIO baseline at its floor, feature built | SC-11, SC-12 | – | all slices, AK-z | no | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SC-13 | SC-f | 1 | acceptance tests first; format-list ratchet live | Tests/SuiteModelTests/SuiteImageFormatsTests.swift, Tests/SuiteModelTests/FormatListRatchetTests.swift, Tests/format-lists-baseline.txt, Tests/AfterGlowCLITests/ImageFormatParityTests.swift | FormatListRatchetTests | #4019 | in review |
| SC-14 | SC-f | 2 | SuiteImageFormats value + plists read it | Sources/SuiteModel/Values/SuiteImageFormats.swift, Sources/SuiteModel/Values/SuiteTypes.swift, Bundle/Info/Photo.plist, Bundle/Info/Library.plist, Tests/SuiteModelTests/PlistShapeAppsTests.swift, Tests/mutations/SuiteModel.SuiteImageFormats.json, docs/c4/parts/creative-apps/suite-model/suite-identity.json | SuiteImageFormatsTests | – | building (stacked on SC-13) |
| SC-15 | SC-f | 3 | Photo open/export lists from SuiteImageFormats | Sources/PhotoModel/PhotoImageFile.swift, Sources/PhotoModel/PhotoHeadless.swift, Sources/PhotoApp/PhotoWindow+File.swift, Sources/PhotoApp/PhotoWindow+Export.swift | PhotoFormats tests | – | planned |
| SC-16 | SC-f | 4 | Library export lists from SuiteImageFormats | Sources/LibraryModel/Contracts/LibraryValues.swift, Sources/LibraryModel/Contracts/ExportFormats.swift, Sources/LibraryModel/Contracts/ExportPresets.swift, Sources/LibraryApp/Platform/JPEGWriter.swift | Library format tests | – | planned |
| SC-1 | SC-a | 1 | core PNG parity + ImageIO import ratchet live | Tests/PhotoModelTests/CorePNGParityTests.swift, Tests/SuiteModelTests/ImageIOImportRatchetTests.swift, Tests/imageio-baseline.txt, Tests/AppSnapshotTests/SuiteImageIOTests.swift, Tests/PhotoModelTests/Fixtures/png-parity/ | CorePNGParityTests, ImageIOImportRatchetTests | #4020 | in review |
| SC-2 | SC-a | 2 | SuiteImageIO stubs (supervisor merge: Package.swift) | Sources/SuiteShell/SuiteImageIO.swift, Package.swift, project.yml, docs/c4/parts/creative-apps/suite-shell/shell-imageio.json | SuiteImageIOTests | – | planned |
| SC-3 | SC-photo | 3 | Photo codec route tests first | Tests/PhotoModelTests/PhotoCodecRouteTests.swift, Tests/RealJobs/photo/rotated-photo/ | PhotoCodecRouteTests | – | planned |
| SC-4 | SC-photo | 4 | Photo codec through SuiteImageIO | Sources/SuiteShell/SuiteImageIO.swift, Sources/PhotoApp/ImageIOCodec.swift, Sources/PhotoModel/CoreRasterImageCodec.swift, Sources/PhotoApp/PhotoPasteboard.swift | PhotoCodecRouteTests | – | planned |
| SC-5 | SC-halo | 3 | Halo frame PNG core tests first | Tests/HaloModelTests/HaloFramePNGCoreTests.swift | HaloFramePNGCoreTests | – | planned |
| SC-6 | SC-halo | 4 | Halo headless PNG through core | Sources/HaloModel/HaloHeadless.swift, Sources/HaloApp/HaloPNGWriter.swift, Tests/mutations/HaloModel.HaloHeadless.json | HaloFramePNGCoreTests | – | planned |
| SC-7 | SC-library | 3 | Library ImageIO tests first | Tests/AppSnapshotTests/LibraryImageIOTests.swift, Tests/AppSnapshotTests/Fixtures/library-imageio-expected.json | LibraryImageIOTests | – | planned |
| SC-8 | SC-library | 5 | Library decode/JPEG through SuiteImageIO | Sources/LibraryApp/Platform/ImageIODecoder.swift, Sources/LibraryApp/Platform/JPEGWriter.swift | LibraryImageIOTests | – | planned |
| SC-9 | SC-raster | 3 | rasterizer PNG tests first | Tests/AppSnapshotTests/RasterizerPNGTests.swift | RasterizerPNGTests | – | planned |
| SC-10 | SC-raster | 5 | Design/Flare rasterizers through SuiteImageIO | Sources/DesignApp/DesignRasterizer.swift, Sources/FlareApp/StageRasterizer.swift | RasterizerPNGTests | – | planned |
| SC-11 | SC-z | 5 | retire HaloFramePNG | Sources/HaloModel/HaloFramePNG.swift, Tests/mutations/HaloModel.HaloFramePNG.json, Tests/PhotoModelTests/CorePNGParityTests.swift, Tests/canonical-baseline.txt | CorePNGParityTests | – | planned |
| SC-12 | SC-z | 6 | ImageIO baseline floor; feature-done | Tests/imageio-baseline.txt, Tests/SuiteModelTests/ImageIOImportRatchetTests.swift, docs/c4/parts/creative-apps/suite-shell/shell-imageio.json, docs/blueprints/suiteui/features/shared-codecs.wave.json | ImageIOImportRatchetTests | – | planned |

Waves (combined plan, rule 19): 1 = SC-13, SC-1, suite-imaging:IM-1 (independent, disjoint files). 2 = SC-14 (waits SC-13: makes its disabled tests live), SC-2 (waits SC-1 and IM-a: links SuiteShell to CoreRaster beside IM-1's Package.swift edit), suite-imaging:IM-2. Later waves per the packet's Build waves.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev (1191940), not main 0dd23d6: the packets and wave data live only on dev, and CLAUDE.md says branch from dev.
- One PR per task, not per slice: SC-13+SC-14 is ~580 lines, over the 400 cap (rule 22; same call as the photo lead).
- SC-14 is built stacked on SC-13 now; its PR opens once SC-13 merges so its diff against dev fits the cap.
- SC-2 edits Package.swift and project.yml as the packet says; it is a supervisor merge, off the fast lane.
- Wave work runs as one worktree subagent per task (Workflow needs opt-in; lead.md fallback).

## Open
- SC-photo waits photo/export-pack; SC-library waits library spine (building); SC-z waits adopt-kernel-autosave AK-z (planned).
- 2026-10-21T19:24Z: #4019 and #4020 were held on red Linux by dev's CommandPathTests photo failure (PhotoPlace.swift:36), which #4008 fixed on dev; both branches merge origin/dev and re-gate.

- 2026-10-21T19:37Z: #4019 and #4020 merged dev (#4008 fix), baselined the pasteboard files dev added, re-gated CI: PASS, moved Head: lines. Both await the lane.
- 2026-10-21T20:10Z: #4019 and #4020 macOS build-only runs queued. SC-14 rebased onto SC-13 head 4e6f468, clean; scripts/ci --changed running.
