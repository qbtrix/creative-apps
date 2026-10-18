# Feature packet: afterglow-mcp

**Feature:** `afterglow mcp`, a Model Context Protocol server over stdio
that publishes every app's command catalog as tools, generated from the
command schemas, so any MCP client (a coding agent, a crew, Paw OS) edits
AfterGlow documents through the same path as the menus and the CLI. It
covers the headless engine first: documents opened from files, held by an
explicit handle, saved and exported on request, on Linux and macOS. A later
pair of slices, **macOS-only**, drives a running app's live document
through the app's command channel: local-only (a same-user Unix socket, no
network listener), user-approved per client, revocable, visibly on, and
every edit an ordinary undo step. This server is the base the paid "AI via
Paw OS" module connects to; nothing in it is gated.
**Line:** `line:suite` · **Wave:** AI1 (`waves.md`, the AI-first track;
beta-80 **W0**, `p0`; the live slices are beta-80 **W2**) · **Lead branch:**
`lead/afterglow-mcp`

**Covers:** the captain's AI-accessible-first call (the MCP half); beta-80
plan "W0: command layer"; suite.md 1.5; the open-core AI module's
connection point (suite blueprint, editions).

**Depends on:**
- `afterglow-cli` (#2998; same line, slice waits): **CL-a** (the
  `AfterGlowCLICore` target, `HeadlessApp`, `HeadlessSession`, `CLIIO`, the
  `MCPServer.serve` stub this packet fills). MC-15's prose also waits on
  CL-z for `docs/cli.md`.
- `suiteui/command-catalog` (#2996) **CC-a** (cross-line, prose): `CommandCatalog`,
  `CommandDescription`, `CommandKind`, the fake headless document.
- The live slices also wait, as a hand-off the lead checks (cross-line), on
  `adopt-command-catalog` (#2999) having one app slice merged-done, so a real
  window has a catalog to drive; and on `suite-contracts` (#1332, built)
  for the preferences store the grants live in.

**Protocol version, checked 2026-10-19** (modelcontextprotocol.io): the
current revision is **2026-07-28**, sessionless (every request carries
`_meta["io.modelcontextprotocol/protocolVersion"]`; `server/discover`
returns versions, capabilities and identity). Handshake-era clients
(`2025-11-25`, `2025-06-18`) send `initialize` first; the server answers
both eras. stdio is newline-delimited JSON-RPC 2.0, UTF-8, nothing but
protocol on stdout. Tool names may use letters, digits, `_`, `-` and `.`,
1 to 128 characters. A tool's input error is a tool result with `isError:
true`; an unknown tool is JSON-RPC `-32602`. MC-1 pins these in
`MCPVersions.swift` and re-checks the spec before it merges (the doc page
is cited in the file header).

**C4:** component ✚ `cli-mcp` in container `afterglow-cli`
(`docs/c4/parts/creative-apps/afterglow-cli/cli-mcp.json`, `paths:
["Sources/AfterGlowCLICore/MCP/"]`, added by MC-1); component ✚
`shell-live-commands` in container `suite-shell`
(`docs/c4/parts/creative-apps/suite-shell/shell-live-commands.json`, added
by MC-10); the grants are a ✚ `suite-ai-access` component in `suite-model`
(`docs/c4/parts/creative-apps/suite-model/suite-ai-access.json`, MC-9).
Relationships: an MCP client (external) → afterglow-cli "tools over stdio";
afterglow-cli → suite-shell "live commands over a local socket (macOS)".

**Clean-room.** The protocol from its published specification only. No
other server's code is read.

Blueprint sections: suite.md 1.5, 2.3, 2.6 (processes and wires), 6.2
(menus: Window > AI Access…).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| MC-a | The MCP types, version table, tool and session stubs exist in `AfterGlowCLICore/MCP/` with an in-process test client that speaks both protocol eras, so the protocol, tools and call slices build at once. | MC-1, MC-2 | MJ0 | afterglow-cli:CL-a |
| MC-proto | The server reads one JSON-RPC message per line, answers `server/discover` and per-request versions (2026-07-28) and `initialize` (handshake era), maps malformed input to the right JSON-RPC errors, never answers a notification, and writes nothing but protocol to stdout. | MC-3, MC-4 | MJ1 | MC-a |
| MC-tools | `tools/list` publishes one tool per catalog command (`<app>.<command>`) plus the session tools, each with its title, description, input schema `{doc, params}` from the command's schema, output schema and kind-based annotations, in a stable order, filterable by app. | MC-5, MC-6 | MJ2 | MC-a |
| MC-call | `tools/call` opens documents under the allowed roots into expiring handles, runs any command on a handle through the catalog, saves and exports only under the roots, and reports refusals, schema issues and why-nots as tool errors the model can act on. | MC-7, MC-8 | MJ3 | MC-a |
| MC-live-wire | (macOS-only) A running app listens on a same-user Unix socket, refuses any client without a grant, and runs granted commands on its window's document through the catalog on the main actor; `afterglow mcp --live` bridges those as `live.<app>.<command>` tools. | MC-9, MC-10, MC-11 | MJ4 | MC-call |
| MC-live-ui | (macOS-only) The first request from a new client shows an approval sheet (allow once, always for this client, deny); a "Controlled by <client>" chip shows while connected with a Stop button; Window > AI Access… lists and revokes grants. | MC-12, MC-13 | `AfterGlowJourneyTests.testAIAccessApproval` | MC-a |
| MC-z | A scripted session runs every tool on the fake in both protocol eras through the spawned binary, the reference and the client set-up are written, and the feature is built. | MC-14, MC-15 | MJ5 | every slice above; afterglow-cli:CL-z (MC-15) |

The headless server is usable once MC-call is merged-done; the live slices
come after (beta-80 W2) and never hold the headless ones. MC-live-ui is the
only UI slice (`"ui": true`); the headless server has no screen. Screen
early (rule 18): it waits only on MC-a, whose MC-1 declares
`AIAccessGrants` as a stub and `FakeAIAccess`, so the sheet, the chip and
the list are built and journeyed on the fake (the `-AIAccessDemoRequest`
launch hook) beside the logic; MC-live-wire makes them real.

**Cross-line files.** MC-12 adds two SuiteUI views and MC-10 one call in
SuiteShell's `SuiteAppModifier.swift`, as the kernel track's packets edit
app Models: the lead names them in each PR's body, and MC-10 starts only
after `switching` (the file's earlier owner) is built.

## Journey steps

1. MJ0 (Linux, MC-1, MC-2): the test client sends `server/discover` and
   gets the stub's `UnsupportedProtocolVersionError`-free answer with the
   supported versions; every stub answers or errors naming its slice.
2. MJ1 (Linux, MC-3, MC-4): `{"jsonrpc":"2.0","id":1,"method":
   "server/discover"}` returns versions `["2026-07-28", "2025-11-25",
   "2025-06-18"]`, `capabilities.tools`, and `serverInfo` "afterglow"; an
   `initialize` with `2025-06-18` is answered in that version; a request
   with `protocolVersion` "2024-01-01" gets the unsupported-version error
   listing the three; `{bad json` gets `-32700`; a notification gets
   nothing.
3. MJ2 (Linux, MC-5, MC-6): `tools/list` with `--app fake` lists
   `fake.open`, `fake.new`, `afterglow.save`, `afterglow.export`,
   `afterglow.close`, then `fake.rect.add` … in id order; `fake.rect.list`
   carries `readOnlyHint: true`; `fake.rect.add`'s input schema nests the
   command's params schema under `params`.
4. MJ3 (Linux, MC-7, MC-8): `fake.open {"path": "a.fake"}` returns
   `{doc, summary}`; `fake.rect.add {"doc", "params": {...}}` returns
   `{undoStep: "Add Rectangle"}`; `fake.rect.move` on a locked rect returns
   `isError: true` with "Unlock Rect 1 first."; `{"path": "/etc/passwd"}`
   returns `isError` "outside the allowed roots"; after the idle limit the
   handle returns `isError` "this document handle expired; open it again".
5. MJ4 (macOS, MC-9 to MC-11): a Photo window with a document; `afterglow
   mcp --live` lists `live.photo.*`; the first call waits on a grant (the
   journey grants through the test hook); a granted `live.photo.layer.add`
   adds a layer the window shows and Edit > Undo reads "Undo Add Layer".
6. `testAIAccessApproval` (macOS, MC-12, MC-13): launched with
   `-AIAccessDemoRequest "Test Client"`, the sheet names the client and the
   app; Allow once: the chip "Controlled by Test Client" shows; Stop: the
   chip goes and the next request asks again; Window > AI Access… lists no
   grant.
7. MJ5 (Linux, MC-14): the spawned `afterglow mcp --app fake --root <tmp>`
   runs MJ1 to MJ3 over real pipes in both eras and exits 0 on stdin's end.

## Screens and states

`suite-ai-access-sheet` (the approval sheet, light and dark),
`suite-ai-access-chip` (the title-bar chip while connected),
`suite-ai-access-list` (Window > AI Access…, one grant and empty).

## Contract slice

```swift
// Sources/AfterGlowCLICore/MCP/MCPVersions.swift (MC-1)
public enum MCPVersions {
    public static let current = "2026-07-28"
    public static let supported = ["2026-07-28", "2025-11-25", "2025-06-18"]   // newest first
    public static func negotiate(_ requested: String?) -> String? }               // nil = unsupported
// Sources/AfterGlowCLICore/MCP/JSONRPC.swift (MC-1 stub, MC-4 body)
public enum RPCID: Hashable, Sendable, Codable { case number(Int), string(String) }
public struct RPCRequest: Sendable { public var id: RPCID?; public var method: String; public var params: JSONValue? }   // id nil = notification
public struct RPCError: Error, Hashable, Sendable { public var code: Int; public var message: String; public var data: JSONValue? }
public enum JSONRPC { public static let maxLineBytes = 16 << 20
    public static func parse(_ line: Data) -> Result<RPCRequest, RPCError>            // -32700, -32600
    public static func reply(_ id: RPCID, result: JSONValue) -> Data; public static func reply(_ id: RPCID?, error: RPCError) -> Data }
// Sources/AfterGlowCLICore/MCP/MCPServer.swift (CL-2 stub; MC-1 contract, MC-4 body)
public struct MCPOptions: Sendable { public var apps: [HeadlessApp]; public var roots: [String]; public var live: Bool
    public var maxOpen = 16; public var idleSeconds = 3600.0; public var maxCallsPerSecond = 50 }
public final class MCPServer: Sendable {
    public init(_ options: MCPOptions, io: any CLIIO, clock: @escaping @Sendable () -> Double)
    public func handle(_ line: Data) -> Data?          // one message in, one reply out (nil for a notification)
    public static func serve(_ arguments: [String], io: any CLIIO) -> Int32 }   // the `afterglow mcp` route
// Sources/AfterGlowCLICore/MCP/MCPTools.swift (MC-1 stub, MC-6 body)
public struct MCPTool: Codable, Hashable, Sendable { public var name, title, description: String
    public var inputSchema: JSONValue; public var outputSchema: JSONValue?; public var annotations: JSONValue }
public enum MCPTools {
    public static func list(_ apps: [HeadlessApp]) -> [MCPTool]   // session tools first, then every app's commands by id
    public static func name(app: String, command: String) -> String   // "photo.layer.add"
    public static func route(_ name: String, in apps: [HeadlessApp]) -> MCPRoute? }
public enum MCPRoute: Hashable, Sendable { case open(app: String), new(app: String), save, export, close, command(app: String, id: String) }
// Sources/AfterGlowCLICore/MCP/MCPSessions.swift (MC-1 stub, MC-8 body)
public struct MCPSessions: Sendable {   // the open documents, by opaque handle (UUID)
    public mutating func call(_ route: MCPRoute, _ arguments: JSONValue, now: Double) -> MCPToolResult }
public struct MCPToolResult: Hashable, Sendable { public var structured: JSONValue; public var text: String; public var isError: Bool }

// Sources/SuiteModel/AIAccess/AIAccessGrants.swift (MC-9; Linux-safe)
public enum AIAccessDecision: String, Codable, Sendable { case allowOnce, alwaysForClient, deny }
public struct AIAccessGrants: Codable, Hashable, Sendable {
    public func allows(client: String, app: String, kind: CommandKind) -> Bool?   // nil = ask; .file kind always asks
    public mutating func record(_ d: AIAccessDecision, client: String, app: String)
    public mutating func revoke(client: String, app: String?); public var entries: [AIAccessEntry] { get } }
// Sources/SuiteShell/LiveCommandChannel.swift (MC-10; macOS)
@MainActor public final class LiveCommandChannel {
    public init<D: HeadlessDocument>(app: String, document: @escaping @MainActor () -> D?, apply: @escaping @MainActor (D) -> Void,
                                     ask: @escaping @MainActor (AIAccessRequest) async -> AIAccessDecision)
    public func start() throws; public func stop()   // socket: ~/Library/Application Support/AfterGlow/live/<app>-<pid>.sock, dir 0700, socket 0600
    public var connectedClient: String? { get } }    // read by the chip
```

Tools (MC-6): session tools `<app>.open {path}`, `<app>.new {options?}`,
`afterglow.save {doc, path?, force?}`, `afterglow.export {doc, format,
path, options?, force?}`, `afterglow.close {doc}`; then per command
`<app>.<id> {doc, params}`. Descriptions: the spec's summary, then
"Undoable: one step named '<title>'." for edits, and for `open` the
handle's lifetime ("handles expire after 1 hour idle; at most 16 open").
Annotations: `query` → `readOnlyHint: true`; `view` and `edit` →
`readOnlyHint: false, destructiveHint: false` (an edit is undoable);
`file` → `destructiveHint: true` only for writes with `force`; every tool
`openWorldHint: false`.

## Pseudocode

```
handle(line):
  req = JSONRPC.parse(line)              // error → reply(id: nil, -32700/-32600)
  if req is notification: handle "notifications/cancelled" (drop if done); return nil
  version = req.params._meta[protocolVersion] ?? (method == "initialize" ? params.protocolVersion : sessionVersion)
  if version and negotiate(version) == nil: reply error {code: -32602-equivalent unsupported, data: {supported}}
  switch method:
    server/discover → {supportedVersions, capabilities: {tools: {listChanged: false}}, serverInfo}
    initialize      → {protocolVersion: negotiated, capabilities, serverInfo}; remember sessionVersion
    tools/list      → MCPTools.list(apps)            // deterministic; no pagination under 2,000 tools
    tools/call      → route = MCPTools.route(name) ?? reply error -32602 "Unknown tool: name"
                      if rate exceeded: isError "slow down: at most N calls a second"
                      result = sessions.call(route, arguments, now)
                      reply {content: [{type: text, text}], structuredContent, isError}
    else            → -32601

sessions.call(route, args, now):
  expire handles idle past idleSeconds
  open:    path inside a root (resolved, no symlink escape) else isError; count < maxOpen else isError
           data = io.read(path); s = app.session(open: data); handle = UUID(); return {doc, summary}
  command: s = handles[doc] ?? isError("this document handle expired; open it again")
           CatalogError → isError text: malformed → each "/path: message"; unavailable → why; failed → message
  save/export: path inside a root; refuse an existing file unless force
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| MC-1 | – | The contract: `MCPVersions` (pinned, the spec page cited), `JSONRPC`, `MCPServer`, `MCPTools`, `MCPRoute`, `MCPSessions` and `AIAccessGrants` as documented stubs, `FakeAIAccess`; the `cli-mcp` C4 part; MJ0's shape checks | `Sources/AfterGlowCLICore/MCP/MCPVersions.swift`, `Sources/AfterGlowCLICore/MCP/JSONRPC.swift`, `Sources/AfterGlowCLICore/MCP/MCPServer.swift`, `Sources/AfterGlowCLICore/MCP/MCPTools.swift`, `Sources/AfterGlowCLICore/MCP/MCPSessions.swift`, `Tests/AfterGlowCLITests/MCPShapeTests.swift`, `docs/c4/parts/creative-apps/afterglow-cli/cli-mcp.json`, `Sources/SuiteModel/AIAccess/AIAccessGrants.swift`, `Sources/SuiteModel/AIAccess/FakeAIAccess.swift` | – | ~360, 9 |
| MC-2 | – | `MCPTestClient`: an in-process client over `MCPServer.handle` that speaks both eras (per-request `_meta` and `initialize` first) and asserts one reply per request; MJ0 covers it | `Tests/AfterGlowCLITests/MCPTestClient.swift`, `Tests/AfterGlowCLITests/MCPClientTests.swift` | MC-1 | ~200, 2 |
| MC-3 | – | Checks first: `MCPProtocolTests` (framing, line cap, -32700/-32600/-32601, notifications unanswered, discover, initialize in each era, unsupported version lists the supported, stdout carries only replies); MJ1, disabled | `Tests/AfterGlowCLITests/MCPProtocolTests.swift` | MC-2 | ~240, 1 |
| MC-4 | – | `JSONRPC` and `MCPServer` dispatch, negotiation and rate limit bodies, the plan; `afterglow mcp [--app] [--root] [--live]` parsed strictly; turns on `MCPProtocolTests` | `Sources/AfterGlowCLICore/MCP/JSONRPC.swift`, `Sources/AfterGlowCLICore/MCP/MCPServer.swift`, `Tests/mutations/AfterGlowCLICore.MCPServer.json`, `Tests/AfterGlowCLITests/MCPProtocolTests.swift` | MC-3 | ~340, 4 |
| MC-5 | – | Checks first: `MCPToolsTests` (one tool per command, names valid and unique, session tools first, input schema nests params, output schema, annotations by kind, stable order, `--app` filter, route round trip); MJ2, disabled | `Tests/AfterGlowCLITests/MCPToolsTests.swift` | MC-2 | ~200, 1 |
| MC-6 | – | `MCPTools` body and plan; turns on `MCPToolsTests` | `Sources/AfterGlowCLICore/MCP/MCPTools.swift`, `Tests/mutations/AfterGlowCLICore.MCPTools.json`, `Tests/AfterGlowCLITests/MCPToolsTests.swift` | MC-5 | ~260, 3 |
| MC-7 | – | Checks first: `MCPCallTests` (open, run, why-not and schema issues as `isError`, unknown tool -32602, roots and symlink escape refused, the open cap, idle expiry on an injected clock, save and export refuse to overwrite without `force`); MJ3, disabled | `Tests/AfterGlowCLITests/MCPCallTests.swift` | MC-2 | ~280, 1 |
| MC-8 | – | `MCPSessions` body and plan; `tools/call` wired; turns on `MCPCallTests` | `Sources/AfterGlowCLICore/MCP/MCPSessions.swift`, `Tests/mutations/AfterGlowCLICore.MCPSessions.json`, `Tests/AfterGlowCLITests/MCPCallTests.swift` | MC-7, MC-4 | ~340, 3 |
| MC-9 | – | `AIAccessGrants` body (Linux): ask, allow once, always for a client per app, deny, revoke, `file` kind always asks; stored through the suite preferences store; its tests, plan and C4 part | `Sources/SuiteModel/AIAccess/AIAccessGrants.swift`, `Tests/SuiteModelTests/AIAccessGrantsTests.swift`, `Tests/mutations/SuiteModel.AIAccessGrants.json`, `docs/c4/parts/creative-apps/suite-model/suite-ai-access.json` | MC-1 | ~220, 4 |
| MC-10 | – | `LiveCommandChannel` (macOS): the socket under Application Support (dir 0700, socket 0600, stale socket removed at start), the same-user peer check, stdio framing, a grant before any command, commands through the catalog on the main actor, an audit line per command (client, app, id, time; no params) in `~/Library/Logs/AfterGlow/ai-access.log`; started by `SuiteAppModifier`; the C4 part | `Sources/SuiteShell/LiveCommandChannel.swift`, `Sources/SuiteShell/SuiteAppModifier.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-live-commands.json` | MC-9, MC-8 (and `switching`, which owns `SuiteAppModifier.swift` first) | ~360, 3 |
| MC-11 | – | `LiveBridge` (`#if os(macOS)`): `afterglow mcp --live` finds the running apps' sockets, lists `live.<app>.<id>` tools from each app's catalog, forwards calls; a socket-pair fake app in its test | `Sources/AfterGlowCLICore/MCP/LiveBridge.swift`, `Tests/AfterGlowCLITests/LiveBridgeTests.swift` | MC-8 | ~300, 2 |
| MC-12 | – | The approval sheet, the "Controlled by" chip with Stop, and Window > AI Access… (SuiteUI views over `AIAccessGrants`, on `FakeAIAccess` through the `-AIAccessDemoRequest` hook); its first change puts AI Access… in the Window menu, the visible control; snapshots; the journey written first, skipped | `Sources/SuiteUI/AIAccessSheet.swift`, `Sources/SuiteUI/AIAccessChip.swift`, `Sources/SuiteShell/AIAccessCommands.swift`, `Tests/AppSnapshotTests/SuiteAIAccessSnapshots.swift`, `UITests/AfterGlowJourneyTests+AIAccess.swift` | MC-1 | ~380, 5 |
| MC-13 | – | Render budget (the sheet's appearance and Allow ≤ 2 window bodies; the chip adds 0 bodies to a canvas drag) and the journey turned on, on the fake request | `Tests/AppSnapshotTests/RenderBudgetAIAccessTests.swift`, `UITests/AfterGlowJourneyTests+AIAccess.swift` | MC-12 | ~160, 2 |
| MC-14 | – | MJ5: spawn `afterglow mcp --app fake --root <tmp>` and run MJ1 to MJ3 over pipes in both eras | `Tests/AfterGlowCLITests/MCPBinaryTests.swift` | MC-4, MC-6, MC-8 | ~180, 1 |
| MC-15 | – | Shared prose: `docs/cli.md` "MCP server" (set-up for a client: the `.mcp.json` entry, the tools, handles, roots, the live mode and its approval), `status: built`; `feature-done`. suite.md already names the component, the wire and the menu (the packet PR wrote them) | `docs/cli.md`, `docs/blueprints/suite/features/afterglow-mcp.wave.json` | MC-11, MC-13, MC-14 | ~220, 2; `feature-done` |

MC-4, MC-6 and MC-8 fill different files; MC-8 waits on MC-4 only because
`tools/call` is dispatched by the server body. MC-9 fills the grants stub
MC-1 declares and is Linux-safe. `SuiteAppModifier.swift`
is a shared SuiteShell file (every app adds the modifier); MC-10 adds one
call to it and nothing else.

## Build waves

- Wave 1: MC-1. Independent in this wave: MC-1 alone.
- Wave 2: MC-2, MC-9, MC-12. Independent in this wave: all three.
- Wave 3: MC-3, MC-5, MC-7, MC-13. Independent in this wave: all four.
- Wave 4: MC-4, MC-6. Independent in this wave: both.
- Wave 5: MC-8. Independent in this wave: MC-8 alone.
- Wave 6: MC-10, MC-11, MC-14. Independent in this wave: all three.
- Wave 7: MC-15 (shared prose, `feature-done`, final). Independent in this wave: MC-15 alone.

MC-9, MC-12 and MC-13 sit in early waves by their dependencies; the lead
starts the live slices only after the hand-off above (an adopt slice
merged-done), never ahead of MC-call.

Longest chain: MC-1 → MC-2 → MC-3 → MC-4 → MC-8 → MC-11 → MC-15 (7). Chain
of 7: MC-2's client drives MC-3's checks, MC-4 turns them on and dispatches
the calls MC-8 answers, MC-11 forwards MC-8's sessions to a live app, and
MC-15 is the final prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| MC-1 | `MCPShapeTests` (MJ0): every type exists; `MCPVersions.supported` is newest first and `negotiate` returns nil for an unknown version | a signature or version is missing | – (stubs) |
| MC-2 | `MCPClientTests`: the client gets exactly one reply per request in both eras | the client accepts two replies or none | – (test support) |
| MC-3 | `MCPProtocolTests` exists, disabled | – | – (tests) |
| MC-4 | `MCPProtocolTests` (MJ1) | a malformed line gets the wrong code, a notification gets a reply, or anything non-protocol reaches stdout | parse errors answered with -32600 → `.parseErrorIs32700`; notifications answered → `.notificationsUnanswered`; an older version accepted unnegotiated → `.unsupportedVersionListed` |
| MC-5 | `MCPToolsTests` exists, disabled | – | – (tests) |
| MC-6 | `MCPToolsTests` (MJ2) | a tool is missing, a name is invalid, the order changes between calls, or a query lacks `readOnlyHint` | order by dictionary iteration → `.stableOrder`; params schema inlined instead of nested → `.paramsNested`; `readOnlyHint` from `undoable` instead of `kind` → `.readOnlyFromKind` |
| MC-7 | `MCPCallTests` exists, disabled | – | – (tests) |
| MC-8 | `MCPCallTests` (MJ3) | a path outside the roots opens, a why-not becomes a protocol error, an expired handle answers, or an export overwrites | root check on the unresolved path → `.symlinkEscapeRefused`; `isError` false on unavailable → `.whyNotIsToolError`; expiry `>` for `>=` → `.idleExpiryInclusive` |
| MC-9 | `AIAccessGrantsTests` | a deny allows, a revoke keeps a grant, or a `file` command skips the ask | `file` kind follows the client grant → `.fileAlwaysAsks`; revoke of one app clears all → `.revokeScoped` |
| MC-10 | macOS build-only job compiles it; `LiveBridgeTests` (MC-11) exercises the framing it shares | – | – (macOS glue; logic is in MC-9 and MC-11) |
| MC-11 | `LiveBridgeTests` (macOS): tools listed from the fake app's catalog; a call forwarded and answered; a refused grant returns `isError` "Photo asked you to approve this client"; a dead socket is skipped | a refused grant runs, or a dead app breaks the list | grant refusal forwarded as success → `.refusedGrantIsError` |
| MC-12 | snapshots of the three states; the journey written, skipped | – | – (UI; budget in MC-13) |
| MC-13 | `RenderBudgetAIAccessTests`; `testAIAccessApproval` passes | over budget, or the chip stays after Stop | – |
| MC-14 | `MCPBinaryTests` (MJ5) | the binary and `handle` disagree, or stdout carries a non-protocol line | – (integration) |
| MC-15 | `scripts/waves check`, `scripts/c4-assemble --check` | the data or parts don't assemble | – (prose) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| list latency | `tools/list` over all five apps ≤ 50 ms on Linux CI after the first call (cached per process) | `MCPToolsTests.listWithinBudget` (reported) |
| call overhead | a fake `rect.add` through `tools/call` ≤ 1 ms p95 beyond the catalog run | `MCPCallTests.callOverhead` (reported) |
| untrusted input | 1,000 seeded mutations of each request kind get a JSON-RPC error or a tool error; never crash, never write outside the roots | `MCPProtocolTests.fuzzedRequestsNeverCrash` |
| rate limit | over `maxCallsPerSecond`, calls return `isError` "slow down", none run | `MCPCallTests.rateLimited` |
| local only | no TCP listener anywhere in the target; the live socket is 0600 in a 0700 dir and refuses another uid | `LiveBridgeTests.socketPermissions` (macOS) |
| human in the loop | a live edit never runs before a grant; Stop revokes within one request | `testAIAccessApproval` |
| render: approval sheet | appear plus Allow ≤ 2 window bodies; p95 ≤ 8 ms | `RenderBudgetAIAccessTests.sheet` |

## Done check

Per slice: its tasks merged and the newest dev CI run containing its last
PR has a green `Linux` job (MJ0 to MJ3 and MJ5 run there). The live slices
are macOS-only: merged-done on the macOS build-only job plus the Linux job
for MC-9; MC-live-ui also the feel gate and its `Mac-Finish:` line. Then
the contact sheet: the tool list for every app and the approval screens.
