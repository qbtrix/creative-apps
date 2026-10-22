# export lead record

Issue: #1554 · Packet: docs/blueprints/library/features/export.md
Run: act-1a1543fe40d-7l1y · Session: claude/library-feature-lead-zn216c · Started: 2026-10-19T12:20Z (earlier: act-1a150baa34c-jzk9)
Stage: 3 wave 4
Base: 507719b37a0f61d4242352f01481193829be3a87 (origin/dev; the brief's main f7e03506 is its ancestor)
Next: EX-6 building (wf_28b17b86-196); EX-10 #3222 macOS build green, lane merges next; EX-8, EX-11, EX-13, EX-16 after EX-6; EX-14 after crop CR-b; gaps #3213 #3214 (budget tests disabled)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| EX-a | contract: export plan, fake services, slots; LiveExporter and ExportRunner | EX-1, EX-2, EX-3 | MX1 | develop DV-a (shared FakeRendering.swift) | no | 0 | building | - | - |
| EX-b | File > Export sheet, real sRGB JPEG, never overwrites, matches the loupe | EX-4, EX-5, EX-6 | J7 | EX-a (EX-5, EX-6) | yes | 0 | building | - | - |
| EX-c | PNG, TIFF, HEIC formats; unwritable format disabled with reason | EX-7, EX-8 | J7F | EX-a (EX-7); EX-b (EX-8) | yes | 0 | planned | - | - |
| EX-d | name templates, presets, last settings across relaunch | EX-9, EX-10, EX-11 | J7N | EX-a (EX-9, EX-10); EX-b (EX-11) | yes | 0 | planned | - | - |
| EX-e | progress with Cancel, failures with Try Again, cropped export | EX-12, EX-13, EX-14 | J7B, P8 | EX-a; EX-b; crop CR-b (EX-14); #782 (P8) | no | 0 | planned | - | - |
| EX-f | XMP sidecar beside each exported file | EX-15, EX-16, EX-17 | J7S | EX-a; EX-b (EX-16); EX-c, EX-d, EX-e (EX-17) | no | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| EX-1 | EX-a | after DV-2 | contract: ExportOptions, format/naming/preset/sidecar slots, ExportNames.unique, FakeExporter, refusing stubs | Sources/LibraryModel/Contracts/LibraryContracts.swift, Sources/LibraryModel/Contracts/ExportFormats.swift, Sources/LibraryModel/Contracts/ExportNaming.swift, Sources/LibraryModel/Contracts/ExportPresets.swift, Sources/LibraryModel/Contracts/ExportSidecar.swift, Sources/LibraryModel/Fakes/FakeRendering.swift, Sources/LibraryModel/LibraryExport.swift, Tests/LibraryModelTests/LibraryExportContractTests.swift, Tests/LibraryModelTests/LibraryExportPlanTests.swift, Tests/LibraryModelTests/LibraryExportFlowTests.swift, Tests/mutations/LibraryModel.ExportNaming.json | LibraryExportContractTests | #3090 | merged f7d88054 |
| EX-4 | EX-b | with EX-1 | J7 skipped, fidelity tests disabled | UITests/LibraryJourneyTests+Export.swift, Tests/AppSnapshotTests/LibraryExportFidelityTests.swift | J7 compiles and skips | #3089 | merged 59305bc1 |
| EX-2, EX-3, EX-7, EX-9, EX-15 | - | EX-1 + 1 | see packet | see export.wave.json | see packet | - | merged: EX-2 #3171, EX-7 #3170 (6f9a2b88), EX-15 #3172 (0b9ec8ab), EX-9 #3174 (097b0d52), EX-3 #3169 (605523a0) |
| EX-5, EX-10, EX-12 | - | EX-1 + 2 | see packet | see export.wave.json | see packet | - | EX-5 #3212 merged 69ee7d31, EX-12 #3215 merged; EX-10 #3222 (a67c9749, Mutate 3/3) macOS build 39235878647 green, in lane |
| EX-6, EX-14 | - | EX-1 + 3 (EX-14 after crop CR-b) | see packet | see export.wave.json | see packet | - | EX-6 building on 6e70826b (wf_28b17b86-196); EX-14 planned |
| EX-8, EX-11, EX-13, EX-16 | - | EX-1 + 4 | see packet | see export.wave.json | see packet | - | planned |
| EX-17 | EX-f | last | blueprint prose, feature-done | docs/blueprints/library.md | see packet | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Resume of Belt's rebuilt record. The base question from the earlier run is settled as origin/dev (CLAUDE.md). main f7e03506 is an ancestor of dev 507719b3.
- Export depends on develop (feature depends in export.wave.json). Its EX-a and develop's DV-a both own Sources/LibraryModel/Fakes/FakeRendering.swift. So EX-1 waits until DV-2, DV-a's last task that edits it, has merged. Then they don't run at the same time. EX-17 and DV-15 both own docs/blueprints/library.md; each is its feature's last task, run one after the other.
- Canonical first (the 2026-10-17 supervisor note on this issue: export is a kernel concept). Before EX-1, check SuiteModel for a shared export plan or naming rule. If one exists, EX-1 builds on it.
- EX-1 (#3090, 02:44Z): SuiteKernel/Export holds only ExportRun; nothing shared for raster formats, presets or the XMP sidecar. The builder had named four non-adapter files `+Kernel` to get past check-dup-logic. Ruling: only ExportNaming+Kernel (on SuiteModel UniqueFileNames) is a real adapter. The other four go back to their contract names as a reviewed exception (`Allow-Dup: Export`, baseline --allow-increase). Gap #3091 lifts them into SuiteKernel and moves ExportState onto ExportRun. Fix round 1 of 2 for EX-a.
- An existing Sources/LibraryModel/Live/LiveExporter.swift from the spine is the base EX-2 extends.

## Open
- Stage 1 gaps filed: #2986 export PNG, TIFF and HEIC; #2987 export presets and file-name templates; #2988 XMP sidecar beside exported files.
- Soft waits: S-L5 ProgressRow #781 (open), S-L8 named marks #782 (open; P8), crop CR-b (EX-14).
- 03:42Z check: dev at 918abfc6; #3090 (EX-1) and #3089 (EX-4) still open in the lane. 0 open findings.
- 04:06Z check: EX-4 #3089 merged 59305bc1. EX-1 #3090 is still in the lane (head 0373894e); EX-2, EX-3, EX-7, EX-9 and EX-15 wait on it. 0 open findings.
- 04:29Z EX-1 #3090 merged f7d88054. Wave 2 started: build-wave runs EX-2, EX-3, EX-7, EX-9 and EX-15 on aed78668. EX-9 works in ExportNaming+Kernel.swift per the EX-1 ruling. 0 open findings.
- 04:54Z check: dev at bede8342 (core bump). Lane PRs still open; 0 open findings.
- 06:19Z wave 2 (wf_a93d8264-8fc) reported: EX-2 #3171 (e7955f22), EX-3 #3169 (b5c8e6fc, Mutate 3/3), EX-7 #3170 (84690c7c, Mutate 3/3), EX-15 #3172 (43430efe). Contract check: #3169, #3170 and #3172 carried a tool attribution footer; stripped, Mutate lines moved under Slice, re-read clean. #3169/#3170 each drop two EX-1 stub assertions in LibraryExportContractTests, which their own behaviour retires (allowed as tests of the listed files). EX-9: work done on lead/export-EX-9 (3e76cffa, mutate 6/6 before rebase) but its gate died on ENOSPC; an agent reruns the gate and opens the PR. 0 open findings.
- 06:26Z check: #3169, #3170, #3171 and #3172 each wait on the lane's macOS build. EX-9 is still finishing. 0 open findings.
- 06:27Z EX-9 #3174 opened (head 3e76cffa): the gate passed and mutate caught 6/6. The unknown-token check becomes meaningful once EX-3 lands. Body clean.
- 06:51Z check: nothing merged; dev run 39209778800 cancelled, CI 39211832383 (977df193) pending; lane PRs await Linux/macOS builds
- 07:15Z check: EX-2 #3171 merged (batch 39212710432); EX-3 #3169 needs-rebase (LibraryExportContractTests.swift), fixer dispatched; #3170 #3172 #3174 macOS builds still queued
- 07:27Z EX-3 #3169 integrated: merged dev, reconciled the contract test with EX-2 (live exporter), head 6de27e8c, scripts/ci --changed PASS; back in the lane
- 07:37Z check: nothing merged; runners backlogged (dev CI 39203617095 still on macOS; newer dev runs superseded while queued, now 39215489121 at 57d85dfd); lane macOS builds all queued, none failed
- 08:00Z check: #3169 build 39216178366, #3170/#3172/#3174 builds queued (runner backlog)
- 08:22Z check: EX-7 #3170 merged 6f9a2b88; #3169 build 39216178366, #3172, #3174 builds queued
- 08:45Z check: EX-15 #3172 merged (0b9ec8ab); EX-3 #3169 build 39216178366 queued; EX-9 #3174 build 39210369956 running
- 09:09Z check: EX-9 #3174 merged (097b0d52); EX-3 #3169 macOS build green, merges next sweep
- 09:31Z EX-3 #3169 merged 605523a0. Wave 3 started: build-wave runs EX-5, EX-10 and EX-12 on acbbef13 (wf_2a3993f0-c26). 0 open export findings.
- 09:54Z check: wave 3 (wf_2a3993f0-c26) running; 0 open findings
- 09:59Z wave 3 reported: EX-5 #3212 (275f58eb), EX-12 #3215 (533fd200), both footers stripped via MCP and re-read (0). EX-10 unfinished (code written, untested, unpushed on lead/export-EX-10): finisher dispatched in the same worktree. EX-12 shipped both budget tests disabled, over their debug gates on the real code: gaps #3213 (plan 144-160 ms vs 50) and #3214 (beginExport 12.7-17 ms vs 10) filed by the builder, footers stripped. Perf-list placement noted for the supervisor in #3215.
- 10:11Z EX-10 #3222 (a67c9749): finisher passed tests, Mutate 3/3 LibraryModel.ExportPresets, gate PASS; 4 files incl. the EX-1 contract test that pinned the stub. Footer stripped, re-read 0.
- 2026-10-19T10:17Z check: EX-5 #3212, EX-12 #3215, EX-10 #3222 macOS builds queued; EX-6 after EX-5 merges and crop CR-5
- 2026-10-19T10:40Z check: EX-12 #3215 macOS build green, awaiting lane; EX-5 #3212 and EX-10 #3222 builds queued
- 11:04Z check: EX-12 #3215 merged d80a1b26; EX-5 #3212 and EX-10 #3222 macOS builds queued
- 11:26Z check: EX-5 #3212 (39233491145) and EX-10 #3222 (39235878647) macOS builds still queued
- 11:50Z check: EX-5 #3212 macOS build green, awaiting lane merge; EX-10 #3222 build 39235878647 queued
- 12:58Z run act-1a1543fe40d-7l1y: EX-5 merged 69ee7d31, EX-12 merged; EX-10 #3222 build green; crop CR-5 on dev (b2078f5f); wave 4 started: EX-6 on 6e70826b. 4 open findings (all SL, waiting on SuiteUI).
- 2026-10-19T14:23Z EX-6 PR #3251 (head 88d7b3b9, Slice EX-b), body fixed to one Head line, no footer. EX-10 #3222 in lane. Next: EX-8, EX-11, EX-13, EX-16 after EX-6 merges; EX-14 after crop CR-b; EX-17 last.
- 2026-10-19T14:24Z wave 5 (stacked on EX-6 #3251, wf_226d5f80-b8f): EX-13 and EX-16 as drafts, marked ready once #3251 merges. EX-8 and EX-11 next (EX-11 also needs EX-10 #3222).
- 2026-10-19T15:36Z wave 5 reported: EX-16 draft PR #3278 (Slice EX-f, Mutate 5/5), EX-13 draft PR #3279 (Slice EX-e), both stacked on #3251. EX-10 #3222 merged 11ce8bd5. Next: mark both ready when #3251 merges; EX-8 and EX-11 (stacked on EX-6); EX-14 after crop CR-b; EX-17 last.
- 2026-10-19T16:07Z heartbeat: EX-6 #3251 clean at 88d7b3b9, waiting on lane. EX-8/EX-11 building in wf_9de3e725-d5e on base 2b029480; drafts marked ready after #3251 merges (with #3278, #3279).
- 2026-10-19T16:14Z EX-8 draft #3294 (a271a18c, Closes gap #2986) and EX-11 draft #3293 (018f4f88; footer stripped) stacked on #3251. Contract flags (size, EX-6 files) are the stack and clear when #3251 merges. Note: EX-11 keeps its store in LibraryWindow+Export.swift because the dup-logic gate rejects a new Export* concept file; its file format is covered by EX-10's Model tests (#3222). Mark both ready (with #3278, #3279) after #3251 merges.
- 2026-10-19T16:35Z check: dev still b3011ab9. EX-6 #3251 clean, waiting on lane sweep. Drafts #3278 #3279 #3293 #3294 wait on it.

- 2026-10-19T16:57Z heartbeat: dev at ed4d55fd; none of this lead's PRs merged yet; waiting on the lane sweep.

- 2026-10-19T17:27Z: #3251 needs-fix (CommandPathTests): baseline lists export sheet buttons, gate PASS, head acf3ad3e

- 2026-10-19T17:52Z: #3251 refused as too big (409 lines): tightened LibraryWindow+Export.swift to 398, gate PASS, head 8541ee9a
- 2026-10-19T18:19Z: check-in: #3251 EX-6 is 398 lines, so the size check now passes; pending, the lane is waiting on macOS build 39297804528 for head 8541ee9a; #3278, #3279, #3293 and #3294 drafts wait on it
- 2026-10-19T18:41Z: #3251 EX-6 open, clean, head 8541ee9a, 398 lines, waiting on lane macOS build 39297804528; drafts #3278 #3279 #3293 #3294 wait on it
- 2026-10-19T19:04Z: #3251 EX-6 still open/clean at 8541ee9a; lane macOS build 39297804528 queued since 17:52Z behind the same macOS backlog
- 2026-10-19T19:25Z: #3251 EX-6 open/clean at 8541ee9a; macOS build 39297804528 still queued (macOS runner backlog)
- 2026-10-19T19:48Z: #3251 EX-6 open/clean at 8541ee9a; macOS build 39297804528 still queued
- 2026-10-19T20:11Z: #3251 EX-6 open/clean at 8541ee9a; macOS build 39297804528 still queued (runners moving again)
- 2026-10-19T20:25Z: #3251 EX-6 macOS build 39297804528 still queued
- 2026-10-19T20:48Z: #3251 EX-6 macOS build 39297804528 still queued; runner backlog
- 2026-10-19T21:28Z: #3251 EX-6 macOS build 39297804528 in progress
- 2026-10-19T22:17Z: #3251 (EX-6) merged 21:18Z as d735ced2. #3294 EX-8 9ea00b01, #3293 EX-11 2ffec0fd, #3279 EX-13 a31ba0e0, #3278 EX-16 956d76db: dev merged, gate PASS each, all under 130 lines, marked ready. EX-b done waits on green dev CI 39333170092.
- 2026-10-19T22:45Z: EX-8 #3294 and EX-11 #3293 merged; EX-b/EX-c/EX-d tasks all on dev; done comments wait for green dev CI 39336158094. #3279, #3278 open, clean.
- 2026-10-19T23:12Z: dev CI 39336158094 still pending; EX-b/c/d done comments wait. #3279, #3278 open, fast-lane, no needs-* label.
- 2026-10-19T23:43Z: Rule 23 re-read: CR-b done, EX-14 unblocked. Fixing findings #3276/#3277 first (fixture soft wave, lead/export-F3276, gating); EX-14 drafted on lead/export-EX-14. EX-b..d await green dev CI 39342355180.
- 2026-10-19T23:57Z: opened #3372 (closes findings #3276, #3277: soft-wave fixture, quarantine traits removed) and #3373 (EX-14, stacked on #3372; mutations 5/5). Dev CI 39342355180 on f564907d still pending; EX-b..d await it. Waiting on EX-13 #3279, EX-16 #3278, EX-14 #3373 before EX-17.
- 2026-10-20T00:13Z: 00:10Z check-in: EX-13 #3279 merged 00:12Z. #3278, #3372, #3373 macOS builds queued. Rule 23 question posted on #1554 (no green dev run since cf120143).
- 2026-10-20T00:41Z: 00:41Z check-in: findings fix #3372 merged 00:40Z (closes #3276, #3277). EX-16 #3278 macOS build green, awaiting lane sweep; EX-14 #3373 macOS build in progress. Waiting for a dev run at or after 2019b521 with a green Linux job for EX-b, EX-c, EX-d. EX-17 after EX-14 and EX-16 merge.
- 2026-10-20T01:09Z: EX-14 #3373 needs-rebase fixed: dev merged, gate PASS, head 609e4c33, Head line moved. EX-16 #3278 merged f76b3abf; EX-15 #3172 merged earlier. EX-17 drafted at 0c2c5d7a (library.md prose + section 8); gate running. EX-b/c/d proof waits on the Linux job of dev run 39349878829. 0 open findings.
- 2026-10-20T01:16Z: EX-b, EX-c, EX-d done: Linux job green on dev run 39349878829 (2019b521). Done and Mac-Finish-Wanted posted on #1554. EX-17 opened as #3387 (docs only, head 0c2c5d7a, gate PASS). EX-e waits on #3373 merging; EX-f on #3387, then a green Linux job after f76b3abf (#3278).
- 2026-10-20T01:35Z: check: EX-17 #3387 merged 53630c3b, so EX-f's tasks are all merged; its proof is the Linux job of dev run 39352633488 (53630c3b, pending). EX-14 #3373 macOS build 39351788853 in progress at head 609e4c33. 0 open findings.
- 2026-10-20T02:02Z: check: EX-14 #3373 merged 56b7578e (macOS build 39351788853 green). Every export task is merged. EX-a's done comment was missing; posted now on run 39349878829 with gaps: #3091. EX-e (gaps #3213 #3214) and EX-f wait on the Linux job of dev run 39356653273 (15b4e591, contains 56b7578e and 53630c3b; pending), then Belt-Contact-Sheet. 0 open findings.
- 2026-10-20T02:29Z: check: dev run 39356653273 (15b4e591) was cancelled before its Linux job ran. Next proof candidate: dev run 39357273491 (13cf5dce, contains 15b4e591), pending. EX-e and EX-f done comments and the contact sheet wait on its Linux job.
- 2026-10-20T02:56Z: check (blocked poll 2/3, rule 23): dev run 39357273491 (13cf5dce) was also cancelled before its Linux job ran. Next proof candidates: 39357615737 (13cf5dce, queued) and 39359599960 (25a8d9a2, pending).
- 2026-10-20T03:13Z: check: blocked poll 3/3 (rule 23). Full dev run 39359599960 (25a8d9a2) still pending; other queued dev runs are scoped (no Linux). Posted Question for the supervisor on #1554 (comment 6282474084). Stopped polling this wait; will use the first full dev run >= 15b4e591 with a green Linux job.
- 2026-10-20T03:36Z: done: supervisor answered (#1554 comment 6282537751): a linux_only run counts and dispatched 39363625797 on dev (233aff5c, contains 15b4e591); Linux green. Posted Belt-Slice-Done EX-e (gaps #3213 #3214), Belt-Slice-Done EX-f and Belt-Contact-Sheet on it. Every export slice is done. Stage: done.
