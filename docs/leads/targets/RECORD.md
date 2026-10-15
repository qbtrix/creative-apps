# targets lead record

Issue: #873 · Packet: docs/blueprints/suite/features/targets.md
Run: act-1a13f70dda7-kche · Session: claude/feature-lead-targets-w8ietz · Started: 2026-10-15T12:10Z
Stage: 3 wave 1
Base: 7f6125962f93be8898cec4fd2a78e75bac280b39
Next: check the wave-1 PRs (TG-0a/b/c lane, BU-0 supervisor); when TG-0a/b/c merge, open BU-1a and TG-0d

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| TG-0a | 1 | C4 parts: suite-model container + 14 components (no relationships) | docs/c4/parts/creative-apps/suite-model/ (15) | scripts/ci C4 step, c4-assemble | | building |
| TG-0b | 1 | C4 parts: 5 more suite-model components, suite-shell container + 7 components | suite-model/ (5), suite-shell/ (8) | scripts/ci | | building |
| TG-0c | 1 | C4 parts: afterglow-app (6), afterglow-bundle, suite-model-tests, afterglow-journeys containers | afterglow-app/, afterglow-bundle/, suite-model-tests/, afterglow-journeys/ (13) | scripts/ci | | building |
| BU-0 | 1 | scripts/size-report, its fixture test, macos step + artifact (supervisor merges) | scripts/size-report, Tests/size_report/, .github/workflows/ci.yml | Tests/size_report/test_size_report.sh (macos) | | building |
| TG-0d | 2 | C4: the 23 planned relationships on new and existing container parts | 15 container.json parts | c4-assemble resolves every end | | waits TG-0a/b/c |
| BU-1a | 2 | Package.swift: SuiteModel(+Tests), SuiteShell, AfterGlowApp, one file each (supervisor merges) | Package.swift + 4 files | SuiteIdentityTests | | waits TG-0a/b/c |
| BU-1b | 3 | launcher scenes, placeholders, disabled menu stubs (lane, feature-done) | 11 under Sources/AfterGlowApp/ + LauncherMenuStubTests | LauncherMenuStubTests | | waits BU-1a |
| BU-S | – | packaging spike on a Mac | docs/blueprints/suite/spike.md | supervisor review | – | supervisor/captain; not in done check |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- TG-0 goes in as C4 parts (docs/c4/parts/), not a model.json edit: model.json is generated now and no PR edits it; parts are lane work, so the lead opens them instead of waiting on the supervisor.
- TG-0 split in four (a, b, c, d) to keep each PR at 15 files or fewer; the new parts carry no relationships so a, b, c are independent; d adds all 23 relationships once every end exists.
- creative-engines (creative-core, planned) is left out: the bundle feature owns it and no relationship of this feature points at it.
- BU-1a waits on TG-0a/b/c: its new Sources files need C4 owners for scripts/ci to pass.
- BU-1b waits on BU-1a: it needs the AfterGlowApp, SuiteShell and SuiteModel targets in Package.swift.
- BU-S needs a Mac: not run by this lead (packet).

## Open
- BU-0 and BU-1a touch protected paths: plain PRs, the supervisor merges.
