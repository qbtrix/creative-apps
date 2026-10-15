# photo-journey-kit lead record

Issue: #1073 · Packet: docs/blueprints/photo/features/photo-journey-kit.md
Run: act-1a1406baff9-fu36 · Session: cloud lead session · Started: 2026-10-15T16:36Z
Stage: 4 round 1
Base: 9f28a9f7dcb6e9d584a7c80847e8ef0108fa5e17
Next: wait for a dev CI run past PhotoCompositeCostTests (photo-edit timing bound, reported on #763 by others); read its ui-test: PhotoJourneyKitTests.testWrittenPhotoOpens, V1-V12, Photo audit

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| KT-1 | 1 | move writeTestPhoto to +Fixtures, add photoArguments, smoke journey; PhotoJourneyTests calls them | UITests/PhotoJourneyTests.swift, UITests/PhotoJourneyTests+Fixtures.swift | PhotoJourneyKitTests.testWrittenPhotoOpens; V1-V12 unchanged | #1199 | merged 16:50Z |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38772608478, 38773966980, 38774988270 | red, not this feature (macOS scripts/ci: two Photo timing budgets, LiveRecovery.swift compile error from #1210); ui-test skipped | not measured | - | - | - | pending |

## Decisions
- Round 1 waits for a run that reaches ui-test: the feature is UITests only, so a run that stops in swift test can't judge it. Code-level read of #1199 found no issue.
- Depends on #333: closed (PR #877), so the feature proceeds.
- One task, one wave: KT-1 is both build and final task (feature-done), per the packet; run as one worktree subagent, not build-wave.js (fewer than 3 tasks).
- KT-1 touches only UITests/, which compiles only on macOS: the Linux gate covers lints only; the macOS run on dev the lane dispatches (UITests path + feature-done) is the real check.

## Open
- dev-red #763: macOS jobs die before ui-test (runs 763-767 all stop in scripts/ci), so the smoke journey has not run yet; LiveRecovery fixed by #1226; run 38782884668 (f9846c9) then failed swift test on PhotoCompositeCostTests' 4x timing ratio (photo-edit, already on #763), ui-test skipped
