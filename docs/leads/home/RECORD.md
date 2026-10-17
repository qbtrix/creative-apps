# home lead record

Issue: #1503 · Packet: docs/blueprints/suite/features/home.md
Run: act-1a149c6a2a3-yna2 (line lead for suite-contracts, bundle, home; was act-1a14881ad5e-axoa, act-1a145e74c4e-1rah) · Session: session_01WeQwKxFmpontDYTdMSub85 (claude/suite-feature-lead-run-iqt0yq) · Started: 2026-10-16T18:11Z · Resumed: 2026-10-17T06:17Z, 2026-10-17T12:13Z
Stage: 4 feature-done (HM-3z)
Base: 042423165693f2f1d65d2ece90eb0d5bcb910554
Next: full CI 39040191625 on 8c05d002 (contains 8e868417; 39038160863 was cancelled, superseded) must be green; then Belt-Contact-Sheet on #1503 and a gap issue for the #836-skipped assertions

Loop: v2 (the packet has no Slices table), with the findings queue and the 2-round cap (started after #1302 merged).
Depends on: none (issue line). Packet waits: suite-contracts (all tasks merged), bundle BU-3 #814 and BU-4 #818 (open, supervisor merges; HM-0 waits), #778/#775 (`.suiteControl`, `.suiteProbes` on dev), A-DE-0 #836 (open, Design line; HM-3a waits).

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| HM-1a | 1 | `HomeBuilder` (locale ages) and the live home slot; QB-SM2 (#842) | Sources/SuiteModel/Home/HomeBuilder.swift, Sources/SuiteShell/Live/HomeSlot.swift, Tests/SuiteModelTests/HomeBuilderTests.swift, Tests/SuiteModelTests/Budget+Home.swift | HomeBuilderTests, Budget+Home | #1534 | merged |
| HM-1b | 1 | `HomeModel`, `SuiteCreating`, live creating slot (#843) | Sources/SuiteModel/Home/{HomeModel,SuiteCreating}.swift, Sources/SuiteShell/Live/CreatingSlot.swift, Tests/SuiteModelTests/HomeModelTests.swift | HomeModelTests | #1542 | merged |
| HM-0 | 4 | AfterGlow journey harness, smoke test, `afterglow` audit key (#841) | UITests/AfterGlowJourneyTests+{Harness,Smoke}.swift, UITests/audit-baseline.json | AfterGlowSmokeJourneys | #1967 | merged 04:03Z (bd11faf7) |
| HM-2a | 2 | Home window, services wiring, updater stub, snapshots (#844) | Sources/AfterGlowApp/{HomeWindow,HomeSidebar,HomeGrid,HomeRunningStrip,LauncherRouter+Services,UpdateService}.swift, Tests/AppSnapshotTests/AfterGlowHomeSnapshots.swift, Sources/SuiteShell/Live/{HomeSlot,CreatingSlot}.swift, Tests/AppSnapshotTests/SuiteLiveServicesTests.swift | AfterGlowHomeSnapshots, SuiteLiveServicesTests | #1584 | merged |
| HM-2b | 3 | New row, inspector, drop target, layout test (#845) | Sources/AfterGlowApp/{HomeNewRow,HomeInspector,HomeDropTarget}.swift, Tests/AppSnapshotTests/AfterGlowHomeLayoutTests.swift | AfterGlowHomeLayoutTests | #1613 | merged |
| HM-2c | 3 | Launcher File, Edit, View menus over `HomeMenu` (#846) | Sources/AfterGlowApp/LauncherCommands+Home.swift, Sources/SuiteModel/Home/HomeMenu.swift, Tests/SuiteModelTests/{HomeMenuTests,LauncherMenuStubTests}.swift | HomeMenuTests | #1616 | merged |
| HM-4 | 4 | Home golden baselines (#870) | Tests/AppSnapshotTests/Golden/afterglow/ | dev run compare | #1953 #1954 #1956 #1959 #1960 | merged |
| HM-3a | 5 | Journeys SJ0, SJ1 steps 1, 2, 5, 6 (#847); the assertions that need the Design fixture files skip with `XCTSkip("waits on #836")` until `UITests/Fixtures/suite/Cards.design` exists | UITests/AfterGlowJourneyTests.swift, UITests/AfterGlowJourneyTests+Home.swift | SJ0, SJ1 | #2056 | merged 13:29Z |
| HM-3b | 5 | testHomeAtEveryWidth, SJ19 (#848) | UITests/AfterGlowJourneyTests+{Layout,EveryControl}.swift | those journeys | #2007 | merged 07:15Z (3a9a784) |
| HM-3z | 6 | home.wave.json status built + feature issue; `feature-done` | docs/blueprints/suite/features/home.wave.json | scripts/ci | #2082 | merged 13:48Z (8e868417) |
| HM-3c | – | Perf journeys SP3, SP4 (#849; follow-up, outside done check) | UITests/AfterGlowJourneyTests+{PerfHome,BudgetsHome}.swift, HomeGrid.swift | SP3, SP4 | | waits #782 |

Waves (packet's Build waves, checked against dev at 132d910):
- Wave 1: HM-1a, HM-1b, independent (HM-1b's tests use `.fake`'s FakeHome). HM-0 moves out: it needs BU-3's AfterGlowJourneyTests bundle and BU-4's AfterGlow.app.
- Wave 2: HM-2a (waits HM-1b: HomeWindow holds a HomeModel). HM-0 joins whichever wave is next once BU-3 and BU-4 merge.
- Wave 3: HM-2b (waits HM-2a: sits in HomeWindow), HM-2c (waits HM-1b and HM-2a: the `\.homeModel` key), independent of each other.
- Wave 4: HM-4 (the dev run holding HM-2a and HM-2b), HM-3a (HM-0, HM-2b, HM-2c, #836).
- Wave 5: HM-3b, feature-done.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| – | 38965923292 (1910bff6) | macOS red, not ours: SuiteUI TimelineStripLayoutTests.idealHeightIsRulerPlusLanesWithTheToolbarOff (#1606 area); every home suite green; AppSnapshotTests never ran, so no home screens | – | – | – | – | no review |
| 1 | 38978368822 (63a61b00) | macOS red (perf/other lines), AppSnapshotTests ran: 36 afterglow-home-* PNGs | no afterglow key yet | clarity, journey, design, layout, controls | 24 confirmed, 1 refuted; filed #1752 #1753 #1754 #1755 #1757 #1758 #1759 #1761 #1762 #1763 #1764 #1765 #1766 #1767 #1768 #1769 (1 blocker, 9 major, 6 minor) | fix round 1: #1773, #1794, #1797 | no |
| 2 | 38985993416 (7a090878) | 56 afterglow-home-* PNGs (14 states) | no afterglow key yet | clarity, journey, design, layout, controls | 9 confirmed, 5 refuted; filed #1865 #1866 #1868 #1869 #1870 #1871 #1872 #1873 #1874 (1 major, 8 minor) | fix round 2: #1879 #1880 #1881 #1882 #1884 | no |
| 3 (closing) | 38994576664 (37d99630) | 56 afterglow-home-* PNGs | no afterglow key yet | clarity, journey, design, layout, controls | 8 confirmed, 4 refuted; filed #1945-#1950 (2 major, 4 minor) | – (cap reached): all open home findings relabelled gap | no; closed under the round cap |
| – | 38975145931 (bfb8ce4f) | macOS red on SuiteUI TimelineStripSafeAreaTests (#1693, closed); no home snapshots | – | – | – | – | no review |
| – | 38967787160 (8e0a5261) | macOS red again on #1659 (SuiteUI); scoped suite run 38968259383 green but uploads no snapshots | – | – | – | – | no review |

## Decisions
- Wave 5 (line lead, 2026-10-17): HM-3a and HM-3b run together; their files are disjoint and neither needs the other's code. HM-3b's `feature-done` is unchained into HM-3z (a docs-only PR after both merge), since HM-3b's own journeys need only the harness, the views and the goldens, all merged.
- #836 (A-DE-0, Design line) is still open with no PR, so `UITests/Fixtures/suite/` doesn't exist and FixtureSeeder marks every weekOfWork card Missing. HM-3a ships now: SJ0 and SJ1 run every step and shoot every screen, and the assertions that need `Logo.design`/`Cards.design` on disk (SJ0 "not Missing", SJ1 step 5's present-vs-missing) throw `XCTSkip("waits on #836 (A-DE-0)")` while `UITests/Fixtures/suite/Cards.design` is absent, so the journey turns green by itself when Design exports the fixtures. Commented on #836.
- HM-0 harness API for HM-3a: SuiteHarness(self).launch(fixture:arguments:) -> Journey under `afterglow`; suite.attach(.app); controls need -SuitePerfProbe YES; menus via openEachMenu. Teardown fails if any suite process outlives 10 s.
- Round 1's batcher made one batch (#1773) and deferred #1753 #1754 #1761 #1762 #1763 #1767 because their files overlap it; they run as batch r-b2 once #1773 merges and count as part of fix round 1, not a second round.
- #1764 and #1766 need SuiteUI: needs-ui #1771 (ThumbnailItem placeholder symbol) and #1772 (per-chip help); left open.
- Fix round 1 of 2 (contract rule 11): every open finding goes in; 16 open findings > 5, so no new feature task starts until it drops (none could start anyway: HM-0, HM-3a blocked).
- HM-4 (goldens) waits for round 1's fixes: the first shots show an empty sidebar, cards off the tiles' edge and large fake-thumbnail cells, so committing them as baselines would freeze known defects.
- PRs target dev, not main: CLAUDE.md never targets main and the lane retargets main PRs to dev. Brief's main HEAD 2e0f7df verified; it is an ancestor of dev 132d910.
- Builder branches are lead/home-<id> (a lead/home/<id> ref can't coexist with lead/home).
- Not-connected sentences come from `SuiteIdentity.notConnected` (#1473), not the packet's "Not connected yet (switching)." (gap #1491).
- `SuiteServices.live` on dev is `live(support:app:arguments:)`; HM-2a builds on that, not the packet's `live(support:)`.
- HM-2a also flips the home and creating slots live and updates SuiteLiveServicesTests: HM-1a/HM-1b left both flags false because that macOS test expects them pending until the window ships.
- HM-1a's QB-SM2 budget suite (SuiteModelTests.HomeBudgetTests) is not in Tests/perf-suites.txt; the supervisor owns that list.
- The MCP PR tool appends a "Generated by" footer; builders must strip it after opening (removed from #1584). #1534 and #1542 merged with it; the lane strips it from squash commits.
- No mutation plans (contract rule 14 is v3 only).

## Open
- HM-3a's SJ0/SJ1 fixture assertions skip until #836 (Design line) merges; nudged on #836 2026-10-17. If it is still open when HM-3z is ready, the contact sheet names the skipped assertions and a `gap` issue tracks lifting them.
- Gaps after the 2-round cap (rule 11): #1763 #1764 #1766 #1945 #1946 #1947 #1948 #1949 #1950, plus #1609.
- #1871 fixed only as a stopgap (no tint); the shared InlineNotice waits on SuiteUI #780.
- #1763 (Open… and Open In never enable) needs recents-open-in's routing slot; left open with a comment. The reason now comes from HomeMenu.openReason(pending:).
- #1790 needs-ui: SuiteUI StatusPill for the Preview data pill (#1762 placeholder).
- #1761 partly: the toolbar search field is window chrome the snapshot window doesn't draw; HM-3a's journey must show it.
- Round 1 and HM-4 wait on #1659 (SuiteUI TimelineStripLayoutTests stops the macOS gate before AppSnapshotTests). Status comment posted on #1503.
- HM-2c limits for the review round: Show Sidebar/Show Inspector disabled with the home's not-connected reason (reads wrong while the window is open); Clear Menu disabled (no clear API); Open Recent follows the grid's search/filter (HomeModel.recents not public); Delete page routing built in HomeMenu but HomeWindow doesn't publish the page; Undo Remove is its own item, no ⌘Z.
- #1609 (gap from HM-2b): recents cards off the 7.3 column math; needs SuiteUI #1615 (needs-ui, ThumbnailGrid fixed columns). Fix task HM-2d (HomeGrid passes HomeLayout columns, drop withKnownIssue) once #1615 merges.
- HM-2b left out HomeDropTarget: HomeModel can't open a dropped file (no dead controls).
- HM-2a left for HM-2b: Locate… on a missing file, sidebar double-click to switch, app-symbol loading card (#804), Open… stays disabled (HomeModel has no open-picked-file path). New-row slot is HomeContent.newRow; inspector placeholder in HomeWindow; focused key \.homeModel.
- HM-3a waits on A-DE-0 #836 (Design line, open).
