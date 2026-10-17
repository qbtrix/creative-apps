# suite-contracts lead record

Issue: #1332 · Packet: docs/blueprints/suite/features/suite-contracts.md
Run: act-1a14ad585d6-dlpz (line lead for suite-contracts, bundle, home; was act-1a149c6a2a3-yna2, act-1a14881ad5e-axoa, act-1a1448a5fd9-0he1) · Session: session_01FgHMdTN1ZvtNhGw81uzVWU (claude/feature-lead-suite-contracts-z0ynwa; was session_01WeQwKxFmpontDYTdMSub85) · Started: 2026-10-16T11:49Z · Resumed: 2026-10-17T06:17Z, 2026-10-17T12:13Z, 2026-10-17T17:08Z
Stage: done
Base: 68cabe667bf2de7df53327a947705078d3b08f2b
Next: none. Belt-Contact-Sheet posted on #1332 (full run 38988895145 on 7ac0a317, green; main promoted). Line lead act-1a149c6a2a3-yna2 re-checked on 2026-10-17T12:13Z: no open finding for the feature, nothing left.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| SC-1a | 1 | identity, app, types, document refs (`fileKey`), errors, links; `declaredOnly` (#820) | Sources/SuiteModel/Values/{SuiteIdentity,SuiteApp,SuiteTypes,SuiteDocumentRef,SuiteError,Links}.swift, Tests/SuiteModelTests/ValuesIdentityTests.swift | ValuesIdentityTests | #1340 | merged |
| SC-1b | 2 | recents values, `RecentsList`, presets, switching values, `HandOff` (`newID`), `HandOffCodec` (id check) (#821) | Values/{Recents,NewDocumentPreset,Switching,HandOff}.swift, Recents/RecentsList.swift, HandOff/HandOffCodec.swift, ValuesRecentsTests, ValuesHandOffTests | ValuesRecentsTests, ValuesHandOffTests | #1350 | merged |
| SC-1c | 2 | round-trip, colour, asset, clipboard values (#822) | Values/{RoundTrip,SuiteColor,Assets,Clip}.swift, ValuesExchangeTests | ValuesExchangeTests | #1349 | merged |
| SC-4a | 2 | `SuiteLocations`, `FileStore` (#829) | Store/{SuiteLocations,FileStore}.swift, StoreTests | StoreTests | #1353 | merged |
| SC-1d | 3 | preferences, onboarding, update values, `UpdateFeed`, `AnimationSummary`, home values, `HomeLayout` (#823) | Values/{Preferences,Onboarding,Update,AnimationSummary,HomeValues}.swift, Update/UpdateFeed.swift, Home/HomeLayout.swift, ValuesSettingsTests, ValuesHomeLayoutTests | ValuesSettingsTests, ValuesHomeLayoutTests | #1359 | merged |
| SC-2a | 4 | nine tier-1 contracts (#824) | Contracts/{AppSwitching,RecentWork,DocumentCreating,DocumentRouting,HandOffSending,HandOffReceiving,ThumbnailPublishing,HomeBuilding,SuiteDocumentHost}.swift, ContractShapeTests | ContractShapeTests | #1371 | merged |
| SC-2b | 4 | other nine contracts (#825) | Contracts/{RoundTripEditing,PasteboardCoding,AssetLibrary,AssetLinking,AnimationSourceReading,PreferencesStoring,SettingsRouting,OnboardingFlowing,UpdateChecking}.swift, ContractShapeMoreTests | ContractShapeMoreTests | #1370 | merged |
| SC-3a | 5 | `ChangeFeed` and tier-1 fakes (#826) | Fakes/{ChangeFeed,FakeSwitching,FakeRecents,FakeCreating,FakeRouting,FakeHandOffs,FakeThumbnails,FakeHome,FakeDocumentHost}.swift, FakesTier1Tests | FakesTier1Tests | #1390 | merged |
| SC-3b | 6 | round-trip, pasteboard, asset, link fakes (#827) | Fakes/{FakeRoundTrips,FakePasteboard,FakeAssets,FakeLinking}.swift, FakesExchangeTests | FakesExchangeTests | #1396 | merged |
| SC-3c | 6 | animation, prefs, settings, onboarding, update fakes; `SuiteFixtures` (#828) | Fakes/{FakeAnimationSource,FakePreferences,FakeSettingsRoute,FakeOnboarding,FakeUpdates,SuiteFixtures}.swift, FakesSettingsTests, SuiteFixturesTests | FakesSettingsTests, SuiteFixturesTests | #1397 | merged |
| SC-5a | 6 | `StoreRecents` (#832) | Recents/StoreRecents.swift, StoreRecentsTests | StoreRecentsTests | #1399 | merged |
| SC-4b | 7 | `SuiteServices`, budget helper, QB-SM6, QB-SV8, Model journey (#830) | SuiteServices.swift, SuiteServicesTests, Budget, Budget+Store, StoreRoundTripTests, SuiteContractsJourneyTests | those | #1409 | merged |
| SC-4c | 7 | `FixtureSeeder` (#831) | Store/FixtureSeeder.swift, FixtureSeederTests | FixtureSeederTests | #1407 | merged |
| SC-5b | 8 | `SlotContext`, `SuiteServices.live`, first seven slots (#833) | Sources/SuiteShell/SuiteServices+Live.swift, Live/{Switching,Recents,Creating,Routing,HandOff,Thumbnails,Home}Slot.swift, Tests/AppSnapshotTests/SuiteLiveServicesTests.swift | SuiteLiveServicesTests (macOS) | #1428 | merged |
| SC-5c | 9 | other seven slots; `feature-done` (#834) | SuiteServices+Live.swift, Live/{RoundTrip,Pasteboard,Assets,Linking,Preferences,Settings,Onboarding}Slot.swift, SuiteLiveServicesTests | SuiteLiveServicesTests (macOS) | #1448 | merged |

Waves (packet's Build waves, checked against dev at ebc68bf):
- Wave 1: SC-1a alone.
- Wave 2: SC-1b, SC-1c, SC-4a, all independent (each needs only SC-1a's merged values).
- Wave 3: SC-1d (waits on SC-1b: `HomeValues` holds `RecentItem`, `NewDocumentPreset`).
- Wave 4: SC-2a, SC-2b, independent (need SC-1b/c/d values).
- Wave 5: SC-3a (waits on SC-2a: fakes conform to its contracts).
- Wave 6: SC-3b, SC-3c, SC-5a, independent (each needs SC-3a's `ChangeFeed`; SC-5a also SC-4a).
- Wave 7: SC-4b, SC-4c, independent (SC-4b builds the fakes; SC-4c needs `SuiteFixtures`, `FileStore`).
- Wave 8: SC-5b (reads SC-4b's `slotFeatures`/`pending`, SC-5a's `StoreRecents`).
- Wave 9: SC-5c (same file as SC-5b), `feature-done`.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38933216466 | red, not this feature: Linux green; macOS failed only HaloEasingSnapshots.segmentTitlesFitOneLine (halo, #1450); SuiteLiveServicesTests, all SuiteModelTests (2740 Model tests) and StoreBudgetTests passed; QB-SM6 median 5.5/5.7 ms (debug gate 50); journeys skipped after the test failure, so no audit | no screens touched | clarity, oracle, quality, packet conformance, robustness | 10 (4 major, 6 minor): #1457 #1459 #1460 #1461 #1462 #1463 #1464 #1465 #1466 #1468 | #1472 #1473 #1474 #1476 merged | no |
| 2 | scoped: suite 38940652547 on 3fbd10f (all round-1 fixes) | scoped green; full 38938209193 still queued | no screens touched | same five lenses | 6 minor, 0 blocker/major (panel clean): #1485 #1486 #1487 #1488 #1489 #1490 | #1492 #1504 #1518 #1519 merged | panel clean |
| 3 (final) | full 38938209193 on 7d7256c | red, not this feature: Design shell geometry (testShellDark/Light, shell-parity #1452) and Halo easing/playback journeys + audit (easing); SuiteLiveServicesTests, StoreBudgetTests and SuiteJourneyTests (4/4) passed | no screens touched | same five lenses | 5 (3 major): #1556 #1558 #1560 major, #1557 #1559 minor | none: round cap (rule 11) reached; relabelled gap with #1463 | no |

Runs after round 1: scoped: suite 38938043443 on 91f1ba6 (has SC-5c and #1472) green; full run 38938209193 on 7d7256c pending; scoped: suite 38940652547 on 3fbd10f (all round-1 fixes) in progress.

## Decisions
- No `## Slices` table in the packet: v2 loop. Started after #1302, so the findings queue (rule 10) and the 2-round cap (rule 11) apply; rules 13/14 (v3 only) don't.
- PRs target `dev`, not `main`: CLAUDE.md forbids targeting `main` and the lane retargets fast-lane PRs to `dev`. The brief's main HEAD 9e3c5f8 was verified; dev (ebc68bf) is one commit ahead.
- `targets` dependency met: its `.wave.json` is `built`, and `Sources/SuiteModel/Values/SuiteIdentity.swift`, `SuiteApp.swift` exist on dev.
- Builder branches are `lead/suite-contracts-<id>` (git can't hold `lead/suite-contracts/<id>` beside the lead branch).
- The container had no Swift: installed swift-6.3.3-RELEASE (CI's image version) under /opt/swift, linked into /usr/local/bin; `scripts/ci --changed` passes on dev ebc68bf.
- `gh` has no valid token in this container: builders open PRs and set labels through the GitHub MCP tools.
- Wave 2 runs through a copy of build-wave.js with branch `lead/suite-contracts-<id>` and MCP PR opening (the template uses `gh`).
- The GitHub MCP server appends a Claude Code footer to PR bodies; the lead strips it with update_pull_request (done on #1349, #1350, #1353), and the builder brief now tells builders to.
- SC-4b QB-SM6: two real processes on Linux (test binary relaunched with SUITE_STORE_WRITER); two tasks on macOS. RecentsList caps at 200, so "1,000 items" is checked as store revision == 1,000 plus the list being exactly the 200 newest; with flock disabled it failed at revision 543. Measured median write ~15 ms (debug gate 50 ms). Supervisor may add `suite SuiteModelTests.StoreBudgetTests` to Tests/perf-suites.txt.
- SC-4b slotFeatures: switching/sending/receiving -> switching; recents/routing/thumbnails -> recents-open-in; creating/home -> home; preferences/settings -> settings; pasteboard -> clipboard-drag; roundTrips -> photo-round-trip; assets -> shared-assets; onboarding -> onboarding; linking -> linked-assets.
- Round 1 panel runs on the code without waiting for CI: no screens in this feature, so the critics read code; CI is judged separately when run 38933216466 ends.
- Waves 1 and 3, 5, 8, 9 have one task: one worktree subagent each instead of the build-wave workflow.
- Corrections in the packet are listed 1-6, 8-10, 7 (no correction is missing); builders apply the ones naming their task.

## Open
- Resolved: the #1075 quarantine entry was removed on dev, and full run 38988895145 (7ac0a317) went green. Its macOS job's only failure, SuiteUITests.AppSwitcherTests.theRoomModelMatchesTheMeasuredToolbars from #1802, is outside this feature. Linux run: 2732 tests; SuiteModelTests alone: 207. QB-SM6 median: 4.8 ms on macOS, 7.0 ms on Linux.
- Gaps after the round cap: #1556 #1558 #1560 (p1), #1557 #1559 #1463 (p2), #1491 (p2); needs-ui #1477.
- #1491 (gap, p2): home.md, targets.md, switching.md packets still quote the old "Not connected yet (" sentence.
- #1477 (needs-ui, line:suiteui): AppSwitcher hardcodes the old not-connected sentence that #1473 replaces.
- #1463 (perf-suites.txt) needs the supervisor: protected file; commented on the issue. Becomes a gap after round 2 if still open.
