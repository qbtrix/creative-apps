# file-flow lead record

Issue: #3474 · Packet: docs/blueprints/halo/features/file-flow.md
Run: act-1a1783581a6-fo4a · Started: 2026-10-26T12:45Z (resumed after auto-relaunch; earlier runs act-1a175f40239-xop3 and before)
Stage: 3 polling (every task in a PR: HF-3 #4894, HF-4 #4936, HF-z #5092 feature-done; HF-a, HF-u done)
Base: 746be6b1 (origin/dev); main d3323f6a checked
Next: wait for the lane to land #4894 (HF-m), then #4936 retargets to dev and #5092 (HF-z); then a CI run on dev whose Linux job contains each slice's last PR, Belt-Slice-Done HF-m and HF-z, Belt-Contact-Sheet

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HF-a | adapter stubs; scene adopts suiteApp, Open Recent via SuiteFileCommands, file drop | HF-1, HF-2 | - | transform:HT-a, shape-tools:HS-a, placed-images:PH-u | yes | 0 | done #4855 (f2955985) | [40029046141](https://github.com/qbtrix/creative-apps/actions/runs/40029046141) | wanted |
| HF-m | adapter bodies, catalog ids, recents imported once, RJ-H42 | HF-3, HF-4 | - | HF-a; gradient-fill:HG-m, autosave-history:HA-m, transform:HT-m, shape-tools:HS-m, stroke-style:HK-m, placed-images:PH-m | yes | 0 | pr #4894 (HF-3, on dev), #4936 (HF-4) | - | - |
| HF-u | snapshots, render budget, journey skipped | HF-5, HF-6 | - | HF-a | yes | 0 | done #4868 (10642721) | [40116034771](https://github.com/qbtrix/creative-apps/actions/runs/40116034771) | wanted |
| HF-z | journey live; halo.md, built, feature-done | HF-7, HF-8 | HaloFileFlowJourneyTests | HF-m, HF-u; export-pack:HX-z, placed-images:PH-z | yes | 0 | pr #5092 | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HF-1 | HF-a | 1 | adapter stubs | Sources/HaloModel/HaloFileFlow+Kernel.swift, Tests/HaloModelTests/HaloFileFlowTests.swift | compiles; tests disabled | #4855 | merged |
| HF-2 | HF-a | 2 | scene, File menu, drop | Sources/HaloApp/HaloApp.swift, see packet | HaloFileFlowSnapshots.menu | #4855 | merged |
| HF-3 | HF-m | 2 | adapter bodies, ids, RJ-H42 | see packet | HaloFileFlowTests | #4894 | pr |
| HF-4 | HF-m | 2 | window notes opens and saves | Sources/HaloApp/HaloWindow+File.swift, Tests/AppSnapshotTests/HaloFileFlowLiveTests.swift | HaloFileFlowLiveTests | #4936 | pr |
| HF-5 | HF-u | 3 | snapshots, budget | Tests/AppSnapshotTests/HaloFileFlowSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHaloFileDropTests.swift | RenderBudgetHaloFileDropTests | #4868 | pr |
| HF-6 | HF-u | 3 | journey skipped | UITests/HaloJourneyTests+FileFlow.swift | compiles, skipped | #4868 | pr |
| HF-7 | HF-z | 4 | journey live | UITests/HaloJourneyTests+FileFlow.swift | testOpenRecentAndDrop | #5092 | pr |
| HF-8 | HF-z | 5 | halo.md, built, feature-done | docs/blueprints/halo.md, docs/blueprints/halo/features/file-flow.wave.json | waves render --dry-run | #5092 | pr |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-26 Packet-Review 2 (6d5f8b92, #3474 comment 6407188805), rule 24:
  1. Host stays HaloDocumentHost: already so in HF-m's code; packet lines 8 and 54 fixed in HF-z (#5092).
  2. Retire Halo's file.open-recent spec, add the four ids: already done in HF-m (#4894: filter in specs, halo.txt). Packet HF-3 row says so.
  3. PNG off the canvas hands off to Photo: HF-m's tests already expect that; packet fixed. Deleting the unused `imageRefusal` goes to one fix PR after HF-4 lands, because pushing the queued #4894 would drop its prescreen.
  4. Canvas places images through PH-3: packet and journey step 3 fixed. The step asserts only that no window opens; the PNG drop mark claim was dropped. The S20 comments and the mutation label get fixed in the same follow-up fix PR.
  5. .flare hands off to Flare: HF-z had already changed step 4. Rule 20 and accept line now say FH-1.
  6. .suiteEditor, and HF-2 landed: packet fixed.
  7. Dropped .halo opens in this window (host sends .openRecent): taken as written. The journey step 2 now expects the same window count, steps 3 and 4 too. No openWindow task.
  8. HaloRecentFile stays for takeOldRecents: packet line 3 fixed (code already keeps it).
  9. Import in the window via takeOldRecents: HF-4 (#4936) already does it; packet pseudocode and HF-4 row fixed.
  10. HaloFiles' own recent list: no menu reads it after HF-4, but it isn't removed yet. Removal (pending open into file.opening, plus HaloProject, availability and recovery) goes in the same follow-up fix PR after HF-4 lands.
- Record lives on lead/file-flow at docs/leads/file-flow/ from run act-1a1783581a6-fo4a on (before: lead/halo-file-flow, while the suite lead held lead/file-flow).
- HF-a rebuilt on dev rather than on the placed-images stack: SF-a, HT-a and HS-a are on dev, and HF-a needs none of PH-u's code. The old branch (a5ba7569, no PR) was replaced by force-with-lease.
- HF-a carries HF-5's snapshots (halo-open-recent, halo-drop-mark) so the menu and drop are seen in the slice that adds them; HF-u adds the budget test and journey.
- Base dev, not main: CLAUDE.md, the fast lane and every other lead target dev.

## Open
- 16:20Z poll: no change; slices still queued in the lane; full CI on dev queued (527676af); #3474 quiet.
- 15:53Z poll: no change; #4894/#5092 prescreen still success, waiting in the lane; stacked PRs unlabelled; #3474 quiet.
- 15:25Z poll: no change; all five PRs open and unlabelled for fixes; full CI on dev in progress (f86f72f7); #3474 quiet; #5321 open.
- 14:52Z poll: no change; #4894/#5092 queued, #4936/#5123/#5801 stacked; full CI on dev in progress; #3474 quiet.
- 14:45Z: #5123 fixed (stale HaloFilesCommandTests.aSavedProjectIsRecent failed with Halo's list gone; now puts the project in the suite's recents), head 0fb13ae9, body gets Belt-Lead/Feature/Slice/Fast-Check/Head. Follow-up #5801 opened, stacked on #5123: imageRefusal removed, S20 notes say PH-3, mutation renamed +2 (7/7). Packet line 95 still names .imagesRefusedUntilS20: update after #5092 lands. Slices still queued in the lane.
- 14:25Z poll: no change on #4894/#4936/#5092 (lane queue). Building the follow-up fix (drop imageRefusal, S20 comments to PH-3, mutation label, +2 mutations) on fix/halo-file-flow-s20-notes, stacked on #5123.
- 2026-10-26T13:52Z poll: no change; #4894/#4936/#5092 open, clean, eligible, queued. No lane merge since #5266 13:21Z. 27 open line:halo findings, none on file-flow (newest are drift reports for stroke-style, transform, placed-images). No supervisor answer.
- 2026-10-26T13:31Z poll: no change. Lane run 40323409808 rates #4894 and #5092 eligible (Fast-Check marker + local-ci/prescreen); 125 ready PRs wait behind one-at-a-time batches. Other PRs landed (#5266 13:21Z, #5781, #5146). No supervisor answer; dev-red #5321 open (macOS); no file-flow findings.
- 2026-10-26T13:06Z poll: no change. #4894 d9c7c9d2, #4936 a713dc26, #5092 a95e7b0e still open, clean, eligible; lane busy (ci.yml runs on dev 57dd31ff: Linux check, scoped photo). No supervisor answer to the 04:06Z question. dev-red #5321 open (macOS). No file-flow findings. Record mirrored on lead/file-flow and here (Belt reads this branch).
- 2026-10-26T12:45Z resume (act-1a1783581a6-fo4a): #4894 (d9c7c9d2, prescreen green), #4936 (a713dc26, on HF-m) and #5092 (a95e7b0e) open, clean, fast-lane, beta. Lane run 40320708539 rates #4894 and #5092 eligible; it lands one PR at a time (LANE_VERIFY_AFTER=1) behind a long queue. dev-red #5321 open (macOS, not ours). Question on #3474 (04:06Z, why #4894 doesn't land) has no answer yet.
- Record moved back to lead/file-flow at docs/leads/file-flow/ (brief): the suite lead moved its record to lead/suite-file-flow on 10-21, so the name is free. lead/file-flow was rebuilt on origin/main (its old history is unrelated to main's, so it could not rebase). lead/halo-file-flow keeps the history up to 11:52Z.
- Follow-up fix after HF-m lands (Packet-Review 2 items 3, 4): delete unused `imageRefusal`, fix the S20 comments and the mutation label. Item 10 (HaloFiles' own recent list) is #5123, stacked on HF-4.
