# photo-journey-kit lead record

Issue: #1073 · Packet: docs/blueprints/photo/features/photo-journey-kit.md
Run: act-1a1406baff9-fu36 · Session: cloud lead session · Started: 2026-10-15T16:36Z
Stage: 4 round 1
Base: 9f28a9f7dcb6e9d584a7c80847e8ef0108fa5e17
Next: round 2 on the first dev CI run containing b555f56 (#1238-#1242, recovery-folder isolation); 38799320916 on 3dc283e predates them. Read smoke + V1-V12 + Photo audit, ui-screens, critic panel

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| KT-1 | 1 | move writeTestPhoto to +Fixtures, add photoArguments, smoke journey; PhotoJourneyTests calls them | UITests/PhotoJourneyTests.swift, UITests/PhotoJourneyTests+Fixtures.swift | PhotoJourneyKitTests.testWrittenPhotoOpens; V1-V12 unchanged | #1199 | merged 16:50Z |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38792928305 (c93a7f8; earlier 763-767 never reached ui-test) | red, cancelled mid ui-test: 11/21 Photo journeys fail on app UI (Layers tab, sheets, fields) from photo window changes, not #1199's files | Photo contrast 1 vs 0 on photo-launch (_NS:58, not this feature) | none run: no ui-screens uploaded | PhotoJourneyKitTests.testWrittenPhotoOpens PASSED; photoArguments open/saveTo/fixture journeys pass | reported on #763 (6201226875) | no |

## Decisions
- #1241 (photo-documents) changed photoArguments to always pass a fresh -PhotoRecoveryDir and updated the smoke test's asserts: it isolates the autosave restore offer that broke round 1's journeys. Accepted as is; no KT follow-up needed.
- Round 1 V1-V12 failures are not this feature's: #1199 changed no step or assertion, the argument arrays are identical, and journeys using the same helpers pass; the failing ones need Photo window UI changed by #1223/#1228/#1230. Reported on dev-red, no fix batch here.
- Round 1 waits for a run that reaches ui-test: the feature is UITests only, so a run that stops in swift test can't judge it. Code-level read of #1199 found no issue.
- Depends on #333: closed (PR #877), so the feature proceeds.
- One task, one wave: KT-1 is both build and final task (feature-done), per the packet; run as one worktree subagent, not build-wave.js (fewer than 3 tasks).
- KT-1 touches only UITests/, which compiles only on macOS: the Linux gate covers lints only; the macOS run on dev the lane dispatches (UITests path + feature-done) is the real check.

## Open
- dev-red #763: macOS jobs die before ui-test (runs 763-767 all stop in scripts/ci), so the smoke journey has not run yet; LiveRecovery fixed by #1226; run 38782884668 (f9846c9) then failed swift test on PhotoCompositeCostTests' 4x timing ratio (photo-edit, already on #763), ui-test skipped
