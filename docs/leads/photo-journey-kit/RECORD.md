# photo-journey-kit lead record

Issue: #1073 · Packet: docs/blueprints/photo/features/photo-journey-kit.md
Run: act-1a1406baff9-fu36 · Session: cloud lead session · Started: 2026-10-15T16:36Z
Stage: 5 finish (stopped after round 4 of 4)
Base: 9f28a9f7dcb6e9d584a7c80847e8ef0108fa5e17
Next: nothing for the lead. A resumed lead only checks whether a dev CI run containing cdcfb62 went green; if so, reply on #1073 with that run link. Otherwise the supervisor decides.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| KT-1 | 1 | move writeTestPhoto to +Fixtures, add photoArguments, smoke journey; PhotoJourneyTests calls them | UITests/PhotoJourneyTests.swift, UITests/PhotoJourneyTests+Fixtures.swift | PhotoJourneyKitTests.testWrittenPhotoOpens; V1-V12 unchanged | #1199 | merged 16:50Z |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38792928305 (c93a7f8; earlier 763-767 never reached ui-test) | red, cancelled mid ui-test: 11/21 Photo journeys fail on app UI (Layers tab, sheets, fields) from photo window changes, not #1199's files | Photo contrast 1 vs 0 on photo-launch (_NS:58, not this feature) | none run: no ui-screens uploaded | PhotoJourneyKitTests.testWrittenPhotoOpens PASSED; photoArguments open/saveTo/fixture journeys pass | reported on #763 (6201226875) | no |
| 2 | 38799320916 (3dc283e, before #1241) | red: 21 Photo journeys fail; shot photo-kit-opened shows a stale 'Restore beach.png' offer over the window (modal true), the cause #1241 fixes | Photo contrast 1 vs 0 (_NS:58, also on photo-launch: not this feature) | first-use clarity, journey correctness (lead's read of photo-kit-opened.png + audit; one screen, so no full panel) | F2-1: testWrittenPhotoOpens passes and shoots 'the v1 open state' with a modal over the window (false green) | #1243 (merged, cdcfb62) | no |
| 3 | 38807718380 (cdcfb62 = #1243, feature-done) | red outside this feature: Photo documents/edit/crop/layer-ops/recovery, Halo and Library journeys; ALL of this feature's journeys pass: PhotoJourneyKitTests.testWrittenPhotoOpens and PhotoJourneyTests V1-V12 (13/13) | photo identifier 22 <= 23; contrast 1 > 0 from photo-documents-1b-save-alert (photo-documents); photo-kit-opened: modal false, contrast 0 | first-use clarity, journey correctness (same lenses as round 2) | none in this feature (shot unobstructed; every label on it is the existing Photo shell) | - | clean for this feature; run red elsewhere |
| 4 | 38808325928 (75492b1, contains #1243) | red outside this feature (9 Photo journeys of other features, 7 Halo, 1 Library); this feature 14/14 pass | photo identifier 22 <= 23; contrast 1 > 0 from photo-documents' save alert; photo-kit-opened modal false, contrast 0 | same as round 3 | none | - | clean for this feature; run red elsewhere |

## Decisions
- Round 3: no finding in this feature's files; the red journeys and the contrast count belong to photo-documents, photo-edit, crop, Halo and Library, which the Dev red job already posted to #763. No new lenses after this round.
- Round 2 panel ran as the lead's own read: the feature adds one screen (photo-kit-opened), so the clarity and correctness lenses fit in one pass; the other failures are outside this feature's files and are already on #763 / fixed by #1238-#1242.
- F2-1's fixer PR also carries feature-done: #1199's triggered CI was red for other features' reasons, so the done check needs a later feature-done merge whose run is green.
- #1241 (photo-documents) changed photoArguments to always pass a fresh -PhotoRecoveryDir and updated the smoke test's asserts: it isolates the autosave restore offer that broke round 1's journeys. Accepted as is; no KT follow-up needed.
- Round 1 V1-V12 failures are not this feature's: #1199 changed no step or assertion, the argument arrays are identical, and journeys using the same helpers pass; the failing ones need Photo window UI changed by #1223/#1228/#1230. Reported on dev-red, no fix batch here.
- Round 1 waits for a run that reaches ui-test: the feature is UITests only, so a run that stops in swift test can't judge it. Code-level read of #1199 found no issue.
- Depends on #333: closed (PR #877), so the feature proceeds.
- One task, one wave: KT-1 is both build and final task (feature-done), per the packet; run as one worktree subagent, not build-wave.js (fewer than 3 tasks).
- KT-1 touches only UITests/, which compiles only on macOS: the Linux gate covers lints only; the macOS run on dev the lane dispatches (UITests path + feature-done) is the real check.

## Open
- Done check open: no green dev CI run yet; #1243 (feature-done) triggered 38807718380, red for other features (#763). Contact sheet posted on #1073 (comment 6203872377) saying so.
- KT-1 follow-up F2-1 shipped as #1243.
- dev-red #763: macOS jobs die before ui-test (runs 763-767 all stop in scripts/ci), so the smoke journey has not run yet; LiveRecovery fixed by #1226; run 38782884668 (f9846c9) then failed swift test on PhotoCompositeCostTests' 4x timing ratio (photo-edit, already on #763), ui-test skipped
