# onboarding lead record

Issue: #1972 · Packet: docs/blueprints/suite/features/onboarding.md
Run: act-1a14841719c-kml4 · Session: claude/task-36wu9d · Started: 2026-10-17T06:00Z
Stage: 3 wave 2
Base: 453198ac93bd637e13a6aea5f20273bd7ee728f4
Next: wave 2 (OB-2, OB-3, OB-11) building via build-wave.js; when their PRs merge, run the check (a dev run with a green Linux job containing OB-2 makes OB-a merged-done) and start wave 3 (OB-4, OB-7, OB-8, OB-9, OB-10)

Loop: v3 (the packet has a `## Slices` table). Findings queue and the 2-round cap apply.

Brief deviations (see Decisions): PRs base `dev`, not `main`; builder branches are `lead/onboarding-<id>`.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| OB-a | `Sources/SuiteModel/Onboarding/` with every type and signature the window calls as stubs returning the fake's values; its Linux tests written and disabled | OB-1, OB-2 | MJ-OB0 | – | no | 0 | building (OB-1 merged; dev runs 39013069150 and 39018046761 at 453198ac are green and contain it) | – | – |
| OB-u | Help > Welcome to AfterGlow and the first launch open the window on the fakes: three pages, Continue, Back, Skip, focus chips, starter row, every control identified, render budget met | OB-3, OB-4, OB-5, OB-5g, OB-6 | OJ1, OJ2 | OB-a (OB-3); home HM-0 (merged, #1967) | yes | 0 | waiting | – | – |
| OB-m | SuiteOnboarding, OnboardingLaunch, OnboardingModel do the work; StorePreferences over FileStore makes the preferences slot live | OB-7, OB-8, OB-9 | MJ-OB1, MJ-OB2, MJ-OB4 | OB-a | no | 0 | waiting | – | – |
| OB-s | SampleCatalog names one sample per app, finds it under Resources, copies into Documents without overwriting; Bundle/Samples/ holds the files | OB-10, OB-11 | MJ-OB3 | OB-a; bundle (built: bundle-apps copies Bundle/Samples/) | no | 0 | waiting | – | – |
| OB-z | The slot is live, the window reads the bundle's samples, journeys on live | OB-12, OB-13 | OJ3, OJ4 | OB-u, OB-m, OB-s (OB-12); switching (OB-13: Window > Switch To and the transport are on dev) | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| OB-1 | OB-a | 1 | The Onboarding/ types and stubs (SampleFile, OnboardingStarter, OnboardingLayout, OnboardingControls; SuiteOnboarding, OnboardingLaunch, SampleCatalog, StorePreferences, OnboardingModel) with the packet's signatures, bodies returning the fake's values; C4 part descriptions | Sources/SuiteModel/Onboarding/{OnboardingStarter,SuiteOnboarding,OnboardingLaunch,SampleCatalog,OnboardingModel}.swift, Sources/SuiteModel/Preferences/StorePreferences.swift, Tests/SuiteModelTests/OnboardingStubTests.swift, docs/c4/parts/creative-apps/suite-model/{suite-onboarding,suite-preferences}.json | OnboardingStubTests (MJ-OB0) | #1998 (merged 0cf5769d) | merged |
| OB-2 | OB-a | 2 | The checks first, each `@Test(.disabled("waits on OB-n"))`: SuiteOnboardingTests, OnboardingLaunchTests, OnboardingModelTests, StorePreferencesTests, SampleCatalogTests | Tests/SuiteModelTests/{SuiteOnboarding,OnboardingLaunch,OnboardingModel,StorePreferences,SampleCatalog}Tests.swift | the five files compile, disabled with their task id | – | building |
| OB-3 | OB-u | 2 | Reachable and open: Help > Welcome to AfterGlow, the scene's launch behavior, OnboardingWindow page 1 on an OnboardingModel over LauncherServices.shared; OnboardingLauncherTests; the Mac suites as disabled shells | Sources/AfterGlowApp/{AfterGlowApp,LauncherCommands+Onboarding,OnboardingWindow,OnboardingPages}.swift, Tests/SuiteModelTests/OnboardingLauncherTests.swift, Tests/AppSnapshotTests/{AfterGlowOnboardingSnapshots,RenderBudgetAfterGlowOnboardingTests}.swift, docs/c4/parts/creative-apps/afterglow-app/onboarding.json | OnboardingLauncherTests (Linux text scan) | – | building |
| OB-11 | OB-s | 2 | Bundle/Samples/ and SampleFilesTests (every SampleCatalog sample present, non-empty, extension matches; a row whose export issue #836–#839 is open skips naming it) | Bundle/Samples/, Tests/SuiteModelTests/SampleFilesTests.swift | SampleFilesTests | – | building |
| OB-4 | OB-u | 3 | Pages 2 and 3 on the fakes: ChoiceChips of the five focuses, Back; the starter row (OnboardingStartPage), "Start from an empty home"; every control's id; ids-present scan | Sources/AfterGlowApp/{OnboardingPages,OnboardingStartPage}.swift, Tests/SuiteModelTests/OnboardingLauncherTests.swift | OnboardingLauncherTests | – | waits OB-3 |
| OB-7 | OB-m | 3 | SuiteOnboarding and OnboardingLaunch bodies and plans; turns on their tests | Sources/SuiteModel/Onboarding/{SuiteOnboarding,OnboardingLaunch}.swift, Tests/mutations/SuiteModel.{SuiteOnboarding,OnboardingLaunch}.json, Tests/SuiteModelTests/{SuiteOnboarding,OnboardingLaunch}Tests.swift | SuiteOnboardingTests, OnboardingLaunchTests; Mutate 4/4 | – | waits OB-2 |
| OB-8 | OB-m | 3 | OnboardingModel body and plan; turns on OnboardingModelTests | Sources/SuiteModel/Onboarding/OnboardingModel.swift, Tests/mutations/SuiteModel.OnboardingModel.json, Tests/SuiteModelTests/OnboardingModelTests.swift | OnboardingModelTests; Mutate 6/6 | – | waits OB-2 |
| OB-9 | OB-m | 3 | StorePreferences body and plan; preferences slot live; SuiteLiveServicesTests rows; turns on StorePreferencesTests | Sources/SuiteModel/Preferences/StorePreferences.swift, Tests/mutations/SuiteModel.StorePreferences.json, Sources/SuiteShell/Live/PreferencesSlot.swift, Tests/AppSnapshotTests/SuiteLiveServicesTests.swift, Tests/SuiteModelTests/StorePreferencesTests.swift | StorePreferencesTests; Mutate 3/3 | – | waits OB-2 |
| OB-10 | OB-s | 3 | SampleCatalog body and plan; turns on SampleCatalogTests | Sources/SuiteModel/Onboarding/SampleCatalog.swift, Tests/mutations/SuiteModel.SampleCatalog.json, Tests/SuiteModelTests/SampleCatalogTests.swift | SampleCatalogTests; Mutate 3/3 | – | waits OB-2 |
| OB-5 | OB-u | 4 | Fills OB-3's shells: the six snapshot states in four appearances (recorded as known issues until OB-5g commits goldens), the margin and right-edge layout check, RenderBudgetAfterGlowOnboardingTests bodies and timing | Tests/AppSnapshotTests/{AfterGlowOnboardingSnapshots,RenderBudgetAfterGlowOnboardingTests}.swift | those suites on the Mac build | – | waits OB-4 |
| OB-6 | OB-u | 4 | Journeys OJ1 and OJ2 in their own class AfterGlowOnboardingJourneys (fixture firstLaunch, no skip flag; mouse clicks; Escape and Return parity step) | UITests/AfterGlowJourneyTests+Onboarding.swift | OJ1, OJ2 on a scoped run | – | waits OB-4 |
| OB-12 | OB-z | 4 | Live: onboardingIsLive and SuiteOnboarding() in the slot; SuiteLiveServicesTests rows; LauncherRouter+Onboarding gives the window samplesFolder, documents, a FileManager copy; OJ3 and OJ4 written as XCTSkip("waits on OB-13") | Sources/SuiteShell/Live/OnboardingSlot.swift, Tests/AppSnapshotTests/SuiteLiveServicesTests.swift, Sources/AfterGlowApp/{LauncherRouter+Onboarding,OnboardingWindow}.swift, UITests/AfterGlowJourneyTests+OnboardingStart.swift | SuiteLiveServicesTests, OnboardingLauncherTests | – | waits OB-4, OB-7, OB-8, OB-9, OB-10 |
| OB-5g | OB-u | 5 | The goldens for Golden/afterglow-onboarding/ taken from the first macOS run's `snapshots` artifact that holds OB-5 | Tests/AppSnapshotTests/Golden/afterglow-onboarding/ | the run's compare | – | waits OB-5 and a macOS run |
| OB-13 | OB-z | 5 | Enables OJ3 and OJ4 on live (OJ3 skips naming #837 while the Flare sample is missing); blueprint prose; status built; feature-done | UITests/AfterGlowJourneyTests+OnboardingStart.swift, docs/blueprints/suite.md, docs/blueprints/suite/features/onboarding.wave.json | OJ3, OJ4 on the dev run | – | waits OB-5, OB-6, OB-11, OB-12 |

Waves (packet's Build waves, checked against dev at 4a86f5fc):
- Wave 1: OB-1 alone (every other task names its types).
- Wave 2: OB-2, OB-3, OB-11, independent (disjoint files; each needs only OB-1's merged stubs).
- Wave 3: OB-4, OB-7, OB-8, OB-9, OB-10, independent. OB-4 waits OB-3 (sits in its window); OB-7..10 wait OB-2 (they enable its tests).
- Wave 4: OB-5, OB-6, OB-12, independent. OB-5 and OB-6 wait OB-4 (they shoot and click its pages); OB-12 waits every logic task.
- Wave 5: OB-5g (goldens from the run), OB-13 (prose, feature-done).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Base `dev`, not `main`: CLAUDE.md never targets main, the lead contract says base dev, and the fast lane retargets a main PR to dev. The brief's base SHA fdaabbfb is an ancestor of origin/main (0e3c08ea) and of dev (4a86f5fc).
- Status channel is `lead/onboarding` as the brief asks; the same commits are mirrored to this session's branch `claude/task-36wu9d`.
- Builder branches are `lead/onboarding-<id>`: a `lead/onboarding/<id>` ref can't coexist with `lead/onboarding` (home lead's precedent).
- Swift was not on this machine; installed with the pinned 6.3.3 toolchain (scripts/cloud-setup.sh's recipe, resumed after a cut download) so `scripts/ci --changed` runs here.
- OB-6 and OB-12/13 journeys get their own XCTestCase classes (AfterGlowOnboardingJourneys, AfterGlowOnboardingStartJourneys), as HM-0's smoke file does: home's HM-3a class waits on #836 and may not land before this feature. The harness HM-0 (#1967) is on dev, so OB-6 waits only on OB-4.
- OB-5 split: the snapshot and budget code (OB-5) on Linux, the PNG goldens (OB-5g) from the first macOS run that holds OB-5, as home's HM-4 did; a missing golden records a known issue, never a failure.
- OB-1 also updates the suite-onboarding and suite-preferences C4 part descriptions; OB-3 the afterglow-app onboarding part (the files exist but their descriptions don't name the new types).
- #836–#839 (the sample exports) are all open and UITests/Fixtures/suite does not exist: OB-11 ships Bundle/Samples/ with no sample files yet, every SampleFilesTests row skipping by its issue number; OJ3 (open the Flare sample) skips naming #837 until it lands. Recorded under Open.
- The slice done rule read as lead.md rule 6: a dev run containing the slice's last PR with a green Linux job; a scoped `app=suite` run or a full run both count.

## Decisions (wave 2)
- The container restarted during wave 1; OB-1's PR #1998 merged at 07:05Z while the lead was down. Resumed at 10:40Z from the remote state: dev at 453198ac, two green full runs containing #1998.
- HM-3b (#2007) landed home's layout and control-sweep journeys but no shared AfterGlowJourneyTests class; OB-6 keeps its own class.

## Open
- Sample files: #836 (Design), #837 (Flare), #838 (Photo), #839 (Halo) open on their lines. Until they land, every tile's "Open sample" reads "The <App> sample isn't in this build." and OJ3 skips.
- `SuiteSize.onboardingWindow` (needs-ui, blueprint 6.3) and `AppTile` #803: OnboardingLayout in SuiteModel holds the window's numbers until they land.
- `Tests/perf-suites.txt` line `suite AppSnapshotTests.BodyCountSuites/RenderBudgetAfterGlowOnboardingTests/timing`: supervisor-only, asked for in OB-5's PR body.
