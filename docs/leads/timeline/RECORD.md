# timeline lead record

Issue: #1480 · Packet: docs/blueprints/suiteui/features/timeline.md
Run: act-1a145e74c2e-oyc0 · Session: cloud lead session · Started: 2026-10-16T18:10Z
Stage: 4 finish
Base: 3b59dc53113bf56a34f420b85331aba6958ad931
Next: read scoped suiteui run 38991868071 (6c4ad16, contains fc31b4f and every timeline PR; past build and tests, in ui-test): judge every slice, review TL-c/TL-d/TL-e screens

## Slices
| slice | behavior | tasks | journeys | waits on | rounds | state | run |
|---|---|---|---|---|---|---|---|
| TL-a | API, contracts and the gallery pages, drawn as today | TL-1, TL-2, TL-3, TL-4 | SJ0 | suite-harness (closed) | 0 | merged | scoped 38967063787 red before journeys ran (#1659); SuiteUI.TimelineTrack mutations pending on the Mac |
| TL-b | Lane beds, clips, key states, playhead pill, pinned ruler, hover, 16 pt hits | TL-4b, TL-5, TL-6, TL-7, TL-8, TL-9 | SJ19a, SP3 | TL-a (TL-5, TL-7) | 2+1 | building | 38977886661 red (#1728); goldens uploaded |
| TL-c | Pick by click/Shift/⌘/right-click, bed clears, ← →, VoiceOver | TL-10, TL-11, TL-12 | SJ19b | TL-a (TL-10); TL-b (TL-11) | 1 | merged | wait scoped run containing 96bd5d9 |
| TL-d | Group key drag with snapping, clip trim, one step per drag | TL-13, TL-14, TL-15 | SJ19c, SP8 | TL-a (TL-13); TL-c (TL-13, TL-14) | 0 | merged | wait scoped run containing 96bd5d9 |
| TL-e | Zoom, sideways scroll, frames/timecode, work area | TL-16, TL-17, TL-18, TL-19 | SJ19d | TL-a (TL-16); TL-b (TL-17..19); TL-c, TL-d (TL-19) | 0 | building | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TL-1 | TL-a | 1 | Three timeline contracts and their Fakes | Contracts/TimelineMapping.swift, Contracts/KeyEditing.swift, Contracts/TimelineEditing.swift, Tests/SuiteUITests/TimelineFakeTests.swift | TimelineFakeTests | #1531 | merged 5ecd0ad |
| TL-2 | TL-a | 1 | Cut TimelineStrip.swift into seam files, bodyRuns counters, safe-area guard over Timeline*.swift | TimelineStrip.swift, TimelineLane.swift, TimelineLaneInput.swift, TimelineLaneAccess.swift, TimelineRuler.swift, TimelinePlayhead.swift, TimelineStrip+Keys.swift, Tests/SuiteUITests/TimelineStripSafeAreaTests.swift | existing tests + TimelineStripSafeAreaTests | #1532 | merged 13cb9be |
| TL-3 | TL-a | 2 | Additive API: TimelineKey, shapes, pickedFrames, new inputs and closures | TimelineTrack.swift, TimelineStrip.swift, Tests/SuiteUITests/TimelineTrackTests.swift, Tests/mutations/SuiteUI.TimelineTrack.json | TimelineTrackTests | #1569 | merged 98414eb |
| TL-4 | TL-a | 3 | Gallery timeline pages over the new API | Gallery/GalleryTimeline.swift | SJ0 | #1602 | merged fce7e9a |
| TL-4b | TL-b | 4 | Drop timeline-long's outer ScrollView now that TL-7 pins the ruler; ruler identifier | Gallery/GalleryTimeline.swift | SJ0, SJ19a scroll step | #1619 | merged 0529325 |
| TL-5 | TL-b | 3 | TimelineLook rules; SJ19a, SP3, scrub budget skipped | TimelineLook.swift, TimelineLookTests, mutations TimelineLook, UITests +Timeline, SuiteTimelineScrubWindowTests | TimelineLookTests | #1605 | merged |
| TL-6 | TL-b | 4 | Lanes: bed, clips, key states/shapes, tween, hover, 16 pt hit | TimelineLane.swift, TimelineLaneInput.swift, TimelineLaneTests, SuiteTimelineSnapshots, mutations Lane, LaneInput | TimelineLaneTests | #1623 | merged 3b59dc5 |
| TL-7 | TL-b | 3 | Pinned ruler over lazy lanes, ideal height, #219 width, QB-S11 | TimelineStrip.swift, TimelineStripLayoutTests, TimelineBudgetTests, mutations TimelineStrip | TimelineStripLayoutTests | #1606 | merged ebe0744 |
| TL-8 | TL-b | 5 | Playhead line, pill, grab band, changed-frame scrub; enables SJ19a, SP3 | TimelinePlayhead.swift, TimelineRuler.swift, TimelinePlayheadTests, mutations Playhead, UITests +Timeline, ScrubWindowTests, +Budgets | TimelinePlayheadTests | #1657 | merged 4347bc7 |
| TL-9 | TL-b | 6 | Golden baselines timeline, -clips, -hover (12 PNGs from run 38977886661; -long isn't asserted yet) | Tests/AppSnapshotTests/Golden/timeline/ | golden checks | #1756 | merged 3799455 |
| TL-10 | TL-c | 2 | SuiteKeyEditing and pick rule; SJ19b skipped | TimelineKeys.swift, TimelineKeysTests, mutations TimelineKeys, UITests +TimelineKeys | TimelineKeysTests | #1571 | merged 5be83d3 |
| TL-11 | TL-c | 5 | Pointer picking on lanes | TimelineLaneInput.swift, TimelineLanePickTests, mutations LaneInput | TimelineLanePickTests | #1647 | merged 1a2f0ef |
| TL-12 | TL-c | 6 | Focus ring, ← →, key a11y children, lane value; enables SJ19b | TimelineLaneAccess.swift, TimelineStrip+Keys.swift, TimelineAccessTests, mutations LaneAccess, Strip+Keys, UITests +TimelineKeys | TimelineAccessTests | #1680 | merged e8a1545 |
| TL-13 | TL-d | 3 | SuiteTimelineEditing snap/trim, drag step rule; SJ19c, SP8, key-drag budget skipped | TimelineEdits.swift, TimelineEditsTests, mutations TimelineEdits, UITests +TimelineDrag, KeyDragWindowTests | TimelineEditsTests | #1607 | merged ecd7137 |
| TL-14 | TL-d | 6 | Key drag on lanes; enables key-drag budget | TimelineLaneInput.swift, TimelineKeyDragTests, mutations LaneInput, KeyDragWindowTests | TimelineKeyDragTests | #1681 | merged 7ea9c39 (key-drag window activation fix follows in its own PR) |
| TL-15 | TL-d | 7 | Trim clip ends; enables SJ19c, SP8 | TimelineLaneInput.swift, TimelineTrimTests, mutations LaneInput, UITests +TimelineDrag | TimelineTrimTests | #1770 | merged 96bd5d9 |
| TL-16 | TL-e | 2 | TimelineZoom and TimelineTime rules; SJ19d skipped | TimelineZoom.swift, TimelineTime.swift, TimelineNavTests, mutations Zoom, Time, UITests +TimelineNav | TimelineNavTests | #1575 | merged 287443c |
| TL-17 | TL-e | 4 | Zoom keys, pinch, toolbar row, sideways scroll | TimelineStrip.swift, TimelineToolbar.swift, TimelineToolbarTests, mutations Strip, Toolbar | TimelineToolbarTests | #1620 | merged 5c1742f |
| TL-18 | TL-e | 6 | Units chips, ruler/pill unit text, work area | TimelineToolbar.swift, TimelineRuler.swift, TimelineRulerUnitTests, mutations Toolbar, Ruler | TimelineRulerUnitTests | #1686 | merged 4eff5af |
| TL-8b | TL-e | 7 | Lanes outside the work area dim to 60% in the playhead layer (packet pseudocode; TL-8 left it out, #1686 notes) | TimelinePlayhead.swift, TimelinePlayheadTests, mutations Playhead | TimelinePlayheadTests | #1707 | merged caa3c66 |
| TL-19a | TL-e | 8 | Toolbar snapshot assertion + enable SJ19d | SuiteTimelineSnapshots, UITests +TimelineNav | SJ19d | #1775 | merged 8fdf407 |
| TL-19b | TL-e | 9 | Toolbar goldens from the next run, wave.json built; feature-done | Golden/timeline (4 PNGs), timeline.wave.json | golden checks | #1817 | merged db0495c |

Waves (from the packet, checked against dev 132d910): 1 TL-1, TL-2 · 2 TL-3, TL-10, TL-16 · 3 TL-4, TL-5, TL-7, TL-13 · 4 TL-6, TL-17 · 5 TL-8, TL-11 · 6 TL-9, TL-12, TL-14, TL-18 · 7 TL-15 · 8 TL-19. Every task in a wave is independent of the others in it; each wait is on merged code named in the Tasks table (shared file chains: TimelineStrip TL-2→3→7→17, TimelineLaneInput TL-2→6→11→14→15, TimelineRuler TL-2→8→18, TimelineToolbar TL-17→18).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| TL-a..TL-d | 38983393903 (journeys ran) | 2be6a10 | CI: SJ0 11 timeline identifier violations; SJ19a/b/c 'no lane for Ball'; SP3/SP8 time out on timeline-long (a11y tree); window budgets and goldens pass | #1800 (TL-c: lane ids, key ids, visible-only key children; TL-b/TL-d journey lookups; SP8 lane name) | – |
| TL-b | 38967063787 (CI log, no screens) | 5c1742f | CI | #1659 | – |
| TL-b | 38971697983 (CI log, no screens) | 4347bc7 | CI | #1693 | 1 |
| TL-b | 38977886661 (CI log + snapshots) | a7c34b4 | CI; panel clarity, design, layout, taste, oracle on snapshots | #1728; panel: #1735-#1745 (14 confirmed, 2 refuted) | 2 |

## Decisions
- Base is `dev`, not `main`: the brief names main, but CLAUDE.md forbids branching from or targeting main, and the packet exists only on dev (main is 74 commits behind). PRs target dev.
- Builder branches are `lead/timeline-<task>` (a `lead/timeline/<task>` ref can't coexist with the `lead/timeline` branch).
- The cloud container had no Swift; the lead ran `scripts/cloud-setup.sh` (pinned 6.3.3) so builders can run `scripts/ci --changed`.
- `gh` has no valid token here; builders open PRs with the GitHub MCP tools.
- SuiteUI mutation plans can't run on Linux (packet Q10): PR bodies end `Mutate: macOS pending SuiteUI.<File>`; the supervisor runs them on the Mac before each Belt-Slice-Done.

- #1517 (halo perf) changed TimelineStrip/TimelineLane after TL-2 merged (Equatable lane, strip owns the tap); later tasks build on that. #1567: counter-reading suites nest under BodyCountSuites, told to TL-5/TL-13 builders.
- The GitHub MCP appends a Claude Code footer to PR bodies; builders now strip it after creating the PR (#1531, #1532 carried it; the lane strips it from the squash).

- The build-wave checker wants Head: last, but the packet (Mutations on macOS) and rule 14 put the Mutate: line after it; wave 2's trailing Mutate: lines stay.

- TL-4 (#1602) adds no test file: the packet names the existing SJ0 as its check (gallery fixture, no mutations); accepted.

- Added TL-4b (slice TL-b): #1602's body says timeline-long's outer vertical ScrollView must come out once TL-7 lands, or SJ19a's pinned-ruler step fails; TL-7 doesn't own the gallery file. Runs in wave 4 beside TL-17 (disjoint files).
- Wave 4 starts TL-17 and TL-4b without waiting on TL-5 (#1605, macOS build queued); TL-6 joins when it merges.

- No file sets the `suite.gallery.timeline.ruler` identifier the journeys read (#1619's notes). TimelineRuler.swift is TL-8's next, and TL-8 enables SJ19a, so TL-8 gives the ruler its identifier and keeps the journey in step.
- TL-17 (#1620) lists no PNGs: the packet records `suiteui-timeline-toolbar` in TL-19. TL-4b (#1619) adds no test: SJ0 and SJ19a are its checks (gallery fixture).

- TL-8 and TL-11 may each touch one line of TimelineStrip.swift (mounting the layer, passing onPickKeyframe); told to keep it minimal so the lane's rebase is trivial. TL-8 also moves the ruler id to `suite.timeline.ruler` in every timeline journey.

- #1659 is fixed out of wave order (round 1 of TL-b): it makes every scoped suiteui run red before journeys run, so no slice can be judged until it merges.

- #63 closes when TL-12 (#1680) and TL-14 (#1681) have both merged; each PR says Refs, so the lead closes #63 by hand (or via TL-15's body) once both are in.

- Added TL-8b (slice TL-e): the work-area dimming the packet puts in the playhead layer is missing (#1686 builder notes); it needs TL-18's workArea plumbing, so wave 7 beside TL-15.

- TL-b has now used its 2 fix rounds (#1659, #1693), both CI blockers no Linux gate could see. Findings on TL-b after the next review become gaps (rule 11). Builders now get the safe-area guard and CGFloat-literal lessons in their brief.

- #1728 is fixed past TL-b's round cap: it is a red test our PRs put on dev that stops every scoped suiteui run before the journeys, so a gap would leave dev red for every line. Critic findings on TL-b from here on become gap issues (rule 11).

- Lead edits RECORD.md in its own worktree (scratchpad/lead-rec): agents may move the main checkout.

- #1728's cause: synthetic clicks in a background test window are activation clicks SwiftUI gestures ignore; #1746 adds .allowsWindowActivationEvents() to the scrub window test, and the same fix goes onto #1681's key-drag window test before it lands.

- #1770 (TL-15) closes #63: its keyboard/VoiceOver half (#1680) and key-drag half (#1681) are merged and the packet puts #63 in this feature (Q5); the checker's objection is overruled.

- TL-19 split: nothing asserted suiteui-timeline-toolbar, so no run could record its goldens. TL-19a adds the assertion and enables SJ19d; TL-19b commits the goldens and carries feature-done.

- #1800 inner identifiers are opt-in via an environment prefix (default none) so Halo's and Flare's strip-level ids and journeys don't change; only the gallery sets `suite.timeline`.
- Packet note for the final task: SJ19b's Badge value is read from a hidden readout (`suite.gallery.timeline.value.badge`) because XCUITest reads SwiftUI values as empty (#262); the lane's spoken key list is capped at 10.

## Open
- Blocked (not ours): #1832, AppSwitcherTests.theRoomModelMatchesTheMeasuredToolbars red on macOS since #1802 (editor-in-window); full CI 38988895145 and scoped suiteui 38988169067 stop before the journeys. Status comment on #1480.
- Mac mutation scores for the 14 SuiteUI timeline plans requested on #1480 (packet Q10).
- Gaps from TL-b's review past its round cap (rule 11): #1735 (major: lane content spills past the bed's rounded end), #1736, #1737, #1739, #1740, #1741, #1742, #1743, #1744.
- #1745 (oracle: a rounding mutation in TimelinePlayhead.rows escapes) stays a finding and is fixed now: rule 6 says no slice is done while a mutation escapes.
- Q10 (mutations on macOS): waiting on the supervisor's Mac runs before any slice is declared done.
