# eyedropper lead record

Issue: #3439 · Packet: docs/blueprints/photo/features/eyedropper.md
Run: act-1a1624626e1-8awa · Session: claude/eyedropper-feature-lead-eton7y · Started: 2026-10-22T09:00Z
Stage: 3 wave 1
Base: bdd92b41888b013f6ccd4e177874848a88b1a227
Next: PE-m builder (PE-6) running; then PE-z (PE-7, PE-8) stacked on it

Relaunch for the remaining slices PE-m and PE-z (PE-a and PE-u done by run act-1a15ac118a1-s70v).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PE-a | stubs + tool on the fakes, size chips, palette | PE-1, PE-2 | MJ-PE | shell-parity (built) | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39514893774 | 1b19079c gaps: #4168 |
| PE-u | loupe, click pick, Option-click with Brush; snapshots, budget | PE-3, PE-4 | PJ-E1 | PE-a | true | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39571804700 | wanted |
| PE-m | live sampling, adapter bodies, color.sample, RJ-P36 | PE-5, PE-6 | MJ-PE, RJ-P36 | PE-a (done); history-panel:PH-m (built) | false | 0 | building | – | – |
| PE-z | journey on live, feature-done | PE-7, PE-8 | PJ-E1, RJ-P22 | PE-u (done), PE-m | true | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PE-1 | PE-a | – | adapter stubs | Sources/PhotoModel/PhotoSample+Kernel.swift | PhotoSampleTests | #3706 | merged |
| PE-2 | PE-a | – | tool on stubs, chips | Sources/PhotoApp/SampleOptions.swift | macOS build | #3706 | merged |
| PE-3 | PE-u | – | loupe, click, Option-click | Sources/PhotoApp/PhotoWindow+Sample.swift | PhotoEyedropperOverlayTests | #3808 | merged |
| PE-4 | PE-u | – | snapshots + render budget | Tests/AppSnapshotTests/PhotoEyedropperSnapshots.swift | RenderBudgetPhotoEyedropperTests | #3808 | merged |
| PE-5 | PE-m | – | live ColorSampling on SampleRules.mean | Sources/PhotoModel/Live/LiveSampling.swift | LiveSamplingTests | #3800 | merged |
| PE-6 | PE-m | 1 | adapter bodies, color.sample in catalog, tests on, RJ-P36 | Sources/PhotoModel/PhotoSample+Kernel.swift, Tests/PhotoModelTests/PhotoSampleTests.swift, Tests/mutations/PhotoModel.PhotoSample+Kernel.json, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/RealJobs/photo/sample-mean/ | PhotoSampleTests; .samplesComposite .pickIsToolState | – | building |
| PE-7 | PE-z | 2 | journey on live | UITests/PhotoJourneyTests+Eyedropper.swift | testPickSkyColor | – | planned |
| PE-8 | PE-z | 2 | status built, feature-done | docs/blueprints/photo/features/eyedropper.wave.json | scripts/ci | – | planned |

## Waves
- W1: PE-6 alone (slice PE-m), base dev.
- W2: PE-7 + PE-8 as one slice PR (PE-z, ~60 lines), stacked on PE-m's branch (rule 22); it needs PE-6's live pick for the journey.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base `dev`, not `main`: main is 419 commits behind dev, CLAUDE.md and the lane target dev. Brief step one verified main at 0dd23d65.
- Status stays on `lead/photo-eyedropper` / `docs/leads/photo-eyedropper/`, as the previous run announced on #3439: `lead/eyedropper` is the SuiteUI eyedropper lead's (#3448), so it is not rebased or force-pushed here. `lead/photo-eyedropper` was rebased onto dev instead.
- history-panel is built (PH-m merged), so PE-6's catalog wait is met.
- No open `finding` issues for the feature at start.

## Open
- #4168 (gap, PE-a Mac finish): Free Transform render budget, not this feature's code.
