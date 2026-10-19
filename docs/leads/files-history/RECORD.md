# files-history lead record

Issue: #1499 · Packet: docs/blueprints/design/features/files-history.md
Run: act-1a14d285aef-3epc (line lead for design: shell-parity #1325, canvas-basics #1500, files-history #1499) · Session: claude/design-shell-parity-wlqm8c · Started: 2026-10-18T04:02Z
Stage: 2 building
Base: 6bb1f3f6072b1873c4827a682b9c1a750dac8f70
Next: wave 1 FH-2 (builder branch lead/files-history-FH-2). Then wave 2 FH-1, FH-3, FH-4 (DW-a is merged on dev).
Last check: 2026-10-18T04:02Z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FH-a | Saving and opening go through the live filing with the same bytes, the document knows when it is unsaved, and opening a bad file says exactly what is wrong. | FH-2, FH-1, FH-6 | J16 | design-contracts (built) | no | 0 | building | | – |
| FH-b | Undo in a text field undoes the typing, the window says when the file is saved, closing with unsaved changes asks first, and a 2,000-layer file opens within budget. | FH-3, FH-4, FH-5, FH-7 | J13, J14, P4 | FH-a (FH-3, FH-4, FH-7); design-window DW-a (merged) | yes | 0 | waits FH-2 | | |

Issues filed at stage 1: gap #2559 "Design: a journey for opening bad files" (FH-6 closes); follow-up #2560 "Design: adopt `EditorSaveStatus`" (depends on #1344, #339).

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FH-2 | FH-a | 1 | step serials, saved marker, isDirty, saveStateText, didSave, closePrompt, undoTarget | DesignHistory.swift, DesignFile.swift (didSave only), DesignDirtyTests.swift, DesignUndoTargetTests.swift, plan DesignModel.DesignHistory | DesignDirtyTests, DesignUndoTargetTests, Mutate | | building |
| FH-1 | FH-a | 2 | codec into LiveFiling, same bytes | Live/LiveFiling.swift, DesignFile.swift, DesignFilingTests.swift | DesignFilingTests | | waits FH-2 |
| FH-3 | FH-b | 2 | Edit > Undo/Redo route via undoTarget; close prompt | DesignCommands.swift, DesignClosePrompt.swift, DesignFileMenuSnapshots.swift | design-file-menu-close | | waits FH-2 |
| FH-4 | FH-b | 2 | save state in subtitle and design.status.save | DesignSaveStatus.swift, DesignFileSnapshots.swift | design-file-edited, design-file-saved | | waits FH-2 |
| FH-5 | FH-b | 3 | J13, J14 | UITests/DesignJourneyTests+Files.swift | journeys on the macOS run | | waits FH-3, FH-4 |
| FH-6 | FH-a | 3 | J16; closes #2559 | UITests/DesignJourneyTests+BadFiles.swift | journey | | waits FH-1 |
| FH-7 | FH-b | 3 | P4; J16 blueprint row; feature-done | UITests/DesignJourneyTests+PerfFiles.swift, docs/blueprints/design.md (J16 row) | P4 report, grep | | waits FH-1 |

Waves (packet's Build waves, checked against dev 6bb1f3f6):
- Wave 1: FH-2 alone (runs alongside canvas-basics CB-2: disjoint files).
- Wave 2: FH-1, FH-3, FH-4. All independent.
- Wave 3: FH-5, FH-6, FH-7 (feature-done, merged last).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- v3 loop: the packet has a Slices table.
- PRs target dev (CLAUDE.md; the lane retargets main to dev). The brief names main as the integration branch; main 0965457c was verified at start.
- Rule 20 (canonical first): dirty state and the save status belong to the kernel's DocumentSession (editor-kernel EK-session, not on dev), and undo to its History (EK-undo, not on dev). FH-2 adds no concept file: it extends DesignHistory.swift, which Tests/canonical-baseline.txt already lists, and keeps the saved marker a plain serial so adopt-kernel-undo (#1934) can swap it for the kernel's tokens. No Allow-Dup line is needed. Posted on #1499.
- FH-b is ui: true (FH-3, FH-4 change the window), so rules 15/17 apply: feel gate on its run, Mac-Finish-Wanted when done.
- Builder branches are lead/files-history-<task> (a lead/files-history/<task> ref can't sit beside this branch).

## Open
- None yet.

## Run act-1a14fd6514a-4hke (resumed 2026-10-18)

Resume point: Stage 3, wave 2 on dev@ae72cc6c.

- FH-2 merged as #2567 (slice FH-a).
- design-window DW-a has merged (#2163, #2168, #2213, #2214, #2217 and fixes), which unblocks FH-3 and FH-4.
- No open `finding` issue names files-history.
- Wave 2 builders: FH-1 (LiveFiling codec, same bytes), FH-3 (Undo routing and close prompt), FH-4 (save state in DesignSaveStatus).
- Wave 3, next: FH-5 (J13 and J14) once FH-3 and FH-4 merge; FH-6 (J16) and FH-7 (P4, feature-done) once FH-1 merges.
- FH-1: merged as #2870 (head e72b3ae0, Mutate 5/5 DesignModel.LiveFiling). Wave 3 started: the FH-6 builder (J16).
- FH-6: PR #2879 (head 76353674, J16 in +BadFiles, closes gap #2559). The contract check passed.
- FH-4: PR #2866 (head 07210d46). It filed #2861 (`needs-ui`, `line:suiteui`) for the window's edited dot.
- FH-3: PR #2873 (head 6f3f7a50, finished by a fixer after the builder stopped before the gate; 3 files, +250/-24).
- The PR bodies were cleaned of the auto-added attribution footer through the GitHub MCP update. A REST PATCH re-adds it.
- Slice done lines: none yet.

- 2026-10-18T18:18:09Z: FH-3 #2873 and FH-6 #2879 merged; FH-a is fully on dev. Wave 4 (wkf4hdp2e): FH-5 and FH-7, FH-7 held with `no-fast-lane` so it merges after FH-5.
- 2026-10-18T18:30:31Z: wave 4 opened FH-5 #2896 (head b8412161) and FH-7 #2894 (head bfcccd0d, held). Both had the attribution footer stripped. Contract checks were otherwise clean.
- 2026-10-18T19:03Z heartbeat: full CI 39153086055 was cancelled. FH-a waits on scoped design run 39155524227 (dev 2e27b8db), queued. #2896 FH-5's macOS build 39154768808 is still running; #2894 FH-7 stays held.
- 2026-10-18T19:25Z heartbeat: #2896 FH-5's macOS build 39154768808 passed at 19:07Z, so it waits on the lane's merge. #2894 FH-7 stays held. Scoped design run 39155524227 is in progress.
- 2026-10-18T19:44Z: #2896 FH-5 merged at 19:28Z, so I removed `no-fast-lane` from #2894 FH-7. Scoped design run 39155524227 (dev 2e27b8db) is green and contains #2870 and #2879, so I posted `Belt-Slice-Done: FH-a` on #1499. The FH-a critic panel (wf_48b462ba-016) is running.
- 2026-10-18T19:50Z: the FH-a critic panel confirmed 5 findings. #2938 is major: DesignHistory duplicates SuiteKernel's saved-state tracking. #2936, #2937, #2939 and #2940 are minor (alert clarity, prompt wording, a mutation gap). That puts files-history at 5 open findings, at the limit. Fix round 1 for FH-a is fix-batch wf_82aa48f8-7c9, with FH-7's and DE-9's files marked busy.
- 2026-10-18T20:03:36Z heartbeat: #2894 (FH-7) awaiting lane merge; FH-b slice-done waits on a green design run containing #2896 and #2894. Fix round 1 (wok9a3u9f) running.
- 2026-10-18T20:24:54Z #2894 (FH-7) merged as 237bc5af: all FH-b PRs are on dev. FH-b slice-done waits on full CI 39162498756 (b1526f3e, contains it), pending.
- 2026-10-18T20:30:55Z FH-a fix round 1 done: #2975 (bad-file alert wording; 3/3), #2967 (LiveFiling width boundary; 7/7), #2968 (one UnsavedPrompt in SuiteKernel; 5/5, 8/8). #2968 edits PhotoModel and FlareApp to use the shared prompt: accepted under lead.md rule 20 (extract to the shared module, both apps use it). FlareApp now imports SuiteKernel transitively; the lane's macOS build-only run checks that before merge.
- Decision: #2938 (DesignHistory reimplements SuiteKernel saved-state) was deferred by the fixer (it shares DesignHistory.swift with #2968). It goes in the next fix batch once #2968 merges; that is #2938's first round. The same batch also updates the J16 row in docs/blueprints/design.md (line 343) to #2975's new alert strings, now that FH-7 has released that file.
- 2026-10-18T21:11:23Z heartbeat: full CI 39164756292 still pending (FH-b). #2975 (#2936 #2937) and #2967 (#2940) merged. #2968 at dbf56fca waits on the lane macOS build.
- 2026-10-18T21:33:10Z heartbeat: full CI 39164756292 was cancelled. FH-b now waits on full 39167964719 or scoped design 39167807664 (both at dev b40c77f6). #2968 is mergeable and waiting on its macOS build.
- 2026-10-18T21:56:05Z heartbeat: #2968 macOS build 39166101762 failed in Tests/AppSnapshotTests/PhotoZoomSweepTests.swift (cannot find TileCanvasView). The test is from #2942, not this PR, and #2990 fixed it on dev. Merged dev into #2968 (f0653e21) to carry the fix. Full CI 39167964719 was cancelled; FH-b waits on 39169434591 or scoped design 39167807664.
- 2026-10-18T22:18:50Z: #2968 (fixes #2939) merged as 76789931. Started fix-batch wf_be705683-751 on #2938 (its round 1); the fixer also updates J16 in docs/blueprints/design.md to #2975's strings. FH-b waits on scoped design 39167807664 (running) or full 39171061138.
- 2026-10-18T22:41:39Z heartbeat: FH-b waits on scoped design 39167807664 (contains 237bc5af), still running; full 39171061138 cancelled, 39171756438 queued. #2938 fixer is still working (local commit ec236735, no PR yet).
- 2026-10-18T23:06:55Z: fix-batch wf_be705683-751 opened #3022 (fixes #2938): Design history and saved marker on the kernel History. I added the J16 row update (docs/blueprints/design.md) the fixer missed, reran `scripts/ci --changed` (CI: PASS), stripped the footer, and moved Head to 3760d5cd. 10 files, about 328 lines.
- 2026-10-18T23:07:59Z heartbeat: scoped design 39167807664 does not count. Its macOS (design) job failed: snapshot tests could not compile `TileCanvasView` at b40c77f6, which predates #2990, and the UI journeys failed too. FH-b now waits on scoped design 39173700610 (46f6ce21, queued). #3022 is open and waits on the lane macOS build.
- 2026-10-18T23:29:58Z heartbeat: FH-b waits on scoped design 39173700610 (46f6ce21), in progress; full 39173775025 was cancelled, and 39176304199 (398ea5d4) is pending. The lane macOS build 39175654043 for #3022 at 3760d5cd is in progress.
- 2026-10-18T23:53:06Z: #3022 (fixes #2938) merged as b3283d3b. FH-a round 1 is done and no findings are open for files-history. FH-b waits on scoped design 39173700610: its design job is in progress. Full runs 39176304199 and 39177282982 were cancelled, and 39177967096 is pending.
- 2026-10-19T00:17:39Z heartbeat: scoped design 39173700610 macOS job red, so FH-b isn't slice-done. J16 fails the contrast audit on the bad-file alert's empty message label (from #2975). Filed finding #3052 and started FH-a fix round 2 (last), fix-batch wf_cfa1c00a-481. The other failures (stroke-add, text, arrange, perf) are outside FH files. Next: 39178639545, 39178441058.
- 2026-10-19T00:28:21Z FH-a round 2 fix PR #3057 (head 8d2fc81c, fast-lane) splits the bad-file alert into a title and a message (Fixes #3052). Footer stripped. The lane's macOS build is pending.
- 2026-10-19T00:39:17Z heartbeat: scoped design 39178639545 is still running and lacks #3057. Full run 39178441058 was cancelled. #3057 is open, waiting on the lane's macOS build. No green design job yet.
- 2026-10-19T01:01:41Z heartbeat: scoped design 39178639545 macOS job red. J16 is red on contrast; the fix is #3057, still waiting on the lane's macOS build. P4 says "no window opened" on the first -SuitePerfProbe launch, before any FH code runs. The scrub and canvas perf journeys fail the same way, so the cause is shared and not ours. J13 and J14 passed. The other red journeys (shell, layout, text, style, every-control, feedback, whole points, main) are outside FH files. Next: 39182410909, full 39183169319.
- 2026-10-19T01:24:38Z #3057 merged as d1abaef0 and closed #3052. FH-a has used its 2 fix rounds, and 0 findings are open. Runs 39182410909 (scoped design, 7ccb643d) and 39184285016 (full, 124fe38c) predate it, so J16 can't pass there. FH-b needs a green design job. Waiting for the next design run.
- 2026-10-19T01:46:15Z heartbeat: scoped design 39182410909 still running; full 39186699154 (ed0fed9e, contains d1abaef0) pending; earlier fulls cancelled. DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T02:08:30Z heartbeat: scoped design 39182410909 red on 7ccb643d (pre-#3057). J16 failed with the alert contrast that d1abaef0 fixes; every other failure is in the known non-FH/DE set. Full 39186699154 cancelled. Waiting on scoped design 39187798386 (0cb8bb88) and full 39188162085 (17dc84c7). DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T02:29:30Z heartbeat: scoped design 39187798386 (0cb8bb88) still queued behind the macOS runner backlog; full 39188162085 (17dc84c7) pending. DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T02:51:46Z heartbeat: scoped design 39187798386 (0cb8bb88) macOS job in progress; full 39188162085 pending. DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T03:15Z heartbeat: scoped design 39187798386 (0cb8bb88) red; J16 now passes; every failure is in the known non-FH/DE set (P4 is the shared perf-probe 'no window opened'); full 39188162085 cancelled; waiting on scoped design 39193348540 and full 39192572958 (cc14022e, queued); DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T03:36Z heartbeat: scoped design 39193348540 and full 39192572958 (cc14022e) still queued on the macOS runner (full's Linux green); no newer design run; no open dev-red; DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T03:58Z heartbeat: scoped design 39193348540 (cc14022e) macOS job running since 03:50Z; full 39192572958 still queued; newer full 39196649963 (7acc00bf) pending; no open dev-red; DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T04:23Z heartbeat: scoped design 39193348540 (cc14022e) macOS red; J13 J14 J16 pass; P4 finding #3020 is ours (PerfCanvas and PerfScrub get a window on the same args, only P4 doesn't), fix round 1 for FH-b started (fix-batch wf_e18c693d-8a5); slice-done held by other lines' red journeys, raised on #1499.
