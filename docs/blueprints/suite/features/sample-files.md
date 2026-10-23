# Feature packet: sample-files

**Feature:** a first launch that shows the apps working. The onboarding tour
already has an Open sample tile per app (`SampleCatalog`), but
`Bundle/Samples/` holds only its README, so every tile reads "The <App> sample
isn't in this build." This packet makes the five samples with `afterglow`
scripts (one JSON script per file under `Bundle/Samples/make/`, run headless by
`scripts/make-samples`), commits the results to `Bundle/Samples/` (which
`scripts/bundle-apps` already copies) and to `UITests/Fixtures/suite/` (the
suite journeys' fixtures, #836 to #839), and checks each one opens in its app.
A script, not a hand-made file, so a format change rebuilds the samples in one
command and a review sees what each sample contains.
**Line:** `line:suite` · **Wave:** BG1 (`waves.md`, the beta gaps) · **Lead branch:** `lead/sample-files`
**Beta:** captain, 2026-10-21 (beta gaps, suite must-haves). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` suite must-have "sample files for
the welcome tour (#836 to #839)"; suite audit row 9; #836 (Logo.design and
Cards.design), #837 (Bounce, Title and Logo `.flare`), #838 (beach.ora and
Sunset.png), #839 (Intro.halo), each closed by its slice; RJ-X66 (new).

**Depends on:** onboarding (built: `SampleCatalog`, the tour's tiles),
afterglow-cli (built: `afterglow run <app> --script`). The scripts use only
commands each app's catalog has on dev; a sample needing a later feature (a
gradient in Cards) waits for it in a later build, never in this packet.

**Rule 20.** No sample-making code in an app: the samples are made through the
same catalog an agent uses.

**C4:** none (`Bundle/` is the bundle's input part already).

**Clean-room.** The art in each sample is drawn by its script (shapes, text,
a generated gradient photo); no third-party image is shipped.

Blueprint sections: suite.md (onboarding), the onboarding packet's OB-11.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SS-a | A make script turns each sample's afterglow script into its file, and the check that every catalog sample exists and opens headless is written and disabled. | SS-1, SS-2 | MJ-SS | – |
| SS-vector | Cards.design and Logo.design (#836) and Bounce.flare, Title.flare and Logo.flare (#837) are made by script, committed, and open in Design and Flare. | SS-3, SS-4 | MJ-SS | SS-a |
| SS-raster | beach.ora and Sunset.png (#838) and Intro.halo (#839) are made by script, committed, and open in Photo, Library and Halo. | SS-5, SS-6 | MJ-SS | SS-a; SS-vector (`SampleFilesTests.swift`) |
| SS-z | Every tour tile opens its sample on a first launch, RJ-X66 passes, and the feature is built. | SS-7, SS-8 | XJ-SS, MJ-SS | SS-vector, SS-raster |

**Order.** The two sample slices share `SampleFilesTests.swift` (each turns
its rows on), so SS-raster waits on SS-vector. SS-7 edits `scripts/ci`, a
supervisor merge (CI files are off the fast lane).

## Journey steps

`MJ-SS` on Linux (`SampleFilesTests`), then:
1. Launch AfterGlow on a clean support folder; the tour's Open sample tile for each app opens that app with its sample; Home's recents list them (SS-7; `XJ-SS`, `AfterGlowOnboardingJourneyTests.testOpenEverySample`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X66 | adds, closes with `suite/sample-files` | C | `Tests/RealJobs/suite/open-samples/`: open each of the five bundled samples headless with its app, export a PNG of each | `Bundle/Samples/` |

Trap: a sample that exists but is stale (written by an older format, or empty
after a model change), so the tour opens a blank canvas. Assertion: each
export has more than 10% non-background pixels, Bounce's PNG at frame 15
differs from frame 0, and `scripts/make-samples --check` reports no drift.
SS-7 writes the check.

## Screens and states

`onboarding-samples-all-present` (the tour page with five live tiles).

## Contract slice

`scripts/make-samples [--check]`: for each `Bundle/Samples/make/<file>.json`
run `afterglow run <app> --script <it> --out Bundle/Samples/<file>`, then copy
to `UITests/Fixtures/suite/`. A script is the CLI's existing script format
(`AfterGlowCLICore/Script.swift`), so no new format. `SampleCatalog` (built)
is unchanged: the files it names now exist.

## Pseudocode

- **Determinism.** Scripts use fixed seeds and no clocks, so two runs give the
  same bytes and `--check` can compare them.
- **Library's sample.** Sunset.png is an image, not a catalog: the tour's
  Library tile imports it into the person's catalog (OB-10), so no catalog
  file ships.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SS-1 | – | **Check first.** `SampleFilesTests` (AfterGlowCLITests): each `SampleCatalog` file is in `Bundle/Samples/`, opens with its app's headless open, has the content the script promises (layers, frames, a text layer) and re-saves without error; disabled per file by name until its slice | `Tests/AfterGlowCLITests/SampleFilesTests.swift` | – | ~120, 1 |
| SS-2 | – | `scripts/make-samples`: runs every `Bundle/Samples/make/*.json` through `afterglow run` into `Bundle/Samples/` and copies each into `UITests/Fixtures/suite/`; `--check` rebuilds into a temp folder and fails when a committed sample differs | `scripts/make-samples`, `Bundle/Samples/README.md` | SS-1 | ~110, 2 |
| SS-3 | – | Design's scripts and files: Cards (three 1080 × 1350 cards with shapes and titles) and Logo; `SampleFilesTests` on for both | `Bundle/Samples/make/Cards.design.json`, `Bundle/Samples/make/Logo.design.json`, `Bundle/Samples/Cards.design`, `UITests/Fixtures/suite/Cards.design`, `UITests/Fixtures/suite/Logo.design`, `Tests/AfterGlowCLITests/SampleFilesTests.swift` | SS-2 | ~180, 6 |
| SS-4 | – | Flare's scripts and files: Bounce (a ball with position and scale keys, 2 s loop), Title and Logo; `SampleFilesTests` on for the three | `Bundle/Samples/make/Bounce.flare.json`, `Bundle/Samples/make/Title.flare.json`, `Bundle/Samples/make/Logo.flare.json`, `Bundle/Samples/Bounce.flare`, `UITests/Fixtures/suite/Bounce.flare`, `UITests/Fixtures/suite/Title.flare`, `UITests/Fixtures/suite/Logo.flare` | SS-2, SS-3 | ~200, 7 |
| SS-5 | – | Photo's script and files: beach (a generated sky-to-sand gradient photo, a second pixel layer and an Exposure adjustment layer) and Sunset.png (the flattened export Library imports); `SampleFilesTests` on for both | `Bundle/Samples/make/beach.ora.json`, `Bundle/Samples/make/Sunset.png.json`, `Bundle/Samples/beach.ora`, `Bundle/Samples/Sunset.png`, `UITests/Fixtures/suite/beach.ora`, `UITests/Fixtures/suite/Sunset.png`, `Tests/AfterGlowCLITests/SampleFilesTests.swift` | SS-4 | ~170, 7 |
| SS-6 | – | Halo's script and file: Intro (a 5 s comp, a solid, a title text layer with an opacity fade and a shape layer sliding in); `SampleFilesTests` on | `Bundle/Samples/make/Intro.halo.json`, `Bundle/Samples/Intro.halo`, `UITests/Fixtures/suite/Intro.halo` | SS-5 | ~120, 3 |
| SS-7 | – | `AfterGlowOnboardingJourneyTests.testOpenEverySample` (each tile opens its app with the sample, none shows the missing reason); RJ-X66's job folder, enabled; `scripts/make-samples --check` added to `scripts/ci`'s docs-and-data checks | `UITests/AfterGlowJourneyTests+Onboarding.swift`, `Tests/RealJobs/suite/open-samples/open-samples.jobs.json`, `scripts/ci` | SS-6 | ~120, 3 |
| SS-8 | – | `status: built`; `feature-done` | `docs/blueprints/suite/features/sample-files.wave.json` | SS-7 | ~10, 1 |

## Build waves

- Wave 1: SS-1. Independent in this wave: SS-1 alone.
- Wave 2: SS-2. Independent in this wave: SS-2 alone.
- Wave 3: SS-3. Independent in this wave: SS-3 alone.
- Wave 4: SS-4. Independent in this wave: SS-4 alone.
- Wave 5: SS-5. Independent in this wave: SS-5 alone.
- Wave 6: SS-6. Independent in this wave: SS-6 alone.
- Wave 7: SS-7. Independent in this wave: SS-7 alone.
- Wave 8: SS-8. Independent in this wave: SS-8 alone.

Longest chain: SS-1 → SS-2 → SS-3 → SS-4 → SS-5 → SS-6 → SS-7 → SS-8 (8). Chain of 8: the check, the make script, then each sample in turn (they share the check file), the journey and the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| SS-1 | compiles, disabled by name | a sample could be missing or broken without a red test | – (test) |
| SS-2 | `scripts/make-samples --check` on an empty make folder passes | a stale sample would pass | – (script) |
| SS-3 | `SampleFilesTests.testCards`, `.testLogoDesign` | the file is missing or opens empty | – (fixtures) |
| SS-4 | `SampleFilesTests.testBounce` (keys at 0, 30, 60), `.testTitle`, `.testLogoFlare` | the bounce has no keys or the loop is off | – (fixtures) |
| SS-5 | `SampleFilesTests.testBeach` (three layers), `.testSunset` (imports into a fresh catalog) | a layer is missing or the PNG won't import | – (fixtures) |
| SS-6 | `SampleFilesTests.testIntro` (three layers, keys on the title) | the comp opens empty or unkeyed | – (fixtures) |
| SS-7 | `XJ-SS`; RJ-X66 on Linux; `scripts/ci` runs the samples check | a tile still says the sample isn't in this build | – (journey and job) |
| SS-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| bundle size | the five samples add under 5 MB | `scripts/size-report` (existing) |
| reproducible | `make-samples --check` clean on CI | `scripts/ci` (SS-7) |
| first launch | every tile opens its app within the launch budget | `AfterGlowOnboardingJourneyTests.testOpenEverySample` |

## Done check

Per slice (rules 6, 21, 22): each sample slice merged-done when its
`SampleFilesTests` rows are on and green on Linux and its issue (#836 to #839)
is closed by the PR; SS-z when the journey and RJ-X66 are green. Then
`Belt-Contact-Sheet:` with the tour page.
