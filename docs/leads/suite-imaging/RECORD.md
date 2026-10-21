# suite-imaging lead record

Issue: #3715 · Packet: docs/blueprints/suiteui/features/suite-imaging.md
Run: act-1a15e10a9c3-kwzx · Session: cse_0149ntRhzuHiphyYf6FNgYbC · Started: 2026-10-21T10:20Z
Stage: 3 wave 1
Base: 11919406886e89e9e02adea13b113b66e852334d
Next: read IM-1's PR (supervisor merge); open IM-2's PR once IM-1 merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| IM-a | SuiteImaging target + live dependency rule; adjust values/program/route/live surface as stubs with disabled tests | IM-1, IM-2 | MJ-IM | suite-harness, editor-kernel (built) | no | 0 | building | – | – |
| IM-m | values clamp/round-trip, one step list for CPU+GPU, wide working space, live surface one write per step | IM-3, IM-4, IM-5, IM-15 | MJ-IM | IM-a | no | 0 | planned | – | – |
| IM-photo | Photo adjustments are SuiteImaging values; canvas on the shared route; PhotoLiveTone deleted | IM-6, IM-7, IM-8, IM-8d | MJ-IM-photo, PJ-IM | IM-a, IM-m, EP-z (IM-8d), photo #3144 (IM-8) | yes | 0 | planned | – | – |
| IM-library | Library develop values are SuiteImaging values; loupe on the GPU route | IM-9, IM-10, IM-11 | MJ-IM-library, LJ-IM | IM-a, IM-m, library spine feature-done | yes | 0 | planned | – | – |
| IM-z | copies deleted, rule with no baseline, feature built | IM-12, IM-13, IM-14 | MJ-IM, PJ-IM, LJ-IM | IM-photo, IM-library, shared-thumbnails:ST-a | no | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| IM-1 | IM-a | 1 | SuiteImaging target + Metal boundary rule (supervisor merge) | Package.swift, project.yml, Sources/SuiteImaging/SuiteImaging.swift, Tests/SuiteImagingTests/ImagingBoundaryTests.swift, Tests/metal-boundary-baseline.txt, docs/c4/parts/creative-apps/suite-imaging/container.json, docs/c4/parts/creative-apps/suite-imaging/imaging-adjust.json, docs/c4/parts/creative-apps/suite-imaging/imaging-route.json, Tests/mutations/SuiteImaging.ImagingBoundary.json | ImagingBoundaryTests | – | building |
| IM-2 | IM-a | 2 | stubs + disabled tests | Sources/SuiteImaging/Adjust/AdjustSettings.swift, Sources/SuiteImaging/Adjust/ImagingProgram.swift, Sources/SuiteImaging/Route/ImagingRoute.swift, Sources/SuiteImaging/Route/LiveToneSurface.swift, Tests/SuiteImagingTests/AdjustSettingsTests.swift, Tests/SuiteImagingTests/ImagingProgramTests.swift | AdjustSettingsTests, ImagingProgramTests (disabled) | – | building (stacked on IM-1) |
| IM-3 | IM-m | 3 | AdjustSettings clamp + round-trip | Sources/SuiteImaging/Adjust/AdjustSettings.swift, Tests/SuiteImagingTests/AdjustSettingsTests.swift, Tests/mutations/SuiteImaging.AdjustSettings.json | AdjustSettingsTests | – | planned |
| IM-4 | IM-m | 3 | ImagingProgram one step list | Sources/SuiteImaging/Adjust/ImagingProgram.swift, Sources/SuiteImaging/Route/ImagingRoute.swift, Tests/SuiteImagingTests/ImagingProgramTests.swift, Tests/mutations/SuiteImaging.ImagingProgram.json | ImagingProgramTests | – | planned |
| IM-15 | IM-m | 3 | wide working space | Sources/SuiteImaging/Color/ImagingColor.swift, Tests/SuiteImagingTests/WideGamutTests.swift, Tests/mutations/SuiteImaging.ImagingColor.json | WideGamutTests | – | planned |
| IM-5 | IM-m | 4 | LiveToneSurface | Sources/SuiteImaging/Route/LiveToneSurface.swift, Tests/SuiteImagingTests/LiveToneSurfaceTests.swift, Tests/mutations/SuiteImaging.LiveToneSurface.json | LiveToneSurfaceTests | – | planned |
| IM-6 | IM-photo | 3 | Photo imaging tests first | Tests/PhotoModelTests/PhotoImagingTests.swift, Tests/PhotoModelTests/Fixtures/adjust-legacy.ora | PhotoImagingTests | – | planned |
| IM-7 | IM-photo | 4 | Photo adjustments through SuiteImaging | Sources/PhotoModel/PhotoAdjust+Imaging.swift, Sources/PhotoModel/AdjustmentSettings.swift, Sources/PhotoModel/PhotoRender.swift | PhotoImagingTests | – | planned |
| IM-8 | IM-photo | 5 | Photo canvas on the shared route | Sources/PhotoApp/CanvasRenderer.swift, Sources/PhotoApp/PhotoRendering.swift, Sources/PhotoApp/TileCanvas.swift, Sources/PhotoModel/PhotoRenderRoute.swift, Tests/metal-boundary-baseline.txt | – | – | planned |
| IM-8d | IM-photo | 6 | delete PhotoLiveTone | Sources/PhotoModel/PhotoLiveTone.swift, Tests/PhotoModelTests/PhotoLiveToneTests.swift, Tests/canonical-baseline.txt | – | – | planned |
| IM-9 | IM-library | 3 | Library imaging tests first | Tests/LibraryModelTests/LibraryImagingTests.swift, Tests/AppSnapshotTests/LibraryDevelopLatencyTests.swift | LibraryImagingTests | – | planned |
| IM-10 | IM-library | 4 | Library develop through SuiteImaging | Sources/LibraryModel/LibraryDevelop+Imaging.swift, Sources/LibraryModel/Contracts/DevelopValues.swift, Sources/LibraryModel/Live/LiveDevelop.swift | LibraryImagingTests | – | planned |
| IM-11 | IM-library | 5 | Library loupe on the GPU route | Sources/LibraryApp/LibraryLoupe.swift, Sources/LibraryApp/LibraryWindow+Loupe.swift, Sources/LibraryModel/Live/LiveLoupeImaging.swift | LibraryDevelopLatencyTests | – | planned |
| IM-12 | IM-z | 7 | delete Photo's copies | Sources/PhotoModel/GammaTrack.swift, Sources/PhotoModel/PhotoLevelsFormat.swift, Sources/PhotoModel/HueSaturation.swift, Tests/canonical-baseline.txt | – | – | planned |
| IM-13 | IM-z | 6 | no-baseline rule; Photo's Metal link removed | Sources/LibraryModel/Contracts/DevelopValues.swift, Sources/LibraryModel/Live/LiveDevelop.swift, Package.swift, Tests/metal-boundary-baseline.txt, Tests/SuiteImagingTests/ImagingBoundaryTests.swift | ImagingBoundaryTests | – | planned |
| IM-14 | IM-z | 8 | feature-done | docs/c4/parts/creative-apps/suite-imaging/imaging-route.json, docs/blueprints/suiteui/features/suite-imaging.wave.json | – | – | planned |

Waves: combined with shared-codecs (see its RECORD). Wave 1 = IM-1 beside SC-13 and SC-1 (disjoint files). Wave 2 = IM-2 (waits IM-1: needs the target). SC-2 waits IM-1 (Package.swift chain).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev (1191940), not main: the packets live on dev.
- One PR per task (rule 22). IM-2 is built stacked on IM-1 now; its PR opens once IM-1 merges.
- IM-1 edits Package.swift and project.yml as the packet says; it is a supervisor merge, off the fast lane.

## Open
- IM-photo waits adopt-kernel-eyedropper-photo EP-z (blocked) and photo #3144; IM-library waits library spine feature-done; IM-13 waits shared-thumbnails ST-a.
