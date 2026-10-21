# Bundled samples

The one sample per app that the onboarding window opens (onboarding packet
OB-11, `docs/blueprints/suite/features/onboarding.md`). `SampleCatalog.samples`
in `Sources/SuiteModel/Onboarding/SampleCatalog.swift` names them, and
`scripts/bundle-apps` copies this folder into
`AfterGlow.app/Contents/Resources/Samples`.

| File | App | Made in |
|---|---|---|
| `Bounce.flare` | Flare | SS-4 |
| `Cards.design` | Design | SS-3 |
| `beach.ora` | Photo | SS-5 |
| `Sunset.png` | Library (imported) | SS-5 |
| `Intro.halo` | Halo | SS-6 |

Bounce.flare and Cards.design have landed. Cards is three card pages, each
holding its frame, with no shape or title until headless Design can add one
(#4092). Bounce's fixture copy, Title.flare and Logo.flare come next. A
missing file's tile reads "The <App> sample isn't in
this build." (sample-files packet, `docs/blueprints/suite/features/sample-files.md`)

## How a sample is made

Every sample is made, never hand-edited, by one make file in `make/`, named
after the sample it makes: `make/Cards.design.jobs.json` makes `Cards.design`.
A make file is the `afterglow run` script format
(`Sources/AfterGlowCLICore/Script.swift`) with fixed values only (no clocks, no
random seeds), so two runs give the same bytes, plus an optional `"new"`
object: the options its app's headless `new` gets.

The maker (`Tests/AfterGlowCLITests/SampleMaker.swift`; it lives in the tests
because `scripts/` is protected) seeds `seed.<native ext>` with the app's
`new`, runs the script over it headless, and takes the one file the run
writes. So a make file's `"inputs"` is `["seed.<ext>"]` and its run writes
exactly one output (the default `out/` folder and name are fine).

The sample goes to `Bundle/Samples/<name>` and its copy to
`UITests/Fixtures/suite/<name>`. A make file under `make/fixtures-only/` makes
a journey fixture the tour doesn't ship (Logo.design, Title.flare,
Logo.flare): it goes to `UITests/Fixtures/suite/<name>` only.

To write the samples after changing a make file:

```bash
MAKE_SAMPLES=1 swift test --filter SampleMakerTests
```

The check runs in `scripts/ci` with the rest of `AfterGlowCLITests`:
`SampleMakerTests.committedSamplesMatchTheirMakeFiles` rebuilds every sample
and fails when a committed copy is missing or differs byte for byte (a fixture
copy of a shipped sample is compared once it exists).
`SampleOpenTests` (`Tests/AfterGlowCLITests/SampleFilesTests.swift`) opens
each sample headless, checks its content and re-saves it; each row is turned
on by the slice that makes its file.
