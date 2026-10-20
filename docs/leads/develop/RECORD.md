# develop lead record

Issue: #1527 · Packet: docs/blueprints/library/features/develop.md
Run: act-1a1543fe40d-7l1y · Session: claude/library-feature-lead-zn216c · Started: 2026-10-19T12:20Z (earlier: act-1a150baa34c-jzk9)
Stage: 3 wave 4 (DV-11; DV-3 and DV-8 from wave 3 still open)
Base: 507719b37a0f61d4242352f01481193829be3a87 (origin/dev; the brief's main f7e03506 is its ancestor)
Next: resumed after container restart: DV-9 #3221 merge state, DV-10 draft #3250 (stacked, ready after #3221 merges), EX-6 #3251 body fix

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DV-a | new catalog fields open neutral, survive save, change thumbnail token | DV-1, DV-2 | MJ1 | spine, persist, thumbnails, loupe-viewport (all built) | no | 0 | done | 39192572958 | - |
| DV-b | slider, curve, levels, reset, copy, paste, sync as undo steps | DV-3, DV-4 | MJ2 | DV-a (DV-3) | no | 0 | done (Belt-Slice-Done, dev CI 39221576463 Linux green) | - | - |
| DV-c | live renderer passes, fixed order, histogram | DV-5, DV-6 | MJ3 | DV-a | no | 0 | done | 39192572958 | - |
| DV-d | Develop tab on the fakes, reachable from the inspector | DV-7, DV-8, DV-9, DV-10 | J5 | DV-a (DV-8, DV-9); spine follow-up (DV-9) | yes | 0 | building | - | - |
| DV-e | vibrance and saturation through CoreRaster | DV-11, DV-12 | MJ4 | DV-c; creative-core issue and its bump (DV-12) | no | 0 | done (per Belt) | - | - |
| DV-f | integrate: live services, relaunch survival, frame budget | DV-13, DV-14, DV-15 | J5, P3 | DV-d, DV-c, DV-b, DV-e | no | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DV-1 | DV-a | 1 | new sliders, ToneCurve, DevelopLevels, back-compatible coding, fingerprint; MJ1 coding half | Sources/LibraryModel/Contracts/DevelopValues.swift, Tests/LibraryModelTests/LibraryDevelopValuesTests.swift, Tests/mutations/LibraryModel.DevelopValues.json | LibraryDevelopValuesTests | #3002 | merged ee16d135 |
| DV-7 | DV-d | 1 | J5 written whole, skipped with its reasons | UITests/LibraryJourneyTests+Develop.swift | J5 compiles and skips | #2995 | merged 9ece98c5 |
| DV-2 | DV-a | 2 | slots: LibraryDevelop signatures, thumbnail token, fake loupe lifts; tests disabled | Sources/LibraryModel/LibraryDevelop.swift, Sources/LibraryModel/LibraryThumbnails.swift, Sources/LibraryModel/Fakes/FakeRendering.swift, Tests/LibraryModelTests/LibraryDevelopTests.swift, Tests/LibraryModelTests/LibraryDevelopValuesTests.swift, Tests/mutations/LibraryModel.LibraryThumbnails.json, Tests/mutations/LibraryModel.FakeRendering.json | LibraryDevelopValuesTests (MJ1 whole) | #3039 | merged 1f3f72a1 |
| DV-5 | DV-c | 2 | render and budget checks, disabled until DV-6 (packet row; tests only) | Tests/LibraryModelTests/LibraryDevelopRenderTests.swift, Tests/LibraryModelTests/LibraryDevelopBudgetTests.swift | both compile, disabled "waits on DV-6" | #3038 | merged 91d02681 |
| DV-6 | DV-c | 3 | LiveDevelop: pass list, CoreRaster calls, neutral untouched, histogram, waiting; enables DV-5's tests | Sources/LibraryModel/Live/LiveDevelop.swift, Tests/LibraryModelTests/LibraryDevelopRenderTests.swift, Tests/LibraryModelTests/LibraryDevelopBudgetTests.swift, Tests/mutations/LibraryModel.LiveDevelop.json | LibraryDevelopRenderTests, LibraryDevelopBudgetTests | #3065 | merged 4747a796 |
| DV-3 | DV-b | 3 | slider, curve, levels edits, coalescing, resets, helps | Sources/LibraryModel/LibraryDevelop.swift, Tests/LibraryModelTests/LibraryDevelopTests.swift, Tests/mutations/LibraryModel.LibraryDevelop.json | LibraryDevelopTests | #3095 | merged 7acc00bf |
| DV-8 | DV-d | 3 | develop area and menu closures | Sources/LibraryApp/LibraryMenus.swift, Sources/LibraryApp/LibraryWindow+Develop.swift, Sources/LibraryApp/LibraryWindow+Thumbnails.swift | macOS build; LibraryDevelopMenuTests (fix 1) | #3086 | merged b749dd94 |
| DV-11 | DV-e | 4 | color checks and MJ4, disabled "waits on DV-12" | Tests/LibraryModelTests/LibraryDevelopColorTests.swift | compiles, disabled | #3098 | merged b48cf6c4 |
| DV-4, DV-9 | DV-b, DV-d | 4 | see packet (DV-4 after DV-3, DV-9 after DV-8) | see develop.wave.json | see packet | - | planned |
| DV-10, DV-12, DV-14 | - | 5 | see packet | see develop.wave.json | see packet | - | planned |
| DV-13 | DV-f | 6 | see packet | see develop.wave.json | see packet | - | planned |
| DV-15 | DV-f | 7 | blueprint prose, feature-done | docs/blueprints/library.md | see packet | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Resume of Belt's rebuilt record. The earlier run was blocked on spine, persist, thumbnails and loupe-viewport. All four are now built on dev, and no DV task had started.
- Base is origin/dev, not main (CLAUDE.md). main f7e03506 is an ancestor of dev 507719b3.
- One combined wave plan with status-and-layout and export. Export's EX-a shares Sources/LibraryModel/Fakes/FakeRendering.swift with DV-a, so EX-1 runs only after DV-2 has merged.
- DV-12 needs `PixelBuffer.saturation(_:)` / `vibrance(_:)` in creative-core. This session's GitHub scope is qbtrix/creative-apps only, so the needs-core issue can't be filed from here. Asked the supervisor (Open). Per open question 1, DV-15 ships with those rows disabled and DV-e becomes a gap if the bump isn't on dev.
- Wave 1 macOS build-only runs failed on dev's own PhotoZoomSweepTests (TileCanvasView, #3005), fixed on dev by #2990. Each wave 1 branch gets origin/dev merged in (a merge commit), scripts/ci --changed, push, Head moved; no PR content changes.
- PR bodies: in this environment `gh api -X PATCH` re-adds a "Generated by Claude Code" footer; builders and fixers create and edit PR bodies only with the GitHub MCP tools (create_pull_request, update_pull_request) and re-read the body to confirm it ends at Head:.
- DV-5's row corrected to the packet: tests only (LibraryDevelopRenderTests, LibraryDevelopBudgetTests), disabled until DV-6; LiveDevelop.swift is DV-6's.
- Wave 2 contract check flagged #3039's Mutate: line above Fast-Check:. The brief puts it exactly there, so the check was wrong; build-wave.js's contract text now names the line. #3039 meets the contract.

- DV-8 (#3086): the contract check found no test, and the view working out its own enable rules (canEdit, show original, copy needs one target). Fix round 1 moves them into a new LibraryDevelop+Menu.swift (outside DV-3's file) with LibraryDevelopMenuTests and a mutation plan.
## Open
- DV-6 (#3065) misses the three QB-LIB-6 release render budgets on the Linux worker (preview 512: 44.7 ms vs 8; histogram 2048: 406 ms vs 10; full 2048: 897 ms vs 120). Per packet Q3 a miss files the fused-pass creative-core issue (`PixelBuffer.developed(...)`, every slider plus curve and levels in one pass, equal to the chained calls within 1e-6), not a looser budget. This session can't reach qbtrix/creative-core; asking the supervisor to file it with `needs-core`. The histogram row is a single core `Histogram(of:)` call.
- needs-core (qbtrix/creative-core): saturation and vibrance on PixelBuffer, spec in develop.md's header. Not filed: outside this session's repo scope. Supervisor, please file it or grant scope. Draft text: title "CoreRaster: PixelBuffer.saturation(_ amount: Float) and vibrance(_ amount: Float)", amount -100...100, linear light, Rec. 709 luminance kept within 1e-3, grey unchanged, identity at 0, RasterError.invalid on non-finite, 24 MP under 1 s.
- Filed: #2983 gap, pass menu/model to LibraryInspector and DevelopInspector (DV-9 waits on it); #2984 needs-ui S-L1 HistogramView; #2985 needs-ui S-L6 InspectorSliderRow onReset.
- 03:42Z check: CI 39192572958 (cc14022e) Linux green and contains DV-1, DV-2, DV-5, DV-6, so DV-a and DV-c are merged-done; Belt-Slice-Done posted for both. #3095, #3086, #3098 still open in the lane (macOS build queue). No panel: DV-d not fully merged.
- 04:06Z check: DV-3 #3095 merged 7acc00bf and DV-11 #3098 merged b48cf6c4. DV-4 starts on b48cf6c4. DV-8 #3086 is still in the lane. CI 39195661324 was cancelled; 39196649963 (7acc00bf) is pending. 0 open findings.
| DV-4 | DV-b | lead-dv4-copy-paste-sync | #3113 | merged f64820f2 |
- 04:17Z DV-4 PR #3113 is open, head dc77c4f4, CI: PASS, mutate 11/11 LibraryModel.LibraryDevelop. Choice: copiedSummary reads "No adjustments" when the copied settings are all neutral.
- 04:29Z check: DV-4 #3113 and DV-8 #3086 are in the lane. 0 open findings.
- 04:54Z check: dev at bede8342 (core bump). Lane PRs still open; 0 open findings.
- 06:02Z check: DV-4 #3113 merged f64820f2. DV-8 #3086 macOS build failed (type checker at LibraryWindow+Develop.swift:24); fixer pushed 153381d8 splitting the menu closures; local gate hit disk-full, so the lane proves the head. 0 open findings.
- 06:26Z check: dev run 39208339251 (6dd055f6) was cancelled, so DV-b waits on 39209778800 (d4814191). DV-8 #3086 at 153381d8 failed the lane's macOS build (39208646635) with 'failed to produce diagnostic' at LibraryWindow+Develop.swift:28 and :39, the two-argument closures built with `canEdit ? {…} : nil`. Fixer dispatched: route them through a two-argument enabled<First, Second> helper beside the existing ones. 0 open findings.
- 06:32Z DV-8 fix pushed to #3086 at cae6cdd7: set and setLevels now go through enabled<First, Second>, which removes the closure-literal ternaries; no other such ternaries in DV-8's LibraryApp code; Linux gate passed; Head line moved, body clean. The lane's macOS build decides.
- 06:51Z check: nothing merged; dev run 39209778800 cancelled, CI 39211832383 (977df193) pending; lane PRs await Linux/macOS builds
- 07:15Z check: nothing merged; dev CI 39211832383 and 39213562657 cancelled, 39214719821 (34b8df25) pending; macOS build runs queued (runner backlog)
- 07:37Z check: nothing merged; runners backlogged (dev CI 39203617095 still on macOS; newer dev runs superseded while queued, now 39215489121 at 57d85dfd); lane macOS builds all queued, none failed
- 08:00Z check: DV-b: dev CI 39215489121 (57d85dfd, has f64820f2) still pending; DV-8 #3086 build 39212425550 queued
- 08:22Z check: DV-b: dev CI 39215489121 cancelled; newest 39221576463 (6f9a2b88, has f64820f2) pending; DV-8 #3086 build 39212425550 queued
- 08:45Z check: DV-b: dev run 39221576463 (6f9a2b88, contains f64820f2) Linux in progress; DV-8 #3086 macOS build 39212425550 queued
- 09:09Z check: DV-b: dev runs superseded again; newest 39226253814 (097b0d52) pending; DV-8 #3086 build 39212425550 still queued
- 09:31Z check: DV-b: newest dev run 39226253814 (097b0d52) pending; DV-8 #3086 build 39212425550 running
- 09:54Z check: DV-8 #3086 merged b749dd94. DV-b done: dev run 39221576463 (6f9a2b88, has f64820f2) Linux green, newer runs cancelled/pending before Linux; Belt-Slice-Done posted on #1527, footer stripped. #2983 closed (57d85dfd), DV-9 started (wf_e3c39652-f90). 0 open findings.
- 10:10Z DV-9 reported: #3221 (21757afc), contract check ok, body clean (0 footer), fast-lane. DV-10 starts once it merges.
- 2026-10-19T10:17Z check: DV-9 #3221 macOS build 39235663702 queued; DV-10 after merge
- 2026-10-19T10:40Z check: DV-9 #3221 macOS build 39235663702 queued; DV-10 after merge
- 11:04Z check: DV-9 #3221 macOS build failed (LibraryDevelopSnapshots.swift:34 Develop menu init); fixer dispatched
- 11:10Z fix: DV-9 #3221 fixer pushed 2e67c5df (typed closures in snapshot menu); footer 0; awaiting lane macOS build
- 11:26Z check: DV-9 #3221 head 2e67c5df, macOS build 39243123840 dispatched
- 11:50Z check: DV-9 #3221 head 2e67c5df, macOS build 39243123840 queued
- 12:55Z run act-1a1543fe40d-7l1y: lead/develop rebuilt on main 6f9a2b88 (record only). Belt marks DV-e done; remaining DV-d, DV-f. DV-9 #3221 macOS build 39243123840 success; lane merges next. Dev CI runs since 08:16Z all cancelled while queued (39252895176 at 6e70826b pending).
- 2026-10-19T14:23Z check: DV-9 #3221 mergeable clean, build green, waiting on lane sweep. DV-10 draft #3250 (e29bc8d2) stacked on it; marked ready once #3221 merges.
- 2026-10-19T15:35Z check (after container restart): DV-9 #3221 clean, green build, waiting on lane; DV-10 draft #3250 stacked on it. Next: mark #3250 ready once #3221 merges, then DV-13.
- 2026-10-19T15:37Z DV-13 building, stacked on DV-10 #3250 (wf_086b691e-0d5). DV-14 can't run until #782 (FrameProbe marks) is on dev, so it's filed as gap #3286 per waves.md. DV-12 still waits on the core bump. #3221 (DV-9) in lane; #3250 to be marked ready when it merges.
- 2026-10-19T16:07Z DV-9 #3221 lane fix: needs-fix from Linux run 39268784025 (CommandPathTests, unbaselined row Reset menu). Merged origin/dev, baselined the site (needs-ui #3290 for a slider-row reset), scripts/ci --changed PASS, head 3b9b5ac0, Head line moved and Belt-Lead set to this run. DV-13 relaunched as wf_2a0949c2-75d on base 6e70826b.
- 2026-10-19T16:14Z DV-13 draft #3295 (1e2be5b7) stacked on #3250. Footer stripped. Contract check flags (size 502, DV-9/DV-10 files) are the stack and clear as #3221 and #3250 merge. Order: #3221 -> mark #3250 ready -> after it merges, merge dev into DV-13, move Head, mark ready.
- 2026-10-19T16:35Z check: dev still b3011ab9. DV-9 #3221 macOS build 39283815084 green on 3b9b5ac0, needs-fix dropped; lane merges next sweep. #3250 and #3295 drafts wait on it.

- 2026-10-19T16:57Z heartbeat: dev at ed4d55fd; none of this lead's PRs merged yet; waiting on the lane sweep.

- 2026-10-19T17:27Z: #3221 needs-rebase: merged dev (CR-6 conflict in DevelopInspector), gate PASS, head 510c7bf5

- 2026-10-19T17:52Z: dev 1b33afbb; #3221 DV-9 head 510c7bf5 clean, waiting on lane macOS build; drafts #3250, #3295 wait on it
- 2026-10-19T18:19Z: check-in: #3221 DV-9 pending, the lane is waiting on macOS build 39294392519 for head 510c7bf5; #3250 and #3295 drafts wait on it
- 2026-10-19T18:41Z: #3221 DV-9 open, clean, head 510c7bf5, waiting on lane macOS build 39294392519; drafts #3250 DV-10 and #3295 DV-13 wait on it
- 2026-10-19T19:04Z: #3221 DV-9 still open/clean at 510c7bf5; lane macOS build 39294392519 queued since 17:28Z (macOS runner backlog, 21 queued runs, one macOS job running)
- 2026-10-19T19:25Z: #3221 DV-9 open/clean at 510c7bf5; macOS build 39294392519 still queued (no macOS job running repo-wide)
- 2026-10-19T19:48Z: #3221 DV-9 open/clean at 510c7bf5; macOS build 39294392519 still queued, no workflow running repo-wide
- 2026-10-19T20:11Z: #3221 DV-9 lane macOS build 39294392519 succeeded; waiting for the next lane sweep to merge
- 2026-10-19T20:25Z: #3221 DV-9 build 39294392519 green; waiting on the next lane sweep (none since 19:40Z)
- 2026-10-19T20:48Z: #3221 DV-9 still open (build green); no scheduled lane sweep since 19:40Z, 16 runs queued repo-wide
- 2026-10-19T21:28Z: #3221 DV-9 merged. #3250 DV-10 merged with dev (conflicts resolved, crop CR-6 kept), gate pass, 113 lines, head c8132980, ready. #3295 DV-13 merged with DV-10, gate pass, head bbd009af, stays draft until #3250 merges
- 2026-10-19T22:17Z: #3250 (DV-10) merged 21:49Z as 23e682ad. #3295 (DV-13, slice DV-f) merged dev, gate PASS, ready at d0a3fbf6 (137+/23-). DV-d done waits on green dev CI 39333170092 (a7e93ca4).
- 2026-10-19T22:45Z: DV-d tasks all on dev (cf120143); done comments wait for green dev CI 39336158094 (pending). #3295 DV-13 open, clean.
- 2026-10-19T23:12Z: dev CI 39336158094 (cf120143) still pending; DV-d done comment waits. #3295 open, fast-lane, no needs-* label.
- 2026-10-19T23:43Z: 23:39Z check-in: no green dev CI yet (39342355180 on f564907d pending); DV-d awaits it. #3295 (DV-13) open.
- 2026-10-20T00:13Z: 00:10Z check-in: #3295 macOS build failed on #require around mutating loupeRequest; fixed locally, gating. Rule 23 question posted on #1527 (no green dev run since cf120143; 5 quarantine entries expired 2026-10-20 fail every gate).
- 2026-10-20T00:41Z: 00:41Z check-in: DV-13 #3295 merged 00:39Z (407cd914). Supervisor answered: green Linux job on a run containing the last PR is the proof; #3380 renewed the quarantine (2019b521). Waiting for a dev run at or after 2019b521 with a green Linux job for DV-d. DV-f also needs DV-15, which waits on DV-e (core bump, DV-12).
- 2026-10-20T01:09Z: DV-13 #3295 merged. DV-d done proof waits on the Linux job of dev run 39349878829 (2019b521, in progress). DV-f: DV-15 waits on DV-e (DV-12 core bump); DV-14 is gap #3286. 0 open findings.
- 2026-10-20T01:16Z: DV-d done: Linux job green on dev run 39349878829 (2019b521, contains DV-13 #3295). Belt-Slice-Done and Mac-Finish-Wanted posted on #1527. DV-f waits on DV-15 (after DV-e).
- 2026-10-20T01:35Z: check: DV-a..DV-d done. DV-f waits on DV-15 (after DV-e, DV-12 core bump); DV-14 gap #3286. 0 open findings.
- 2026-10-20T02:02Z: check: no change. DV-f waits on DV-15 (after DV-e, DV-12 core bump); DV-14 gap #3286. 0 open findings.
- 2026-10-20T02:29Z: check: no change; no supervisor news on #1527. DV-f waits on DV-15 (after DV-e).
- 2026-10-20T02:56Z: check: no change; no supervisor news on #1527. DV-f waits on DV-15 (after DV-e).
