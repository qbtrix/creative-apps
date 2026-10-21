# sample-files lead record

Issue: #3775 · Packet: docs/blueprints/suite/features/sample-files.md
Run: act-1a15ef24f0e-t1j1 · Session: cse_01Mv9wxYxE6yTZhCjfP2rdUH · Started: 2026-10-21T14:56Z
Stage: 3 wave 1
Base: 3f96cd10c74f0eb4da8641e8fe511a2e5e42a466
Next: SS-a builder (SS-1 + SS-2, one PR) is running; on its PR, stack SS-vector (SS-3 + SS-4) as a draft on it

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SS-a | make step turns each sample script into its file; the per-file open check is written, disabled | SS-1, SS-2 | MJ-SS | – | no | 0 | building | – | – |
| SS-vector | Cards/Logo .design and Bounce/Title/Logo .flare made by script, committed, open | SS-3, SS-4 | MJ-SS | SS-a | no | 0 | planned | – | – |
| SS-raster | beach.ora, Sunset.png, Intro.halo made by script, committed, open | SS-5, SS-6 | MJ-SS | SS-a, SS-vector | no | 0 | planned | – | – |
| SS-z | every tour tile opens its sample; RJ-X66; feature built | SS-7, SS-8 | XJ-SS, MJ-SS | SS-vector, SS-raster | no | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SS-1 | SS-a | 1 | SampleFilesTests (AfterGlowCLITests): each catalog sample is in Bundle/Samples, opens headless, has its content, re-saves; disabled per file | Tests/AfterGlowCLITests/SampleFilesTests.swift | itself (compiles, disabled by name) | – | building |
| SS-2 | SS-a | 1 | make step: runs Bundle/Samples/make/*.jobs.json through AfterGlowCLICore into Bundle/Samples and UITests/Fixtures/suite; check mode fails on a stale sample (Swift test, not scripts/make-samples, see Decisions) | Tests/AfterGlowCLITests/SampleFilesTests.swift (or a sibling file), Bundle/Samples/README.md | make check on an empty make folder passes; a stale sample fails | – | building |
| SS-3 | SS-vector | 2 | Design: Cards and Logo scripts and files; rows on | Bundle/Samples/make/Cards.design.jobs.json, Bundle/Samples/make/Logo.design.jobs.json, Bundle/Samples/Cards.design, UITests/Fixtures/suite/Cards.design, UITests/Fixtures/suite/Logo.design, Tests/AfterGlowCLITests/SampleFilesTests.swift | SampleFilesTests.testCards, .testLogoDesign | – | planned |
| SS-4 | SS-vector | 2 | Flare: Bounce (position and scale keys, 2 s loop), Title, Logo; rows on | Bundle/Samples/make/Bounce.flare.jobs.json, Bundle/Samples/make/Title.flare.jobs.json, Bundle/Samples/make/Logo.flare.jobs.json, Bundle/Samples/Bounce.flare, UITests/Fixtures/suite/Bounce.flare, UITests/Fixtures/suite/Title.flare, UITests/Fixtures/suite/Logo.flare | SampleFilesTests.testBounce, .testTitle, .testLogoFlare | – | planned |
| SS-5 | SS-raster | 3 | Photo: beach.ora (gradient, second layer, adjustment) and Sunset.png (flattened export); rows on | Bundle/Samples/make/beach.ora.jobs.json, Bundle/Samples/make/Sunset.png.jobs.json, Bundle/Samples/beach.ora, Bundle/Samples/Sunset.png, UITests/Fixtures/suite/beach.ora, UITests/Fixtures/suite/Sunset.png, Tests/AfterGlowCLITests/SampleFilesTests.swift | SampleFilesTests.testBeach, .testSunset | – | planned |
| SS-6 | SS-raster | 3 | Halo: Intro (5 s comp, solid, title text with opacity fade, shape sliding in); row on | Bundle/Samples/make/Intro.halo.jobs.json, Bundle/Samples/Intro.halo, UITests/Fixtures/suite/Intro.halo | SampleFilesTests.testIntro | – | planned |
| SS-7 | SS-z | 4 | journey testOpenEverySample; RJ-X66 job folder | UITests/AfterGlowJourneyTests+Onboarding.swift, Tests/RealJobs/suite/open-samples/open-samples.jobs.json | XJ-SS; RJ-X66 on Linux | – | planned |
| SS-8 | SS-z | 4 | status built; feature-done | docs/blueprints/suite/features/sample-files.wave.json | scripts/waves render --dry-run | – | planned |

Wave plan (one PR per slice, brief rule 10; each slice PR stacks on the one before as a draft until it merges):
- Wave 1: SS-a (SS-1 + SS-2). Independent of shell-text.
- Wave 2: SS-vector (SS-3 + SS-4). Waits on SS-a: needs the check file and the make step.
- Wave 3: SS-raster (SS-5 + SS-6). Waits on SS-vector: the same check file.
- Wave 4: SS-z (SS-7 + SS-8). Waits on every sample file.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev (3f96cd10c74f0eb4da8641e8fe511a2e5e42a466), not main (0dd23d6, verified as the brief's step one): main is 248 commits behind dev, this packet exists only on dev, CLAUDE.md and lead.md target dev, and the lane retargets main PRs to dev.
- The packet's scripts/make-samples is a protected path (fast lane refuses scripts/), so the make step and its --check mode are Swift code in AfterGlowCLITests: the check runs as a test inside scripts/ci, regeneration runs the same code with MAKE_SAMPLES=1. SS-7 then needs no scripts/ci edit.
- afterglow run takes only a .jobs.json path (app and output live in the JSON) and every input must exist, so each make script seeds its input with the app's headless new; make files are named <sample>.jobs.json.
- SampleCatalog names five files; Logo.design, Title.flare and Logo.flare are journey fixtures only (UITests/Fixtures/suite), not catalog samples.
- Design's catalog has no command that adds a shape or text with geometry (tool.* only pick a tool), so Cards.design is limited to what headless Design can make; a gap issue on line:design asks for it.
- Tests/SuiteModelTests/SampleFilesTests.swift already checks presence per file (disabled rows #836–#839); each sample slice turns its row on there too.
- Waves are 1 to 2 tasks with nothing alongside, so each runs as one worktree subagent (lead.md stage 3).

## Open
- dev-red #3856 (Photo CommandPathTests, Flare SetLayerParent): not this feature's.
