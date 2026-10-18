# Bundled samples

The one sample per app that the onboarding window opens (onboarding packet
OB-11, `docs/blueprints/suite/features/onboarding.md`). `SampleCatalog.samples`
in `Sources/SuiteModel/Onboarding/SampleCatalog.swift` names them, and
`scripts/bundle-apps` copies this folder into
`AfterGlow.app/Contents/Resources/Samples`.

Each file is a copy of an app line's suite fixture export in
`UITests/Fixtures/suite/`. None has landed yet, so the folder ships without
them; a missing file's tile reads "The <App> sample isn't in this build."

| File | App | Filled by |
|---|---|---|
| `Bounce.flare` | Flare | #837 (A-FL-0) |
| `Cards.design` | Design | #836 (A-DE-0) |
| `beach.ora` | Photo | #838 (A-PH-0) |
| `Sunset.png` | Library (imported) | #838 (A-PH-0) |
| `Intro.halo` | Halo | #839 (A-HA-0) |

When an export lands, copy it here unchanged and remove its row's
`.disabled` in `Tests/SuiteModelTests/SampleFilesTests.swift`, which checks
that each file is present, non-empty and has its type's extension.
