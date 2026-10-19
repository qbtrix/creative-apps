# bundle lead record

Issue: #1331 · Packet: docs/blueprints/suite/features/bundle.md
Run: act-1a14c1f550d-8dvt (line lead for suite-contracts, bundle, home; was act-1a14bc85382-m8og, act-1a14ad585d6-dlpz, act-1a149c6a2a3-yna2, act-1a14881ad5e-axoa, act-1a144bb7df0-dpn3) · Session: session_01FgHMdTN1ZvtNhGw81uzVWU (claude/feature-lead-suite-contracts-z0ynwa; was session_01WeQwKxFmpontDYTdMSub85) · Started: 2026-10-16T12:43Z · Resumed: 2026-10-17T06:17Z, 2026-10-17T12:13Z, 2026-10-17T17:08Z, 2026-10-17T21:34Z, 2026-10-17T23:09Z
Stage: 5 contact sheet
Base: 4a86f5fcff2f2cc18748a93e39f1491c6ae5c745 (dev at scoped run 39008864548, which holds #1966)
Next: parked (needs-human) until the supervisor un-parks. At 2026-10-18T06:42Z: No supervisor reply on #1331/#1332/#1503. Full CI 39098181461 (e01529f4, now main) finished: Linux green, macOS failed the same 4 AfterGlow journeys (3rd run); re-raised on #1503 (issuecomment-6246651967). dev-red #2667 is Library's LibraryLoupeBudgetTests.focusChangeWithinBudget, not this line. No open finding. After the supervisor's call on #1503: file the 4 as finding (Feature: home), fix wave, then Belt-Contact-Sheet from the next full run's ui-test. #2099 (supervisor-owned) still open.

Loop: v2 (the packet has no Slices table), with the findings queue and the 2-round cap (started after #1302 merged, 2026-10-16T04:20Z).
Depends on: none open (#809 BU-0, #810 BU-1a, #333 SH-7 all closed).

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| BU-2 | 1 | SizeReport, SizeBudget, SizeFinding, SizeGate, BundleLayout (#813) | Sources/SuiteModel/Packaging/{SizeReport,SizeGate,BundleLayout}.swift, Tests/SuiteModelTests/Packaging/{SizeGateTests,BundleLayoutTests}.swift | SizeGateTests, BundleLayoutTests | #1357 | merged |
| BU-3 | 1 | Release graph in project.yml (R1), CreativeEngines re-export, journey bundle sources (#814; supervisor merges) | project.yml, Bundle/Engines/CreativeEngines.swift, Tests/SuiteModelTests/BuildGraphTests.swift | BuildGraphTests | #1358 | merged |
| BU-5a | 1 | AfterGlow.plist with every suite document and exported type (#815) | Bundle/Info/AfterGlow.plist, Tests/SuiteModelTests/PlistShapeTests.swift | PlistShapeTests | #1360 | merged |
| BU-5b | 1 | Info.plists for the five embedded apps (#816) | Bundle/Info/{Flare,Design,Photo,Library,Halo}.plist, Tests/SuiteModelTests/PlistShapeAppsTests.swift | PlistShapeAppsTests | #1361 | merged |
| BU-5c | 2 | Placeholder icons (#817; feature-done, held until BU-4 merges) | Bundle/Icons/*.png, Bundle/Icons/README.md, Tests/SuiteModelTests/IconFilesTests.swift | IconFilesTests | #1392 | merged |
| BU-4 | 3 | scripts/bundle-apps assembles and signs AfterGlow.app; size-report rows (#818; supervisor merges) | scripts/bundle-apps, scripts/size-report | dev macOS run | #1445 | merged |
| done | 4 | bundle.wave.json status built, feature-done | docs/blueprints/suite/features/bundle.wave.json | scripts/ci | #1966 | merged 03:58Z (e251c5c5) |
| BU-6 | 4 | Size gate on after ten green dev runs (#819; supervisor, later; not in the done check) | .github/workflows/ci.yml, Bundle/size-budget.json | SizeGateTests | | later |

Wave 1: BU-2, BU-3, BU-5a, BU-5b, all independent (disjoint files; BU-5b's test reads only the app plists).
Wave 2: BU-5c waits on BU-5a and BU-5b (its test reads CFBundleIconFile from their plists).
Wave 3: BU-4 waits on BU-3 (the release graph it builds) and BU-5a/b/c (the plists and icons it copies).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 39008864548 (4a86f5fc, scoped: suite) | bundle-apps, otool -L, codesign green | no bundle screens | clarity, oracle, quality, packet conformance, robustness | 5 minor: #2050 #2051 #2052 #2053 #2054 | fix round 1: #2072 (#2052), #2073 (#2050 #2051); #2053 #2054 supervisor | no |
| 2 | 39038456229 (8e868417, scoped: suite) | green | no bundle screens | clarity, oracle, quality, packet conformance, robustness | #2050-#2052 fixes hold (tests fail on each regression); 2 minor: #2104 #2105 | fix round 2: #2111 (merged 15:25Z, f50448c4) | no; cap reached: #2053 #2054 relabelled gap |

## Decisions
- Line lead act-1a14c1f550d-8dvt (2026-10-17T23:10Z): main HEAD 59c435a6 verified. The supervisor parked #1331, #1332 and #1503 with needs-human at 23:07Z ("supervisor un-parks after Mac verification"), so this run builds nothing and leaves the label. The Halo journey regression blamed on #2073 is refuted: scoped: halo run 39045670179 (dd7ec767, which contains #2073's 6fe25c81) is green, and #2077 to #2081 closed as passing. Posted on #1331.
- Line lead act-1a14bc85382-m8og (2026-10-17T21:34Z): main HEAD c55fad78 verified (= dev's run head). The brief's rebase of lead/<feature> onto origin/main is done as one commit on origin/main carrying docs/leads/<feature>/ from the old branch (the clone is shallow and the old branch shares no base with main; its only own content is this record), pushed with --force-with-lease.
- Done check reading (line lead, 2026-10-17): #1966 (feature-done) triggered full run 39000814995 on e251c5c5: Linux green, Promote moved main; its macOS job failed `scripts/ci` on `scripts/ci-findings`' stub-gh tests (scripts/, not this feature) and skipped bundle-apps. The bundle's own proof is the scoped: suite run 39008864548 on 4a86f5fc (holds #1966): `scripts/bundle-apps` passed its otool -L and codesign checks, `size-report` wrote the table (AfterGlow.app 26,236,555 bytes; executables sum 12,484,544). Full run 39007643232 on 0e3c08ea (main) is the first with #1932's fix that runs the journeys after a red scripts/ci.
- The round-1 panel reads code, as suite-contracts' did: this feature has no screens. Lenses: clarity, oracle, quality, packet conformance, robustness. Findings in `scripts/`, `project.yml` or `.github/` go to the supervisor (protected paths); fixers take only Model, plist, icon and test files.
- PRs target dev, not main: CLAUDE.md never targets main and the lane retargets main PRs to dev. Brief's main HEAD 9e3c5f8 verified; it is an ancestor of dev b102413.
- Builder branches are lead/bundle-<id> (a lead/bundle/<id> ref can't coexist with lead/bundle).
- BU-3 (project.yml) and BU-4 (scripts/) open without the fast-lane label: the packet says the supervisor merges them.
- No mutation plans (contract rule 14 is v3 only).
- BU-4 built while BU-3 #1358 waits on the supervisor: its files (scripts/) are disjoint from BU-3's and the supervisor merges both, BU-3 first; the builder reads BU-3's project.yml from its branch for names.
- Supervisor note 2026-10-16T18:13Z (UI and logic in parallel, re-sliced wave data) read: bundle has no UI slice and dev's bundle.wave.json is not re-sliced yet, so the v2 plan stands.
- BU-5c opens without feature-done: BU-4 (supervisor) can't merge before it. The last lane PR, after BU-4 merges, sets bundle.wave.json status built and carries feature-done.
- Wave 2's first launch was given a PR head as base (squash merges make that SHA absent from dev); stopped and relaunched on dev e464eca.

## Open
- #2099 (supervisor): scripts/bundle-apps leaves SuiteKernel.framework out of AfterGlow.app, so bundled helper apps die at launch. scripts/ is protected; the lead can't fix it.
- #2053, #2054: in protected scripts/size-report and scripts/bundle-apps; owner supervisor; relabelled gap after round 2 (15:40Z).
- none blocking; #819 BU-6 waits for ten green dev runs (outside the done check).
- PR bodies carry a server-appended "Generated by Claude Code" footer after the Head: line; a PATCH re-adds it. Supervisor: the lane strips it from the squash commit.
