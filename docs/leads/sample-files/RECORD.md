# sample-files lead record

Issue: #3775 · Packet: docs/blueprints/suite/features/sample-files.md
Run: act-1a15ef24f0e-t1j1 · Session: cse_01Mv9wxYxE6yTZhCjfP2rdUH · Started: 2026-10-21T14:56Z
Stage: 3 wave 4
Base: 9951eea7355e5a768f0ce1e1bad25656cf05cd82
Next: #4100 merged (9a4ac8828, batch 20261021190945). #4112 (head 9d44e115c) and #4115 (head 4b2f2212c) have dev merged in, CI PASS, are ready and target dev. #4129 holds the pre-restack heads of both, so it stays a draft until both merge; then merge dev in, keep ours, CI, move Head:, ready. Belt-Slice-Done SS-vector once a green dev Linux run contains #4112's merge, SS-raster for #4115's; then SS-z, then Belt-Contact-Sheet.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SS-a | make step turns each sample script into its file; the per-file open check is written, disabled | SS-1, SS-2 | MJ-SS | – | no | 0 | merged #4094 (e78df8233) | – | – |
| SS-vector | Cards/Logo .design and Bounce/Title/Logo .flare made by script, committed, open | SS-3, SS-4 | MJ-SS | SS-a | no | 0 | #4100 merged 9a4ac8828; #4112 merged 0c435e275 | – | – |
| SS-raster | beach.ora, Sunset.png, Intro.halo made by script, committed, open | SS-5, SS-6 | MJ-SS | SS-a, SS-vector | no | 0 | ready #4115 (beach.ora held on #4113) | – | – |
| SS-z | every tour tile opens its sample; RJ-X66; feature built | SS-7, SS-8 | XJ-SS, MJ-SS | SS-vector, SS-raster | no | 0 | pr-open #4129 (feature-done) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SS-1 | SS-a | 1 | SampleFilesTests (AfterGlowCLITests): each catalog sample is in Bundle/Samples, opens headless, has its content, re-saves; disabled per file | Tests/AfterGlowCLITests/SampleFilesTests.swift | itself (compiles, disabled by name) | #4094 | pr-open |
| SS-2 | SS-a | 1 | make step: runs Bundle/Samples/make/*.jobs.json through AfterGlowCLICore into Bundle/Samples and UITests/Fixtures/suite; check mode fails on a stale sample (Swift test, not scripts/make-samples, see Decisions) | Tests/AfterGlowCLITests/SampleFilesTests.swift (or a sibling file), Bundle/Samples/README.md | make check on an empty make folder passes; a stale sample fails | #4094 | pr-open |
| SS-3 | SS-vector | 2 | Design: Cards and Logo scripts and files; rows on | Bundle/Samples/make/Cards.design.jobs.json, Bundle/Samples/make/Logo.design.jobs.json, Bundle/Samples/Cards.design, UITests/Fixtures/suite/Cards.design, UITests/Fixtures/suite/Logo.design, Tests/AfterGlowCLITests/SampleFilesTests.swift | SampleFilesTests.testCards, .testLogoDesign | #4100 | pr-open |
| SS-4 | SS-vector | 2 | Flare: Bounce (position and scale keys, 2 s loop), Title, Logo; rows on | Bundle/Samples/make/Bounce.flare.jobs.json, Bundle/Samples/make/Title.flare.jobs.json, Bundle/Samples/make/Logo.flare.jobs.json, Bundle/Samples/Bounce.flare, UITests/Fixtures/suite/Bounce.flare, UITests/Fixtures/suite/Title.flare, UITests/Fixtures/suite/Logo.flare | SampleFilesTests.testBounce, .testTitle, .testLogoFlare | #4100 (Bounce); Title/Logo fixtures in #4112 (SS-vector-b); Bounce fixture copy in SS-z | pr-open |
| SS-5 | SS-raster | 3 | Photo: beach.ora (gradient, second layer, adjustment) and Sunset.png (flattened export); rows on | Bundle/Samples/make/beach.ora.jobs.json, Bundle/Samples/make/Sunset.png.jobs.json, Bundle/Samples/beach.ora, Bundle/Samples/Sunset.png, UITests/Fixtures/suite/beach.ora, UITests/Fixtures/suite/Sunset.png, Tests/AfterGlowCLITests/SampleFilesTests.swift | SampleFilesTests.testBeach, .testSunset | #4115 (Sunset; beach held on #4113) | pr-open |
| SS-6 | SS-raster | 3 | Halo: Intro (5 s comp, solid, title text with opacity fade, shape sliding in); row on | Bundle/Samples/make/Intro.halo.jobs.json, Bundle/Samples/Intro.halo, UITests/Fixtures/suite/Intro.halo | SampleFilesTests.testIntro | #4115 | pr-open |
| SS-7 | SS-z | 4 | journey testOpenEverySample; RJ-X66 job folder | UITests/AfterGlowJourneyTests+Onboarding.swift, Tests/RealJobs/suite/open-samples/open-samples.jobs.json | XJ-SS; RJ-X66 on Linux | #4129 | pr-open |
| SS-8 | SS-z | 4 | status built; feature-done | docs/blueprints/suite/features/sample-files.wave.json | scripts/waves render --dry-run | #4129 | pr-open |

Wave plan (one PR per slice, brief rule 10; each slice PR stacks on the one before as a draft until it merges):
- Wave 1: SS-a (SS-1 + SS-2). Independent of shell-text.
- Wave 2: SS-vector (SS-3 + SS-4). Waits on SS-a: needs the check file and the make step.
- Wave 3: SS-raster (SS-5 + SS-6). Waits on SS-vector: the same check file.
- Wave 4: SS-z (SS-7 + SS-8). Waits on every sample file.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- After a parent squash-merges, the child merges origin/dev (keeping its own side of the add/add conflicts in Bundle/Samples/README.md and SampleFilesTests.swift, which already carry the parent), reruns scripts/ci --changed, moves Head:, and leaves draft. No rebase, no force-push.
- SS-vector split over the 400-line cap: the generated Flare files are large; the follow-up is the same slice (Slice: SS-vector).
- Base is origin/dev (3f96cd10c74f0eb4da8641e8fe511a2e5e42a466), not main (0dd23d6, verified as the brief's step one): main is 248 commits behind dev, this packet exists only on dev, CLAUDE.md and lead.md target dev, and the lane retargets main PRs to dev.
- The packet's scripts/make-samples is a protected path (fast lane refuses scripts/), so the make step and its --check mode are Swift code in AfterGlowCLITests: the check runs as a test inside scripts/ci, regeneration runs the same code with MAKE_SAMPLES=1. SS-7 then needs no scripts/ci edit.
- afterglow run takes only a .jobs.json path (app and output live in the JSON) and every input must exist, so each make script seeds its input with the app's headless new; make files are named <sample>.jobs.json.
- SampleCatalog names five files; Logo.design, Title.flare and Logo.flare are journey fixtures only (UITests/Fixtures/suite), not catalog samples.
- Design's catalog has no command that adds a shape or text with geometry (tool.* only pick a tool), so Cards.design is limited to what headless Design can make; gap #4092 (line:design) asks for frame/shape/text commands.
- Tests/SuiteModelTests/SampleFilesTests.swift already checks presence per file (disabled rows #836–#839); each sample slice turns its row on there too.
- The proxy appends an attribution footer to every gh api body write; final PR/issue/comment bodies are set through the GitHub MCP update tools, which don't.
- Waves are 1 to 2 tasks with nothing alongside, so each runs as one worktree subagent (lead.md stage 3).

## Open
- #4129 (SS-z, draft on #4115 + #4112, feature-done): journey testOpenEverySample (XCTSkip naming #4113 until beach.ora ships); RJ-X66 as three jobs in Tests/RealJobs/{flare,design,halo}/open-sample/ (the harness takes <app>/<job>/ only; Photo held on #4113, Library opens catalogs); Bounce fixture copy; wave.json built. The packet's scripts/ci hook for make --check is protected: for the supervisor (the maker test already fails on a stale sample). 389 lines over its parents.
- #4112 (SS-vector-b, draft on #4100): Title.flare and Logo.flare fixtures with their fixtures-only make files; 231 lines over #4100.
- #4115 (SS-raster, draft on #4100): Sunset.png and Intro.halo with make files and fixtures; 66 lines over #4100. beach.ora held: #4113 gap (line:photo, p1) .ora save is not byte-stable (adjustment set in hash order); its make file is in scratchpad/beach.ora.jobs.json. testBeach and beachOra rows stay disabled, pointing at #4113.
- #4114 gap (line:halo, p2): headless text.set-color refuses solid and shape layers; Intro's solid and shape keep default colors.
- #4100 (SS-vector, draft on #4094): Cards.design, Logo.design fixture, Bounce.flare. Flare files are pretty JSON, the full slice was 808 lines, so Title/Logo.flare fixtures go in a follow-up PR (SS-vector-b, make files kept in scratchpad/deferred) and Bounce's UITests fixture copy rides with SS-z.
- #4108 gap (line:flare): headless Flare commands only reach layer id layer-1; make files use layer-1/layer-2.
- Belt reads lead/suite-<feature> with docs/leads/suite-<feature>/; every record push mirrors to both names.
- #4094 (SS-a): merged as e78df8233 at ~17:15Z. Its disabled count asserts (Cards ≥6 layers, Bounce 2 s, beach 3 layers, Intro 5 s and 3 layers) are the builder's reading; later slices may adjust them. Fixture-only make files live in Bundle/Samples/make/fixtures-only/. scripts/bundle-apps copies all of Bundle/Samples (make/ and README ship in bundles): protected script, noted for the supervisor.
- #4092 gap (line:design): headless Design commands that add content; Cards.design stays minimal until it lands.
- dev-red #3856 (Photo CommandPathTests, Flare SetLayerParent): not this feature's.
