# targets lead record

Issue: #873 · Packet: docs/blueprints/suite/features/targets.md
Run: act-1a1429c87d2-exzi (resumed; first act-1a13f70dda7-kche) · Session: claude/feature-lead-targets-r13t2d · Started: 2026-10-15T12:10Z, resumed 2026-10-16T02:50Z
Stage: 4 round 1
Base: 8fce5e2 (dev with BU-1b #1263)
Next: wait on dev CI (791 red, not ours; 792 on 9230d80 pending); on the first green ci.yml run on dev whose head contains 8fce5e2, comment `Belt-Contact-Sheet: <run link>` on #873 with the size table and 'launcher has no journey shots until home'. Nothing of this feature's is red; no fix batch.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| TG-0a | 1 | C4 parts: suite-model container + 14 components (no relationships) | docs/c4/parts/creative-apps/suite-model/ (15) | scripts/ci C4 step, c4-assemble | #1131 | merged 63aa0a5 |
| TG-0b | 1 | C4 parts: 5 more suite-model components, suite-shell container + 7 components | suite-model/ (5), suite-shell/ (8) | scripts/ci | #1134 | merged 802a4ed |
| TG-0c | 1 | C4 parts: afterglow-app (6), afterglow-bundle, suite-model-tests, afterglow-journeys containers | afterglow-app/, afterglow-bundle/, suite-model-tests/, afterglow-journeys/ (13) | scripts/ci | #1135 | merged b073dac |
| BU-0 | 1 | scripts/size-report, its fixture test, macos step + artifact (supervisor merges) | scripts/size-report, Tests/size_report/, .github/workflows/ci.yml | Tests/size_report/test_size_report.sh (macos) | #1133 | merged 8e6d8ff |
| TG-0d | 2 | C4: the 23 planned relationships on new and existing container parts | 15 container.json parts | c4-assemble resolves every end | #1144 | merged |
| BU-1a | 2 | Package.swift: SuiteModel(+Tests), SuiteShell, AfterGlowApp, one file each (supervisor merges) | Package.swift + 4 files | SuiteIdentityTests | #1143 | merged ea892e2 |
| BU-1b | 3 | launcher scenes, placeholders, disabled menu stubs (lane, feature-done) | 11 under Sources/AfterGlowApp/ + LauncherMenuStubTests | LauncherMenuStubTests | #1263 | merged 8fce5e2 |
| BU-S | – | packaging spike on a Mac | docs/blueprints/suite/spike.md | supervisor review | – | supervisor/captain; not in done check |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38823898596 (8fce5e2) | Linux green; macOS build/bundle/size green; UI journeys red 19 (Halo/Photo/Library, 17 pre-existing at 75492b1, 2 from Halo #1258/#1260) | no afterglow key yet; over-baseline counts are Halo/Photo, not ours | none run: no launcher screens exist (no journey until home) | 0 for this feature | – | clean for targets; dev not green |

## Size report (run 38823898596, 8fce5e2)
| app | executable bytes | bundle bytes | SuiteUI symbols |
|---|---|---|---|
| Flare | 7,363,200 | 7,365,936 | 5,785 |
| Design | 4,415,376 | 4,418,115 | 5,831 |
| Photo | 6,434,704 | 6,437,440 | 5,854 |
| Library | 4,838,032 | 4,840,774 | 5,812 |
| Halo | 8,257,104 | 8,259,837 | 5,817 |
Executables total 31,308,416 bytes; app-builds.tar.gz 8,064,887 bytes. SuiteUI is linked into each of the five executables (about 5.8k symbols each).

## Decisions
- Round 1: no critic panel. The feature adds no screen any journey or snapshot captures (packet: no journey until home), so there is nothing for critics to read; the menu stubs are covered by LauncherMenuStubTests.
- BU-1b: AfterGlow > Settings… is the Settings scene's own working item (packet step 3: ⌘, opens Settings), not a disabled stub; LauncherCommandsSettings is an empty group for the settings feature.
- TG-0 goes in as C4 parts (docs/c4/parts/), not a model.json edit: model.json is generated now and no PR edits it; parts are lane work, so the lead opens them instead of waiting on the supervisor.
- TG-0 split in four (a, b, c, d) to keep each PR at 15 files or fewer; the new parts carry no relationships so a, b, c are independent; d adds all 23 relationships once every end exists.
- creative-engines (creative-core, planned) is left out: the bundle feature owns it and no relationship of this feature points at it.
- BU-1a waits on TG-0a/b/c: its new Sources files need C4 owners for scripts/ci to pass.
- BU-1b is built ahead on top of BU-1a's branch (not opened, its diff would carry Package.swift); BU-1b waits on BU-1a: it needs the AfterGlowApp, SuiteShell and SuiteModel targets in Package.swift.
- BU-S needs a Mac: not run by this lead (packet).

## Open
- 2026-10-16T03:40Z: run 791 (e99643c) red: Linux PhotoEditBudgetTests; macOS scripts/ci PASS, UI journeys red only in Halo (overlap, unnamed, transport, layout, parent menu), Photo (paste, merge, keep-layers) and Library (loupe). None in AfterGlowApp/SuiteShell/SuiteModel; all on #763.
- 2026-10-16T02:50Z: dev still red for others: run 791 (e99643c) Linux red on PhotoEditBudgetTests.editBudgets (Photo timing budget, #763); 792 (9230d80) queued. Waiting for a green dev run containing 8fce5e2.
- Run 785 (f3b8987, has #1143+#1133): macOS scripts/ci, bundle-apps and Size report passed. Linux failed only on PhotoEditBudgetTests.editBudgets (copy/paste p50 7.2 s vs merge 3.8 s): Photo line, a timing budget, not this feature's files; belongs to the dev-red issue.
- 2026-10-15T19:41Z: lead hit its 8 h budget waiting ~7 h on the supervisor to merge #1143 (BU-1a) and #1133 (BU-0); both merge clean on dev 6018826. BU-1b is ready on lead/targets-bu-1b (f789ca0, one commit over BU-1a 38e2c99).
- BU-1b: shared-assets must handle ⌘X/C/V/A in text fields (the stub replaces .pasteboard with disabled items); fine today, no text fields.
- Branches are lead/targets-<task>: git can't hold lead/targets/<task> next to lead/targets.
- BU-1a also creates Values/SuiteApp.swift (minimal enum) so SuiteCommands' init(app:) compiles; SC-1a #820 extends that file.
- BU-0 and BU-1a touch protected paths: plain PRs, the supervisor merges.
