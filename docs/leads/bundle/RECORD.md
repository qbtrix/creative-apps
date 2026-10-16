# bundle lead record

Issue: #1331 · Packet: docs/blueprints/suite/features/bundle.md
Run: act-1a144bb7df0-dpn3 · Session: claude/bundle-feature-lead-3ldknj · Started: 2026-10-16T12:43Z
Stage: 3 wave 1
Base: b102413d07d8e5b668f52d967491545dfd0af9d4
Next: read the wave-1 PRs (BU-2, BU-3, BU-5a, BU-5b); send any the lane comments on back to a fixer

Loop: v2 (the packet has no Slices table), with the findings queue and the 2-round cap (started after #1302 merged, 2026-10-16T04:20Z).
Depends on: none open (#809 BU-0, #810 BU-1a, #333 SH-7 all closed).

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| BU-2 | 1 | SizeReport, SizeBudget, SizeFinding, SizeGate, BundleLayout (#813) | Sources/SuiteModel/Packaging/{SizeReport,SizeGate,BundleLayout}.swift, Tests/SuiteModelTests/Packaging/{SizeGateTests,BundleLayoutTests}.swift | SizeGateTests, BundleLayoutTests | | building |
| BU-3 | 1 | Release graph in project.yml (R1), CreativeEngines re-export, journey bundle sources (#814; supervisor merges) | project.yml, Bundle/Engines/CreativeEngines.swift, Tests/SuiteModelTests/BuildGraphTests.swift | BuildGraphTests | | building |
| BU-5a | 1 | AfterGlow.plist with every suite document and exported type (#815) | Bundle/Info/AfterGlow.plist, Tests/SuiteModelTests/PlistShapeTests.swift | PlistShapeTests | | building |
| BU-5b | 1 | Info.plists for the five embedded apps (#816) | Bundle/Info/{Flare,Design,Photo,Library,Halo}.plist, Tests/SuiteModelTests/PlistShapeAppsTests.swift | PlistShapeAppsTests | | building |
| BU-5c | 2 | Placeholder icons (#817; feature-done, held until BU-4 merges) | Bundle/Icons/*.png, Bundle/Icons/README.md, Tests/SuiteModelTests/IconFilesTests.swift | IconFilesTests | | waits BU-5a, BU-5b |
| BU-4 | 3 | scripts/bundle-apps assembles and signs AfterGlow.app; size-report rows (#818; supervisor merges) | scripts/bundle-apps, scripts/size-report | dev macOS run | | waits BU-3, BU-5a, BU-5b, BU-5c |
| BU-6 | 4 | Size gate on after ten green dev runs (#819; supervisor, later; not in the done check) | .github/workflows/ci.yml, Bundle/size-budget.json | SizeGateTests | | later |

Wave 1: BU-2, BU-3, BU-5a, BU-5b, all independent (disjoint files; BU-5b's test reads only the app plists).
Wave 2: BU-5c waits on BU-5a and BU-5b (its test reads CFBundleIconFile from their plists).
Wave 3: BU-4 waits on BU-3 (the release graph it builds) and BU-5a/b/c (the plists and icons it copies).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- PRs target dev, not main: CLAUDE.md never targets main and the lane retargets main PRs to dev. Brief's main HEAD 9e3c5f8 verified; it is an ancestor of dev b102413.
- Builder branches are lead/bundle-<id> (a lead/bundle/<id> ref can't coexist with lead/bundle).
- BU-3 (project.yml) and BU-4 (scripts/) open without the fast-lane label: the packet says the supervisor merges them.
- No mutation plans (contract rule 14 is v3 only).

## Open
- none
