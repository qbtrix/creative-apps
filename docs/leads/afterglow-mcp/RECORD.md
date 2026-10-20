# afterglow-mcp lead record

Issue: #3000 · Packet: docs/blueprints/suite/features/afterglow-mcp.md
Run: act-1a157b204fb-js9h (resumed from act-1a1543c761a-p4tj, act-1a1514ffe22-lvmw) · Session: cloud lead (line:suite) · Started: 2026-10-18T23:21Z
Stage: done
Base: b3011ab9dc5579023722e79f83254e6e2520e612 (origin/main; branch rebuilt on main with only this folder)
Next: beta-hardening lane verifies MC-live-ui (Mac-Finish-Wanted posted); nothing left for the lead.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| MC-a | MCP types, versions, tool/session stubs, test client | MC-1, MC-2 | MJ0 | afterglow-cli:CL-a | false | 0 | done | 39331727327 (scoped: suite, bd10d93a) | – |
| MC-proto | JSON-RPC framing, discover, initialize, errors | MC-3, MC-4 | MJ1 | MC-a | false | 0 | done (Belt) | – | – |
| MC-tools | tools/list from the catalogs | MC-5, MC-6 | MJ2 | MC-a | false | 0 | done (Belt) | – | – |
| MC-call | tools/call over handles under roots | MC-7, MC-8 | MJ3 | MC-a | false | 0 | done (Belt) | – | – |
| MC-live-wire | (macOS) live socket, grants, bridge | MC-9, MC-10, MC-11 | MJ4 | MC-call | false | 0 | done (Belt) | – | – |
| MC-live-ui | (macOS) approval sheet, chip, AI Access list | MC-12, MC-13 | testAIAccessApproval | MC-a | true | 1 | done | 39292755765 | wanted |
| MC-z | spawned binary, docs, built | MC-14, MC-15 | MJ5 | every slice above; afterglow-cli:CL-z | false | 0 | done (Belt) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| MC-1 | MC-a | 1 | contract stubs, FakeAIAccess, cli-mcp C4 | Sources/AfterGlowCLICore/MCP/*, MCPShapeTests.swift, cli-mcp.json, SuiteModel/AIAccess/* | MCPShapeTests | #3125 | merged 69cf6f6d |
| MC-2 | MC-a | 2 | MCPTestClient | MCPTestClient.swift, MCPClientTests.swift | MCPClientTests | #3200 | merged 3e9fbe1c |
| MC-9 | MC-live-wire | 2 | AIAccessGrants body | AIAccessGrants.swift, AIAccessGrantsTests.swift | AIAccessGrantsTests | #3202 | merged 95478401 |
| MC-12 | MC-live-ui | 2 | sheet, chip, Window > AI Access… | AIAccessSheet.swift, AIAccessChip.swift, AIAccessCommands.swift | snapshots | #3203 | merged 955f02d0 |
| MC-3 | MC-proto | 3 | MCPProtocolTests disabled | MCPProtocolTests.swift | exists, disabled | #3237 | merged 79591c4f |
| MC-5 | MC-tools | 3 | MCPToolsTests disabled | MCPToolsTests.swift | exists, disabled | #3238 | merged 22cd834e |
| MC-7 | MC-call | 3 | MCPCallTests disabled | MCPCallTests.swift | exists, disabled | #3239 | merged 6e70826b |
| MC-13 | MC-live-ui | 3 | render budget, journey on | RenderBudgetAIAccessTests.swift, journey | budget, journey | #3272 | merged 731916bf |
| MC-4 | MC-proto | 4 | JSONRPC + server dispatch | JSONRPC.swift, MCPServer.swift | MCPProtocolTests | #3283 | merged f0520a67 |
| MC-6 | MC-tools | 4 | MCPTools body | MCPTools.swift | MCPToolsTests | #3284 | merged 1f4500f1 |
| MC-8 | MC-call | 5 | MCPSessions body, tools/call | MCPSessions.swift | MCPCallTests | #3320 | merged cd44f3ee |
| MC-10 | MC-live-wire | 6 | LiveCommandChannel (macOS) | LiveCommandChannel.swift, SuiteAppModifier.swift | macOS build | #3383 | merged 15b4e591 |
| MC-11 | MC-live-wire | 6 | LiveBridge (macOS) | LiveBridge.swift, LiveBridgeTests.swift | LiveBridgeTests | #3368 | merged e497d903 |
| MC-14 | MC-z | 6 | spawned binary MJ5 | MCPBinaryTests.swift | MCPBinaryTests | #3369 | merged f9b8ea4f |
| MC-15 | MC-z | 7 | docs/cli.md MCP section, built | docs/cli.md, afterglow-mcp.wave.json | waves/c4 check | #3395 | merged 13cf5dce |
| fix-3327 | MC-live-ui | r1 | chip accessibility label | AIAccessChip, journey | journey | #3362 | merged bb4695bc |
| fix-copy | MC-live-ui | r1 | approval sheet copy (#3346-#3349) | AIAccessPrompt | AIAccessPromptTests | #3363 | merged bd10d93a |
| fix-3350 | MC-live-ui | r1 | re-ask after Stop | FakeAIAccess, journey | journey | #3364 | merged 92c83969 |

Wave independence follows the packet's Build waves: MC-1 alone; MC-2, MC-9, MC-12 independent (each on MC-1); MC-3, MC-5, MC-7 (MC-2), MC-13 (MC-12); MC-4 (MC-3), MC-6 (MC-5); MC-8 (MC-7, MC-4: tools/call dispatch); MC-10 (MC-9, MC-8, switching), MC-11 (MC-8), MC-14 (MC-4, MC-6, MC-8); MC-15 final.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs base `dev` (CLAUDE.md; the lane retargets main to dev).
- MC-1 can't start before CL-a: it fills CL-2's `MCPServer.swift` stub and uses `HeadlessApp` and `CLIIO`.

## Open
- Blocked on afterglow-cli:CL-a: CL-1 merged (#3037); CL-2 waits on command-catalog CC-2 #3074 (open).

## MC-1 handoff notes (PR #3125, head e7a27b3)
- Real: MCPVersions (supported 2026-07-28, 2025-11-25, 2025-06-18 newest first; negotiate → nil on unknown), JSONRPC.reply, MCPTools.name. FakeAIAccess runs request/decide/stop/revoke.
- Stubs naming their task: parse/handle (MC-4), list/route (MC-6), call (MC-8), AIAccessGrants (MC-9); serve still exits 69.
- Deviations: AIAccessGrants.allows takes kind: String (raw CommandKind value; SuiteModel can't import SuiteKernel); serve keeps CL-2's serve(_:apps:io:); RPCRequest is Hashable; new C4 part suite-model/suite-ai-access.json.

## 07:44Z heartbeat
- #3125 still open, clean; macOS build queued since 04:39Z (run 39200599134), 3h.
- Not waiting: MC-2 and MC-9 builders dispatched stacked on lead/afterglow-mcp-MC-1; PRs held until #3125 merges. MC-12 waits (UI, macOS-only).

## MC-2 built (held)
- Branch lead/afterglow-mcp-MC-2 head 63a43ed8815b83c097c3dd21d8a08a770ede3fe4, 2 test files +235, ci --changed PASS (first run failed only on Design/Library timing budgets under load ~20; rerun clean).
- Client accepts null id only on an error reply. theRealServerAnswersEachEraOnceWithItsID disabled until MC-4.
- PR held until #3125 merges; then merge dev in, rerun ci, open PR (title "test(suite): afterglow MCP in-process test client (MC-2)", Slice: MC-a).

## 08:05Z heartbeat
- #3125 still open, clean; its lane macOS build has been queued since 04:39Z (no macOS runner). For the supervisor: our slices are blocked only on macOS runner capacity, not on code.

## MC-9 built (held)
- Branch lead/afterglow-mcp-MC-9 head fffb92dd29d79ed584bbffa4060ded51c4ffd606, 5 files +227/-11. ci --changed PASS; mutate SuiteModel.AIAccessGrants 10/10.
- Deny is remembered per client per app (allows -> false). Grants stored in SuitePreferences.perApp[app]["aiAccess.<client>"]; save throws .staleRevision, no retry.
- MCPShapeTests updated: FakeAIAccess deny leaves one entry; test renamed aFileCommandAsksAndTheFakeFlowConnectsAllowOnceUntilStop.
- Note for MC-12: FakeAIAccess still shows the approval sheet to a denied client (it connects only when allows == true); MC-12 may want a remembered deny to refuse without asking.
- PR held until #3125 merges; then merge dev in, rerun ci, open PR (title "feat(suite): AI access grants ask, allow, deny and revoke (MC-9)", Slice: MC-live-wire).

## 08:27Z heartbeat
- MC-1 #3125 merged to dev as 69cf6f6d. MC-a contract on dev.
- Dispatched: shipper for MC-2 and MC-9 (merge dev in, ci, push, open PRs); MC-12 builder (AI Access sheet, chip, Window menu; journey written skipped).

## 2026-10-19T08:45Z: MC-2 and MC-9 PRs open
- MC-2: #3200, head 59fa5ae4dae3859f3135637c7766eb838af55281. Gate passed.
- MC-9: #3202, head e21246847a1ea4ebf15563cf3ab2c0a999f0ef56. Gate passed on the third run; the first two each failed one timing-budget test that this PR doesn't touch (Library grid and Design snap), with machine load at about 16. mutate 10/10.
- Fixed the JSON merge driver, which pointed at a removed agent worktree. It is now set to the main checkout's scripts/merge-json.
- Next: MC-3, MC-5 and MC-7, stacked on MC-2 with their PRs held until it merges. MC-12 builder still running.

## 2026-10-19T08:46Z: MC-12 PR open, MC-3/5/7 builder dispatched
- MC-12: #3203, head 85376b8ccfe3549d647d22108c52af1bd3e27422. 12 files, 397 lines (at the cap). Gate passed, mutate 3/3. None of the SuiteUI or shell code has been compiled yet; the lane's macOS build is its first build.
- Snapshots: suite-ai-access-{sheet,chip,list,list-empty}-{light,dark}.png.
- Notes for MC-13:
  - Enable testAIAccessApproval.
  - Replace FakeAIAccess in AIAccessCenter with the live bridge.
  - Add "AI Access…" to the Window menu list in AfterGlowJourneyTests.
  - Only AfterGlow adds SuiteCommands for now.
- Builder dispatched for MC-3, MC-5 and MC-7, one after another, stacked on MC-2. Their PRs are held until #3200 merges.

## 2026-10-19T08:48Z: heartbeat
- #3200 MC-2, #3202 MC-9 and #3203 MC-12 are open in the lane and waiting for their macOS builds. The builder for MC-3, MC-5 and MC-7 (stacked on MC-2) is running.

## 2026-10-19T08:57Z: MC-3, MC-5 and MC-7 pushed, PRs held until #3200 merges
- MC-3: lead/afterglow-mcp-MC-3 @aa3838e6469e3f4ad143c6cc4dd99f8aca09b63f. MCPProtocolTests, +205, gate passed. Title: "test(suite): MCP protocol checks, disabled until MC-4 (MC-3)".
- MC-5: lead/afterglow-mcp-MC-5 @b629ccea65f66d55c8f5019a744cb8034f151284. MCPToolsTests, +189, gate passed. Title: "test(suite): MCP tool-list checks, disabled until MC-6 (MC-5)".
- MC-7: lead/afterglow-mcp-MC-7 @de89ccd2b936476987bbfc912baddc2d1a298adc. MCPCallTests, +261, gate passed. Title: "test(suite): MCP call checks, disabled until MC-8 (MC-7)".
- All three add tests only, so none has a mutation plan; those come with MC-4, MC-6 and MC-8. Every test is disabled until its build slice lands.
- Choices the tests make that the packet doesn't spell out:
  - unsupported version uses code -32602;
  - command output is {result, undoStep};
  - tool names follow id order, so the first command is fake.doc.export-json, not fake.rect.add as MJ2 says;
  - MJ3 doesn't say what relative paths resolve against;
  - a command with id open or new would collide with <app>.open / <app>.new.
- On macOS, MC-8 must resolve the root's own symlink (/tmp is /private/tmp).
- For the supervisor: MCPToolsTests.listWithinBudget and MCPCallTests.callOverhead should be added to Tests/perf-suites.txt.

## 2026-10-19T09:11Z: heartbeat
- #3200, #3202 and #3203 are clean, waiting for macOS builds. MC-3/5/7 are built and held. Builder running MC-4 then MC-6. MC-13 waits until that builder finishes.

## 2026-10-19T09:13Z: MC-4 and MC-6 pushed, PRs held
- MC-4: lead/afterglow-mcp-MC-4 @b3d1ed90c1c06f57bae391085369f54e2c5b7126, based on MC-3.
  - 11 files, +276/−64. Gate passed, mutate 4/4.
  - Title: "feat(afterglow): MCP protocol server over stdio".
  - Adds the JSON-RPC parser and MCPServer, and gives CLIIO a readLine().
  - LiveIO reads stdin and no longer buffers stdout.
  - Removes the mcp stub rows.
- MC-6: lead/afterglow-mcp-MC-6 @6ab5e483d5fb421e52f086195c0baa8862bc2453, based on MC-5.
  - 5 files, +118/−23. Gate passed, mutate 4/4.
  - Title: "feat(afterglow): MCP tool list and routing from the command catalogs".
- Conflicts to expect when merging:
  - MC-4 and MC-6 both change cli-mcp.json's description and the header of MCPShapeTests.swift; merge those by hand.
  - MC-4 also changes LiveIO.swift, which CL-10 (d69d134) changes too.
- MC-14: CL-10's main.swift switch to LiveIO is what lets afterglow mcp read stdin. MC-14 depends on CL-10 for that.
- Turn on later, once MC-4 and MC-6 are both merged:
  - toolsListThroughTheServerMatchesTheList;
  - a rate-limit test through tools/call.
- For the supervisor, perf list: also MCPToolsTests.listWithinBudget.
- Next: dispatch MC-8, based on a merge of MC-4 and MC-7.

## 2026-10-19T09:26Z: MC-8 pushed, PR held
- Branch: lead/afterglow-mcp-MC-8 @31668965891905c251f36ec212a4f558e6f55ab3, built on MC-4 with MC-7 and MC-6 merged in.
- Size: its own diff from merge c9160fc7 is 6 files, +237/−24.
- Gate passed (113 tests), mutate 6/6.
- Title: "feat(afterglow): MCP call sessions behind tools/call".
- Merged MC-6 because routing is needed for tools/call to reach the sessions. So MC-8 ships after MC-4, MC-6 and MC-7 all merge.
- Notes:
  - Relative paths resolve against the first root.
  - Imports Glibc/Darwin for realpath.
  - Fixed a runtime crash from duplicate dictionary keys in MC-7's pathsOutsideTheRootsAreRefused; that fix must ride with MC-8 or go into MC-7 before its PR.
  - callOverhead and listWithinBudget wait on perf-suites entries.

## 2026-10-19T09:34Z: heartbeat
- #3200, #3202 and #3203 are still waiting for macOS builds. MC-3, MC-4, MC-5, MC-6, MC-7 and MC-8 are built and held. MC-13 builder dispatched, stacked on MC-12.

## 2026-10-19T09:43Z: MC-13 pushed, PR held until #3203 merges
- Branch: lead/afterglow-mcp-MC-13 @f28576a21e60c98d9f4b34b5cb86f80b9cfef171, built on MC-12. 6 files, +112/−12. Gate passed on Linux; nothing new compiled there.
- Title: "test(suite): AI access render budget and the approval journey on (MC-13)".
- What it does:
  - Adds RenderBudgetAIAccessTests.
  - Turns on testAIAccessApproval.
  - Adds "AI Access…" to the Window menu literal.
  - request() takes an optional host window.
- The bridge stays on FakeAIAccess. MC-10 swaps in LiveCommandChannel and uses MC-9's grants.
- Risks for the first macOS run:
  - .titled on the harness window may move the drag coordinates.
  - First @testable import SuiteShell in AppSnapshotTests.
- For the supervisor: the sheet p95 ≤ 8 ms timing test needs a perf-suites entry.

## 2026-10-19T09:55Z: heartbeat
- No merges since the last heartbeat. #3200, #3202, #3203, #3209 and #3211 are clean and fast-lane, waiting on the lane's macOS build runs. 30 runs are queued repo-wide.
- None of the open `finding` issues are from this run's critics. The afterglow journey ones date from 2026-10-17.
- The MC-11 builder is still running. CL-11 is held (see above).

## 2026-10-19T10:09Z: MC-11 pushed, PR held until MC-8 merges
- Branch: lead/afterglow-mcp-MC-11 @8e22403946bcba4cfb80a3275cf9d6c65b5b1a1e, stacked on MC-8 @3166896 only.
- Size: 6 files, +386/−14 = 400, exactly at the cap.
- Gate and mutations: `scripts/ci --changed` passed (119 tests), and `scripts/mutate --plan AfterGlowCLICore.LiveBridge` caught 4 of 4.
- Planned PR title: "feat(afterglow): live bridge for afterglow mcp --live". Slice: MC-live-wire.
- The PR body must say context7 was out of quota. apple-docs was used for sockaddr_un, SO_NOSIGPIPE and the FileManager calls.
- What it does:
  - LiveBridge finds the `*.sock` files under Application Support/AfterGlow/live.
  - It lists each app's commands as `live.<app>.<id>` tools.
  - A call goes out as `live/run`; a -32010 reply becomes the approval-text tool error.
  - A dead socket is skipped, and `serve --live` exits 69 off macOS.
- The wire contract MC-10 must implement:
  - `live/describe {client}` returns `{app,title,commands}`.
  - `live/run {client,id,params}` returns `{result,undoStep?}`. Error -32010 means no grant.
  - Messages are NDJSON JSON-RPC on `<app>-<pid>.sock`, with a 120 s reply timeout.
- MC-15 must document: `--live`, the `live.<app>.<id>` tools and their `{params}` input, the approval text, the "In the open <Title> window:" prefix, and exit 69 off macOS.
- For the critics:
  - The socket code builds on Linux (only `local()` and `serve --live` are macOS-only), which departs from the packet's `#if os(macOS)`.
  - Request ids are always 1.
  - A client that never sends `initialize` shows as "MCP client".
  - No macOS test covers `--live`.
- When MC-8 merges: open its PR off dev (merge dev in, take dev's copies of MC-8's files, rerun ci). Watch the 400 cap after the merge.

## 2026-10-19T10:10Z: MC-10 and MC-14 builders started, both stacked
- MC-10 (MC-live-ui) builds on dev with MC-9 (#3202) and MC-11 (which carries MC-8) merged in. It goes to lead/afterglow-mcp-MC-10 with no PR; switching's SuiteAppModifier is already on dev.
- MC-14 (MC-z) builds on dev with MC-8 and CL-10 (#3211) merged in. It goes to lead/afterglow-mcp-MC-14 with no PR.

## 2026-10-19T10:18Z: heartbeat
- No merges yet. All five lane PRs are clean, and their macOS build runs are still queued (33 queued repo-wide).
- The MC-10 and MC-14 builders are running. MC-11 and CL-11 are held.

## 2026-10-19T10:25Z: MC-14 pushed, PR held until MC-8 and CL-10 merge
- Branch: lead/afterglow-mcp-MC-14 @6a2a9692c507a0368738047338bfb18f6d720d64. It is dev with MC-8 and CL-10 merged in, plus Tests/AfterGlowCLITests/MCPBinaryTests.swift (+190, 1 file).
- Gate passed on the first run.
- PR title: "test(afterglow): MCP journeys through the built binary (MC-14)". Slice: MC-z.
- The test runs MJ1 to MJ3 through the spawned binary in all three eras. Its reply lines must equal MCPServer.handle on the same journey, with nothing extra on stdout and nothing on stderr. Its failure condition was checked by planting an extra stdout line.
- No bugs found. Idle expiry isn't run through the binary (the limit is 3600 s with no flag); MCPCallTests covers it in process.
- **Watch:** MC-8 conflicts with dev in CLIStubTests and CLIShapeTests (dev's CL-7 made `run` real; MC-8 made `mcp` real). The resolution: the stubs left are `jobs` and `mcp --live` (69, names MC-11). Apply the same resolution when MC-8's PR merges dev in. MC-11 must then remove the `mcp --live` stub row.

## 2026-10-19T10:35Z: MC-10 pushed, PR held until MC-9 and MC-11 merge
- Branch: lead/afterglow-mcp-MC-10 @54c976a8733bb92d5042e970aa0f92c3f803ab5a, on a merge of MC-9 and MC-11 (17397a18).
- Size: 9 files, +389/−5 (394).
- Gate: `scripts/ci --changed` passed (4136 tests), and `scripts/mutate --plan SuiteModel.AIAccessAudit` caught 3 of 3.
- PR title: "feat(suite): live command channel in every app". Slice: MC-live-ui.
- What it adds:
  - LiveCommandChannel (SuiteShell, macOS only), on the same wire as MC-11's bridge. The socket folder is 0700 and the socket 0600; stale sockets are removed at start.
  - getpeereid limits peers to the same user.
  - A grant check before each run; "allow once" lasts only for that connection.
  - The audit decision and the log line live in SuiteModel, tested on Linux.
- **Risks:**
  - Nothing in SuiteShell has been compiled yet; the PR's macOS build is its first compile.
  - project.yml gains a SuiteKernel dependency for SuiteShell.
  - Constructs only macOS checks: @Observable on a @MainActor class, `throws(CatalogError)`, and the C calls pollfd, getpeereid and sun_len.
- **Gap for critics:** `.suiteApp(...live:)` defaults to nil and no app passes a channel yet, so the live mode reaches no app until each app's line wires one. Expect a finding; file one gap per app at the end if it isn't fixed.
- Merge note: its MC-11 merge also removed CLIShapeTests.everyOtherFormIsAStubThatNamesItsSlice, leaving `jobs` as the only stub.
- For MC-15:
  - "allow once" is lost on reconnect;
  - after 110 s the client must call again;
  - `stop` disconnects every client;
  - the audit log is never rotated.

## 2026-10-19T10:35Z: MC-15 docs builder started
- It works on dev with CL-11, MC-10, MC-14 and MC-13 merged in, writing to lead/afterglow-mcp-MC-15. No PR.
- Once MC-15 is built, every MC slice is built; what remains is merging the held branches in dependency order, then the critics.

## 2026-10-19T10:39Z: heartbeat
- No merges yet. The macOS build for MC-12 (#3203) is now running (run 39225689887). The other lane builds are still queued (28 queued repo-wide).
- The MC-15 docs builder is running. Every other slice is built and held.

## 2026-10-19T10:50Z: MC-15 pushed; every MC slice is now built
- Branch: lead/afterglow-mcp-MC-15 @4e8e8a4153dd98cfdf9200259d7bd1e204dab72f. It is dev with CL-11, MC-10, MC-14 and MC-13 merged in.
- Own diff: 3 files, +274/−21.
  - docs/cli.md: the MCP server section.
  - afterglow-mcp.wave.json: status set to built.
  - CLIStubTests.swift: −18, a merge-order fix (below).
- Gate passed.
- PR title: "docs(suite): afterglow MCP server guide (MC-15)". Labels: feature-done. Slice: MC-z. Refs #3000.
- **Merge-order rule:** once CL-9's real `jobs` meets MC-8/MC-10's stub tests, nothing is a stub any more. Whichever PR lands after both must drop `everyStubExits69NamingItsSlice` (MC-15's own commit does this). Recheck when each held PR merges dev in.
- **Packet/code disagreements for the critics** (the doc follows the code):
  1. The live UI is not connected to the channel. The sheet, the chip with Stop, and Window > AI Access… all run on FakeAIAccess, so "Stop revokes within one request" is not true yet. Likely a p1 finding.
  2. No app wires `.suiteApp(...live:)`, so MJ4 can't run.
  3. LiveBridge opens a new connection for every call, so "Allow once" covers exactly one call.
  4. A remembered deny shows the same "answer it in <Title>" text, but no sheet appears.
  5. The app's cutoff is 110 s against the bridge's 120 s.
  6. notifications/cancelled gets no special handling, and the tool list isn't cached.
  7. The fake catalog has no lock command, so MJ3's "Unlock Rect 1 first." is unverified.
  8. The audit line adds an `outcome` field; at most 8 connections; client names capped at 128 characters.

## 2026-10-19T11:01Z: heartbeat; MC-9 merged; MC-12 needs-rebase
- #3202 MC-9 merged at 10:48Z.
- #3203 MC-12 built green, then got needs-rebase: MC-9 also rewrote suite-ai-access.json. I merged dev in and combined both descriptions (merge 6c826012). The gate is running; when it passes I push and move the Head: line.
- #3200, #3209 and #3211 are still waiting on macOS builds (30 queued).

### 11:09Z: MC-12 (#3203) integrated

- needs-rebase: MC-9 and MC-12 both changed the suite-ai-access C4 description. Merged origin/dev into lead/afterglow-mcp-MC-12 (6c826012), combined the two descriptions, and `scripts/ci --changed` printed CI: PASS. Pushed and moved Head: to 6c826012. Mergeable state is clean, and the lane drops the label on its next sweep.
- The cloud server adds the "Generated by Claude Code" footer back to the PR body on every write, whether by `-F body=@` or by JSON `--input`. The lane strips it from the squash (scripts/fast-lane.sh ATTRIBUTION filter) and reads `Head:` as a line, so nothing waits on it. Recorded here because the brief forbids it.
- Waiting on: #3200 (opens MC-3, MC-5, MC-7) and #3203 (opens MC-13).

### 11:24Z: heartbeat, #3200 MC-2 merged
- #3200 MC-2 merged at 11:15Z, in a lane batch of 2. A shipper is opening MC-3, MC-5 and MC-7: merge dev in, MC-8's duplicate-key test fix goes into MC-7, gate, then each PR.
- #3203 MC-12 is clean on 6c826012, needs-rebase is gone, and it waits for its macOS build.
- Next: MC-4 and MC-6 once MC-3 and MC-5 merge; MC-13 once #3203 merges.

## 2026-10-19T14:21Z: MC-12 merged, MC-13 PR #3272 open
- #3203 MC-12 merged in lane batch 20261019133046 (the prefix through #3203 was green; the batch went red on #3207's halo/render-frame real job, PNG.write waits on IC-5, not this lead's).
- MC-13: merged dev into lead/afterglow-mcp-MC-13. Four add/add conflicts left by MC-12's squash (AIAccessCommands.swift, AfterGlowJourneyTests+AIAccess.swift, two C4 parts); dev's copy equalled MC-12's head in each, so MC-13's side was taken. Own diff 7 files +113/-13. scripts/ci --changed: CI: PASS. Head 0b414652.
- The container had no swift; scripts/cloud-setup.sh installed 6.3.3 and the merge drivers.
- The session proxy re-appends a "Generated by" footer to PR bodies on every write; the lane strips it from the squash.

## 2026-10-19T15:31Z: MC-3 and MC-5 merged; MC-4 #3283 and MC-6 #3284 open
- #3237 MC-3 and #3238 MC-5 were squash-merged by the lane.
- MC-4: merged dev in.
  - Redid the add/add conflicts as 3-way merges from MC-4's fork point on MC-3 (aa3838e6), because MC-3 moved after the stack was built.
  - The CLIShapeTests and CLIStubTests stub tests had no stub entry point left (run and jobs are real on dev, mcp is real now), so I removed them.
  - Checked that the merged MCP diff equals MC-4's own diff.
  - Gate PASS. Pushed b8bc58ec and opened #3283.
- MC-6: merged dev in and took MC-6's side of MCPToolsTests. The diff matches MC-6's own. Gate PASS. Pushed c0cf1cfb and opened #3284.
- Carried to MC-8: enable MCPToolsTests.toolsListThroughTheServerMatchesTheList (it needs MC-4 and MC-6).
- listWithinBudget stays disabled until the supervisor adds a perf-suites entry.
- MC-4 and MC-6 both touch MCPShapeTests, so the lane integrates whichever merges second.

### 15:49Z: heartbeat
- MC-13 #3272, MC-4 #3283 and MC-6 #3284 are clean and waiting on their lane macOS builds. MC-8 is held until MC-4 and MC-6 merge.

### 16:07Z: heartbeat
- No merges. fast-lane.yml runs have been queued since 15:53Z, so the lane is backed up. MC-13 #3272, MC-4 #3283 and MC-6 #3284 are clean.

### 16:26Z: heartbeat
- No merges yet. Two lane sweeps are in progress (from 15:53Z and 16:05Z), 16 runs are queued repo-wide, and the dev CI run has been going since 14:25Z. Every open PR is clean.

### 16:44Z: heartbeat
- The macOS builds for MC-13 0b414652, MC-4 b8bc58ec and MC-6 c0cf1cfb succeeded. CL-11 is docs only. All four are ready and wait for the lane sweep running on dev since 16:28Z.

### 17:02Z: heartbeat
- Lane batch lane/batch-20261019170158 has been in its Linux check since 17:02Z. Our four PRs are clean and ready. No dev-red issue is open.

## 17:16Z: MC-13 merged, MC-live-ui built
- #3272 squash-merged as 731916bf at 17:16Z. CL-11 #3281 merged with it (feature-done), so a full dev CI run should follow.
- MC-live-ui's critics wait for the ui-screens of a run that contains 731916bf.
- MC-4 #3283 and MC-6 #3284 are still in the lane.

## 17:40Z MC-4 merged; MC-6 integrated

- MC-4 #3283 squash-merged 17:35Z as f0520a67.
- MC-6 #3284 conflicted with it (MCPShapeTests header and serve stub test; cli-mcp.json description). Merged dev in by hand, kept both: MC-4 server text plus MC-6 tools text. Enabled MCPToolsTests.toolsListThroughTheServerMatchesTheList now that both exist (passes).

## 21:36Z: MC-8 merged, MC-live-ui critics, fix round 1
- MC-8 #3320 squash-merged as cd44f3ee.
- MC-live-ui: Belt-Slice-Done and Mac-Finish-Wanted posted on run 39292755765 at 21:15Z. afterglow-cli: CL-z Slice-Done and Contact-Sheet posted; the supervisor closed #2998.
- The critic panel (clarity, journey, mouse, taste) on run 39292755765 confirmed 5 and refuted 2. Filed:
  - #3346 sheet says "the open document" on Home;
  - #3347 no way back named;
  - #3348 the two allows' scope;
  - #3349 the client isn't called an AI assistant;
  - #3350 the journey skips the re-ask after Stop.
- Fix round 1 (MC-live-ui):
  - #3362 fixes #3327: the chip is one accessibility element carrying its label, and the journey reads the label or value.
  - lead/afterglow-mcp-fix-copy fixes #3346-#3349: AIAccessPrompt title, scoped message and choiceHelp; AIAccessRequest.document; mutate 6/6.
  - lead/afterglow-mcp-fix-3350: FakeAIAccess's demo client asks again once after Stop, and the journey walks re-ask, Allow Once, Stop; mutate 2/2.
- MC-11 and MC-14 are re-merged with dev (cli-mcp.json: ours, a superset), gated (PASS) and pushed, held under the findings cap.
- 21:45Z: #3363 (copy) and #3364 (re-ask) opened with fast-lane, gate PASS. Findings close when they merge.

## 2026-10-20T05:20Z: run act-1a157b204fb-js9h, finish
- Brief: integration branch main, HEAD b3011ab9 verified. lead/afterglow-mcp rebuilt on origin/main carrying only docs/leads/afterglow-mcp (the old branch held 1700 dev commits; a commit-by-commit rebase would replay dev onto main).
- MC-a: last PR #3200 (3e9fbe1c, on main). Successful scoped suite run 39331727327 (bd10d93a) contains it. No open finding for the feature. Belt-Slice-Done posted.
- Contact sheet: every slice has its line (Belt counts MC-proto, MC-tools, MC-call, MC-live-wire, MC-z as done). Run 39370860805 (Linux check, dev 18464f26, success) is the newest completed run holding every slice's last PR, 13cf5dce; the supervisor's 05:03Z note makes Linux checks the merged-done proof. Scoped suite 39354995505 and full 39368749437 still queue for macOS.
- Left to the beta-hardening lane: MC-live-ui verification (Mac-Finish-Wanted posted 2026-10-19T21:15Z).
