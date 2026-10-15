# targets lead record

Issue: #873 · Packet: docs/blueprints/suite/features/targets.md
Run: act-1a13f70dda7-kche · Session: claude/feature-lead-targets-w8ietz · Started: 2026-10-15T12:10Z
Stage: 3 wave 2
Base: b073dac (dev after TG-0c)
Next: when #1143 merges, rebase lead/targets-bu-1b on origin/dev, rerun scripts/ci, open BU-1b with fast-lane + feature-done

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| TG-0a | 1 | C4 parts: suite-model container + 14 components (no relationships) | docs/c4/parts/creative-apps/suite-model/ (15) | scripts/ci C4 step, c4-assemble | #1131 | merged 63aa0a5 |
| TG-0b | 1 | C4 parts: 5 more suite-model components, suite-shell container + 7 components | suite-model/ (5), suite-shell/ (8) | scripts/ci | #1134 | merged 802a4ed |
| TG-0c | 1 | C4 parts: afterglow-app (6), afterglow-bundle, suite-model-tests, afterglow-journeys containers | afterglow-app/, afterglow-bundle/, suite-model-tests/, afterglow-journeys/ (13) | scripts/ci | #1135 | merged b073dac |
| BU-0 | 1 | scripts/size-report, its fixture test, macos step + artifact (supervisor merges) | scripts/size-report, Tests/size_report/, .github/workflows/ci.yml | Tests/size_report/test_size_report.sh (macos) | #1133 | open, supervisor merges |
| TG-0d | 2 | C4: the 23 planned relationships on new and existing container parts | 15 container.json parts | c4-assemble resolves every end | #1144 | merged |
| BU-1a | 2 | Package.swift: SuiteModel(+Tests), SuiteShell, AfterGlowApp, one file each (supervisor merges) | Package.swift + 4 files | SuiteIdentityTests | #1143 | open, supervisor merges |
| BU-1b | 3 | launcher scenes, placeholders, disabled menu stubs (lane, feature-done) | 11 under Sources/AfterGlowApp/ + LauncherMenuStubTests | LauncherMenuStubTests | | built f789ca0 on lead/targets-bu-1b over BU-1a, CI: PASS; PR opens after #1143 merges |
| BU-S | – | packaging spike on a Mac | docs/blueprints/suite/spike.md | supervisor review | – | supervisor/captain; not in done check |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- BU-1b: AfterGlow > Settings… is the Settings scene's own working item (packet step 3: ⌘, opens Settings), not a disabled stub; LauncherCommandsSettings is an empty group for the settings feature.
- TG-0 goes in as C4 parts (docs/c4/parts/), not a model.json edit: model.json is generated now and no PR edits it; parts are lane work, so the lead opens them instead of waiting on the supervisor.
- TG-0 split in four (a, b, c, d) to keep each PR at 15 files or fewer; the new parts carry no relationships so a, b, c are independent; d adds all 23 relationships once every end exists.
- creative-engines (creative-core, planned) is left out: the bundle feature owns it and no relationship of this feature points at it.
- BU-1a waits on TG-0a/b/c: its new Sources files need C4 owners for scripts/ci to pass.
- BU-1b is built ahead on top of BU-1a's branch (not opened, its diff would carry Package.swift); BU-1b waits on BU-1a: it needs the AfterGlowApp, SuiteShell and SuiteModel targets in Package.swift.
- BU-S needs a Mac: not run by this lead (packet).

## Open
- Waiting on the supervisor to merge #1143 (BU-1a) and #1133 (BU-0).
- BU-1b: shared-assets must handle ⌘X/C/V/A in text fields (the stub replaces .pasteboard with disabled items); fine today, no text fields.
- Branches are lead/targets-<task>: git can't hold lead/targets/<task> next to lead/targets.
- BU-1a also creates Values/SuiteApp.swift (minimal enum) so SuiteCommands' init(app:) compiles; SC-1a #820 extends that file.
- BU-0 and BU-1a touch protected paths: plain PRs, the supervisor merges.
