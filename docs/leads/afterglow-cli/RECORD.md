# afterglow-cli lead record

Issue: #2998 · Packet: docs/blueprints/suite/features/afterglow-cli.md
Run: act-1a1543c761a-p4tj (resumed from act-1a1514ffe22-lvmw) · Session: cloud lead (line:suite, with afterglow-mcp #3000) · Started: 2026-10-18T23:21Z
Stage: 4 done
Base: 6e70826be59e092e59269605cfdfbce93c4a2bbe (origin/dev)
Next: none. Every slice is done; Belt-Contact-Sheet posted 21:14Z (run 39292755765) and the supervisor closed #2998.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CL-a | targets, executable, stubs, FakeIO, app registry | CL-1, CL-2 | LJ0 | – (CL-2: command-catalog CC-a, cross-line) | false | 0 | building (CL-1 merged) | – | – |
| CL-args | strict single-shot forms, one JSON object, sysexits, no overwrite | CL-3, CL-4, CL-5 | LJ1 | CL-a | false | 0 | waiting | – | – |
| CL-batch | `afterglow run` scripts | CL-6, CL-7 | LJ2 | CL-a | false | 0 | waiting | – | – |
| CL-jobs | real-jobs harness on Linux CI | CL-8, CL-9 | LJ3 | CL-a | false | 0 | waiting | – | – |
| CL-z | spawned binary, docs/cli.md, built | CL-10, CL-11 | LJ4 | every slice above | false | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CL-1 | CL-a | 1 | targets, main.swift, CLI router stub, `--version` live, C4 container + cli-runner | Package.swift, scripts/test-scope, Sources/AfterGlowCLI/main.swift, Sources/AfterGlowCLICore/CLI.swift, Tests/AfterGlowCLITests/CLIShapeTests.swift, docs/c4/parts/creative-apps/afterglow-cli/container.json, docs/c4/parts/creative-apps/afterglow-cli/cli-runner.json | CLIShapeTests (LJ0) | #3037 | merged 0487e28 |
| CL-2 | CL-a | 2 | CLIIO/FakeIO, HeadlessApp/Session, Apps, ScriptRunner/RealJobs/MCPServer stubs | Sources/AfterGlowCLICore/{CLIIO,Apps,ScriptRunner,RealJobs}.swift, Sources/AfterGlowCLICore/MCP/MCPServer.swift, Tests/AfterGlowCLITests/CLIStubTests.swift | CLIStubTests | – | waits on CC-2 #3074 |
| CL-3 | CL-args | 3 | CLIArgsTests + CLIFileSafetyTests, disabled | Tests/AfterGlowCLITests/CLIArgsTests.swift, CLIFileSafetyTests.swift, Golden/ | exists, disabled | – | waiting |
| CL-6 | CL-batch | 3 | BatchTests + fixtures, disabled | Tests/AfterGlowCLITests/BatchTests.swift, Fixtures/Batch/ | exists, disabled | – | waiting |
| CL-8 | CL-jobs | 3 | RealJobsTests + fake jobs + broken fixture, disabled | Tests/AfterGlowCLITests/RealJobsTests.swift, Tests/RealJobs/fake/, Fixtures/RealJobsBroken/ | exists, disabled | – | waiting |
| CL-4 | CL-args | 4 | parser, router, output | CLI.swift, Arguments.swift, Output.swift, mutations Arguments plan, CLIArgsTests.swift | CLIArgsTests | – | waiting |
| CL-5 | CL-args | 4 | LiveIO | LiveIO.swift, mutations LiveIO plan, CLIFileSafetyTests.swift | CLIFileSafetyTests | – | waiting |
| CL-7 | CL-batch | 4 | Script + ScriptRunner bodies, cli-batch C4 | Script.swift, ScriptRunner.swift, mutations ScriptRunner plan, BatchTests.swift, cli-batch.json | BatchTests | – | waiting |
| CL-9 | CL-jobs | 4 | RealJobs body, cli-jobs C4 | RealJobs.swift, mutations RealJobs plan, RealJobsTests.swift, cli-jobs.json | RealJobsTests | – | waiting |
| CL-10 | CL-z | 5 | spawned binary journey | Tests/AfterGlowCLITests/CLIBinaryTests.swift | CLIBinaryTests | – | waiting |
| CL-11 | CL-z | 6 | docs/cli.md, status built, feature-done | docs/cli.md, afterglow-cli.wave.json | waves check, c4 check | – | waiting |

Wave independence: wave 1 CL-1 alone. Wave 2 CL-2 alone (waits on CL-1 for the targets, and on CC-a for HeadlessDocument, CommandEnvelope, CatalogError). Wave 3 CL-3, CL-6, CL-8 independent (each waits on CL-2's stubs). Wave 4 CL-4 (CL-3), CL-5 (CL-3), CL-7 (CL-6), CL-9 (CL-8), independent of each other. Wave 5 CL-10 (CL-4, CL-5, CL-7: runs their code from the binary). Wave 6 CL-11 (CL-9, CL-10: final prose).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs base `dev`, not `main`: CLAUDE.md and the lane only take `dev` (the lane retargets a fast-lane PR opened against main); the brief's "base main" read as the integration branch it verified.
- CL-1 starts now although the packet lists CC-a for "everything": CL-1 declares only targets, the router stub and `--version`, and calls no Commands type. CL-2 does (HeadlessDocument, CommandEnvelope, CatalogError, BatchReport, ExportedFile), so it waits on #2996 CC-a.
- CL-1 is a supervisor merge (protected Package.swift, scripts/test-scope): the PR carries Fast-Check and waits for the supervisor.
- No slice is UI (`ui_slice: none`), so no critic panel needs screens; reviews of Linux-only slices run as code reviews only when findings are plausible.

## Open
- command-catalog #2996 CC-a: CC-1 merged (#3056); CC-2 open as #3074. CL-2 needs CC-2's five <X>Headless types and the fake for `Apps.all`, so it holds CL-2, every slice after CL-a, and all of afterglow-mcp.

## CL-3 handoff notes (PR #3118, head 8f1f4af)
- CLIArgsTests disabled "waits on CL-4"; CLIFileSafetyTests disabled "waits on CL-5" (needs a liveIO() helper filled by CL-5).
- Output shapes fixed by tests: error kinds usage/data/unavailable/failed/exists/io; reply keys commands, command, summary, output, outputs, undoStep; unavailable message is the app's own text.
- CL-4 must route over Apps.all + [Apps.fake] (tests call CLI.run(_:io:)); command-editing tests also need CC-7 (catalog run body).
- CL-4 enabling breaks CLIShapeTests.everyOtherFormIsAStubThatNamesItsSlice (list-apps, --help, --version --json no longer stubs): CL-4 must update that test.
- Fake catalog has 8 commands (incl. edit.undo/edit.redo), not 6.

## CL-8 handoff notes (PR #3123, head 788e8b8)
- RealJobsTests (LJ3) disabled "waits on CL-9"; RealJobsLayoutTests (2, file-only) enabled.
- Assumed report: RealJobs.check prints one JSON object: "ok": true on pass; "ok": false + non-zero exit on failure; "skipped": "<reason>" + exit 0 on skip ("macOS-only: <why>" or "waits on image-codecs").
- Fixtures export with "format": "json"; output extension comes from the format. Broken fixture fake/wrong-sha differs in the last hex digit (catches .fullDigest).
- The pixel-expectation test needs updating once image-codecs is bumped in.

## CL-6 handoff notes (PR #3124, head 458e9ec)
- BatchTests (16) disabled "waits on CL-7"; also need CC-7 runBatch. Fixtures in Tests/AfterGlowCLITests/Fixtures/Batch/, loaded via #filePath into FakeIO.
- Fixed choices for CL-7: any refused input in a run exits 70 and the report still prints; output.format equal to the app's native extension ("fake") saves natively; report paths are CLIIO.read-style (batch/out/beach-small.fake).
- Exit codes: version != 1 → 65; unknown app/step → 64 naming it, nothing written; missing script 74, malformed 65; empty pattern 65; collisions 73 unless force.
- hundredInputsWithinBudget only prints; ask supervisor if it should join Tests/perf-suites.txt.

## CL-5 handoff notes (PR #3149, head e45a0da)
- LiveIO: regular-file reads through symlinks, 2 GiB cap (LiveIO(readLimit:)); writes via hidden temp + rename(2), no-replace via link(2); globs per segment, files only, sorted, dot-files only when the segment starts with '.'. Mutate 6/6 AfterGlowCLICore.LiveIO.
- CLIFileSafetyTests gated `.enabled(if: routed)` (routed = CLI.run(["list-apps"]) != 69): they turn on by themselves when CL-4 lands.
- For CL-10: Sources/AfterGlowCLI/main.swift still calls CLI.run(args, out:err:); must become CLI.run(args, io: LiveIO()) or the binary never touches disk. Router: every write error except CLIIOError.exists → 74.
- Public HeadlessApp.session(reading:io:) lives in LiveIO.swift. #3149 edits cli-runner.json `description` (possible key conflict with CL-4).

## CL-4 handoff notes (PR #3151, head 701ca29)
- Router CLI.run(_:apps:io:) over CLI.registry = Apps.all + [Apps.fake]; files only via CLIIO. Order: exists check (73) → availability (69) → run → write. Write errors except CLIIOError.exists → 74. Mutate 5/5 AfterGlowCLICore.Arguments.
- main.swift unchanged: still CLI.run(args, out:err:) which now runs over a fresh FakeIO → CL-10 must switch it to CLI.run(args, io: LiveIO()).
- run and mcp still route to ScriptRunner / MCPServer stubs (69).
- Branched before CC-7 #3120 merged: command runs exit 69 "notBuilt" on its base. Four CLIArgsTests disabled "waits on CC-7" (everyCommandFormAnswersWithOneObject, catalogExitCodes, goldenRunOK, lj1FakeSession). With CC-7 now on dev, a follow-up (folded into CL-10 or a small fixer once #3149 and #3151 merge) turns these on and checks the CC-7-dependent CLIFileSafetyTests cases (forceReplacesWhole, inPlaceIsExplicit success, atomicWrite rect.add, directoryIs74 rect.add), which #3149's `routed` gate enables automatically.

## CL-7 handoff notes (PR #3154, head b01b9a1)
- ScriptRunner.run(_:apps:dryRun:force:io:) keeps CL-2's signature; Script.swift new (format, checks 64/65, name template). 16 BatchTests on, fuzz 1000 → 64/65 only. Mutate 7/7 AfterGlowCLICore.ScriptRunner. 6 files +267/-31.
- Choices: atomic defaults true; input open failure = refused → 70; non-native format must export exactly one file; dry run prints {"ok":true,"dryRun":true,"inputs":[...]} and still refuses collisions 73.
- Paths resolve against the script's folder as given; report prints paths as CLIIO.read takes them.
- Touched CLIStubTests (removed `run` row from everyStubExits69NamingItsSlice) — possible overlap with #3151; lane merge drivers / needs-rebase will tell.
- CL-10 must: route `run <script> [--dry-run] [--force]` to ScriptRunner.run in CL-4's router (CLIShapeTests still expects "CL-batch" until then); main.swift → CLI.run(args, io: LiveIO()); enable the "waits on CC-7" CLIArgsTests.
- hundredInputsWithinBudget is print-only (0.13s/103 inputs vs 2s); ask supervisor whether it joins Tests/perf-suites.txt.

## CL-9 status (builder holding, no PR yet)
- Built and committed locally; gate fails on dev alone because RealJobs runs jobs through ScriptRunner (still the 69 stub until CL-7 #3154 merges). With #3154 merged on a scratch branch: scripts/ci PASS, mutate 6/6, fake sha256 fixtures match real runner output. Builder is watching #3154 and opens the PR after it merges.
- 5 files, 232 lines; pure-Swift SHA-256 in RealJobs.swift (none in repo/core). Also touches CLIStubTests.swift (drops "jobs" case) — same lines as CL-4/CL-7 edits → expect needs-rebase; resolution: drop both "run" and "jobs" cases.
- Report shapes: pass {"ok":true,"job","checked"}; fail {"ok":false,"job","failures":[{path,why}]} exit 70; skip {"job","skipped"} exit 0 (no ok key). Pixel expectations skipped "waits on image-codecs (creative-core#562)". force:true on runs.
- CL-11 docs/cli.md: describe real-jobs format (layout, expect per path: sha256/json/pixels{tolerance,reference}, platforms, why), the three report shapes + exit codes, pixel skip until image-codecs bump.

## #3154 rebase fix (head a53cfee)
- Merged dev into CL-7 (merge commit, no force). CL-4's router already routes `run` → ScriptRunner.run, so `run` is real once #3154 merges. Removed `run`+CL-4 `cli` rows from CLIStubTests.everyStubExits69NamingItsSlice and the `run` row from CLIShapeTests. Full ci PASS (4012), mutate 7/7, 7 files +271/-36.
- Remaining stub rows: `jobs` (RealJobs.check — CL-9 removes it) and `mcp` (MC slices). When mcp is real, delete CLIShapeTests.everyOtherFormIsAStubThatNamesItsSlice.
- CL-10 no longer needs to route `run`: only main.swift → LiveIO and the waits-on-CC-7 tests.

## 07:44Z heartbeat
- #3154 still open, clean, macOS build queued (run 39213749046). No dev merges of ours.
- Not waiting: CL-10 builder dispatched stacked on lead/afterglow-cli-CL-7; it pushes lead/afterglow-cli-CL-10 and holds its PR until #3154 merges.

## 08:05Z heartbeat
- #3154 still open, clean; its lane macOS build has been queued since 07:05Z (no macOS runner). For the supervisor: our slices are blocked only on macOS runner capacity, not on code.

## CL-10 built (held)
- Branch lead/afterglow-cli-CL-10 head d69d13442a1b638a4776f84bd95623216f8b792a, 8 files +174/-17 vs CL-7. ci --changed PASS; mutate AfterGlowCLI.main 3/3, AfterGlowCLICore.LiveIO 7/7.
- main.swift -> CLI.run(args, io: LiveIO()); CLIBinaryTests (LJ4, spawned binary; --version 13-19 ms vs 150 ms); four waits-on-CC-7 CLIArgsTests on.
- LJ4 found a real bug: LiveIO.write did not create missing parent folders (batch output dir -> 74 on real disk). Fixed (createDirectory withIntermediateDirectories) + liveWriteMakesFolders test + mutation.
- @Suite failed to compile in this target; tests use per-test .enabled(if:) traits.
- PR held until #3154 merges; then merge dev in, rerun ci, open PR (title "feat(suite): afterglow binary runs on the real disk (CL-10)", Slice: CL-z).

## 08:27Z heartbeat
- #3154 CL-7 still in lane (macOS build queued since 07:05Z). CL-9 and CL-10 held on it.

## 2026-10-19T08:48Z: heartbeat
- #3154 CL-7 is still waiting for its macOS build: run 39213749046 has been queued since 07:05Z. CL-9 (35ee7e6) and CL-10 (d69d134) ship once it merges. We are blocked only on macOS runner capacity.

## 2026-10-19T09:11Z: heartbeat
- #3154 is clean but its macOS build (run 39213749046) is still queued, with 27 CI runs waiting. Another branch, fix/cli-liveio-symlink-type, is building on macOS; it may touch LiveIO, which CL-10 also changes, so check for a conflict when shipping CL-10.

## 2026-10-19T09:26Z: CL-7 #3154 merged (09:22Z)
- Dispatching a shipper for CL-9 (rebuilt on dev from 35ee7e6, jobs stub row dropped, Slice: CL-jobs) and then CL-10 (d69d134, Slice: CL-z).

## 2026-10-19T09:34Z: heartbeat
- Shipper is running: CL-9 (merge dev in, drop the jobs row, PR with Slice: CL-jobs), then CL-10 (merge dev in, PR with Slice: CL-z).

## 2026-10-19T09:40Z: CL-9 and CL-10 PRs open
- CL-9: #3209, head c8c1f238bbc34de54adcf4504f4c530e6b83764e, Slice: CL-jobs.
  - 5 files, +215/−19. Gate passed, mutate 6/6.
  - The jobs stub row is gone; only the mcp row is left.
- CL-10: #3211, head b1b309c9326b44d5f793f2e9ffb6a108ceaa220e, Slice: CL-z.
  - 8 files, +174/−17. Gate passed, mutate 3/3 and 7/7.
  - The symlink fix from #3193 merged cleanly with CL-10's createDirectory.
- Four RealJobsTests skip on CL-10's branch until CL-9 is on dev.
- Next: CL-11 (docs/cli.md, wave.json status, feature-done), built on both branches merged, PR held until both merge.

## 2026-10-19T09:49Z: CL-11 pushed, PR held until #3209 and #3211 merge
- Branch: lead/afterglow-cli-CL-11 @3a291b22722b32f3b462ce4552ef0f41d64bc6eb. It is dev with CL-9 and CL-10 merged in, plus one docs commit.
- Changes:
  - docs/cli.md, +263;
  - afterglow-cli.wave.json status set to built.
- Gate passed. The builder ran every example in the guide through the built binary.
- PR plan: title "docs(suite): afterglow CLI guide (CL-11)", labels fast-lane and feature-done, Refs #2998, Slice: CL-z. Open it after a fresh merge of dev once #3209 and #3211 are in.
- Where the packet and the code disagree (the doc follows the code); these are inputs for the critics:
  - fake is registered in the shipped binary;
  - fake list-commands lists 8 ids, not 6 (edit.undo and edit.redo);
  - new accepts --force;
  - atomic defaults to true;
  - a job whose script run fails exits with the run's code, not 70;
  - pixel tolerance and reference aren't checked yet;
  - every <X>Headless is still a stub (empty catalogs);
  - mcp still exits 69 until MC-15.

## 2026-10-19T09:55Z: heartbeat
- No merges since the last heartbeat. #3200, #3202, #3203, #3209 and #3211 are clean and fast-lane, waiting on the lane's macOS build runs. 30 runs are queued repo-wide.
- None of the open `finding` issues are from this run's critics. The afterglow journey ones date from 2026-10-17.
- The MC-11 builder is still running. CL-11 is held (see above).

## 2026-10-19T10:18Z: heartbeat
- No merges yet. All five lane PRs are clean, and their macOS build runs are still queued (33 queued repo-wide).
- The MC-10 and MC-14 builders are running. MC-11 and CL-11 are held.

## 2026-10-19T10:39Z: heartbeat
- No merges yet. The macOS build for MC-12 (#3203) is now running (run 39225689887). The other lane builds are still queued (28 queued repo-wide).
- The MC-15 docs builder is running. Every other slice is built and held.

## 2026-10-19T11:01Z: heartbeat
- #3209 and #3211 are still waiting on their macOS builds. CL-11 is held.

### 11:24Z: heartbeat
- #3209 CL-9 and #3211 CL-10 are clean and waiting for their macOS builds (the queue is backed up). CL-11 3a291b2 is held until both merge.

## 2026-10-19T15:06Z: CL-10 merged, CL-11 PR #3281 open
- CL-10 #3211 merged about 15:00Z.
- Merged dev into CL-11 with no conflicts. The diff is docs only, +264/−1. scripts/ci --changed printed CI: PASS. Pushed c3447624.
- Opened #3281 with the labels fast-lane and feature-done (Slice: CL-z, Refs #2998).

### 15:49Z: heartbeat
- CL-11 #3281 is clean and docs only, waiting on the lane's Linux check.

### 16:07Z: heartbeat
- CL-11 #3281 is clean. The lane's own runs have been queued since 15:53Z, so no Linux check has been dispatched yet.

### 16:26Z: heartbeat
- No merges yet. Two lane sweeps are in progress (from 15:53Z and 16:05Z), 16 runs are queued repo-wide, and the dev CI run has been going since 14:25Z. Every open PR is clean.

### 16:44Z: heartbeat
- The macOS builds for MC-13 0b414652, MC-4 b8bc58ec and MC-6 c0cf1cfb succeeded. CL-11 is docs only. All four are ready and wait for the lane sweep running on dev since 16:28Z.

### 17:02Z: heartbeat
- Lane batch lane/batch-20261019170158 has been in its Linux check since 17:02Z. Our four PRs are clean and ready. No dev-red issue is open.

## 17:16Z: CL-11 merged, CL-z built
- #3281 squash-merged as 8f405311 at 17:16Z. It carried feature-done, so the lane should dispatch a full CI run on dev.
- Waiting for a successful ci.yml run that contains 8f405311, then the Slice-Done and Contact-Sheet comments.

## 21:14Z: CL-z done, feature done
- Posted Belt-Slice-Done: CL-z and Belt-Contact-Sheet on scoped suite run 39292755765, which contains 8f405311. The supervisor closed #2998 at 21:15Z.
