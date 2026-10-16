# Editions: the seams for the paid modules

The code seams for the open-core model in `docs/licensing.md` (the captain's
decision of 2026-10-15): a GPL core that is complete on its own, and three
closed modules (Team, AI, Enterprise) that plug into it in the official build.
This designs the seams only. Nothing here is built yet, and no closed code
ever lands in this repo.

Read on 2026-10-15: creative-apps `origin/dev` a2313a5 (`docs/blueprints/suite.md`,
`docs/engineering.md`, `docs/c4/model.json`, `Sources/HaloModel/Contracts/`),
creative-core `origin/dev` c608d4b (`Sources/FlareCore/Command.swift`,
`CommandRegistry.swift`, `Document.swift`). Platform facts from the
`apple-docs` MCP tools: "Bundle.principalClass", "Disable Library Validation
Entitlement".

The suite blueprint lists "cloud sync, accounts, collaboration" as v1
non-goals (suite.md 1.3). That stays true: v1 ships none of it. This page
makes sure v1 code doesn't block it. The supervisor links this page from
suite.md.

## 1. Rules for every seam

1. **One protocol per paid capability**, four in all (section 3). A closed
   module conforms to one or more; the core only ever talks to the protocol.
2. **Every protocol has a free default in the core.** The default does
   nothing, or answers "not available", and is what the public GPL build runs.
3. **No dead controls** (CLAUDE.md). Every capability carries
   `unavailableHelp: String?`, the same shape as `HaloService` in
   `Sources/HaloModel/Contracts/HaloContracts.swift`. Nil means it can act; a
   string is the tooltip of every control that needs it, which stays
   disabled. A menu item for it gets a nil action. A default's help names
   what is missing in plain words, for example "Comments need AfterGlow
   Team." or "AI needs a Paw OS account."
4. **A module never gates a core tool.** Every manual tool works with the
   defaults. A Model test (ED-4) runs each app's tools test (`<X>ToolsTests`)
   on the defaults and on the fakes and expects the same results.
5. **The core never names a module's internals.** No closed type, endpoint
   or key appears in this repo; only the protocols and their values do.
6. **Models stay Linux-safe.** The protocols are Foundation-only values and
   `async` methods, `Sendable`, Swift 6, like suite.md's contracts.

## 2. Where they live

In **`SuiteModel`**, the planned Linux-safe Model target every app Model
already depends on (suite.md 2.2), in a new component **suite-editions**:

| Path (planned) | What |
|---|---|
| `Sources/SuiteModel/Editions/EditionContracts.swift` | The four protocols and `EditionCapability` |
| `Sources/SuiteModel/Editions/EditionValues.swift` | The values they pass: `EditionModuleID`, `AIRequest`/`AIResult`, `PresenceEntry`, `RemoteChange`, `SignedInAccount`, `PolicyDecision` |
| `Sources/SuiteModel/Editions/EditionDefaults.swift` | The free defaults (section 3) |
| `Sources/SuiteModel/Editions/SuiteEditions.swift` | `SuiteEditions` (one slot per protocol) and `EditionRegistry` |
| `Sources/SuiteModel/Fakes/Edition*.swift` | Fakes that act, for tests and snapshots |
| `Sources/SuiteShell/Editions/EditionLoader.swift` | macOS: finds, checks and loads module bundles (section 4) |
| `Tests/SuiteModelTests/Editions*.swift` | Default, fake and registry tests; the conformance suites a module must pass |

`SuiteModel` is created by suite task BU-1; the editions tasks (section 8)
come after it. When they land, the suite-editions component goes into
`docs/c4/model.json` with these paths.

## 3. The protocols

A sketch; ED-1 writes the real file and its tests.

```swift
/// What every edition capability shares: whether its controls can act.
public protocol EditionCapability: Sendable {
    /// Nil once it can act; otherwise the help of every control that needs it.
    var unavailableHelp: String? { get }
}

/// AI in every app, through the user's Paw OS account (the AI module).
public protocol AIProviding: EditionCapability {
    /// The AI actions this app may offer now, e.g. "photo.removeObject".
    func actions(for app: SuiteApp) async -> [AIActionDescriptor]
    /// Runs one action on values the app converted from its document.
    /// The result is applied by the app as an ordinary command, so it undoes.
    func run(_ request: AIRequest) async throws(EditionError) -> AIResult
}

/// Hosted sync, presence, comments and history (the Team module).
public protocol SyncProviding: EditionCapability {
    func attach(documentID: String, revision: Int) async throws(EditionError) -> SyncSession
    func send(_ changes: [DocumentChange], in session: SyncSession) async throws(EditionError)
    func incoming(_ session: SyncSession) async -> AsyncStream<RemoteChange>
    func presence(_ session: SyncSession) async -> AsyncStream<[PresenceEntry]>
    func detach(_ session: SyncSession) async
    /// Comments and version history share the session; each has its own help.
    var commentsHelp: String? { get }
    var historyHelp: String? { get }
}

/// Who is signed in: the Paw OS account, a Team account, or company SSO.
public protocol IdentityProviding: EditionCapability {
    func current() async -> SignedInAccount?
    func signIn(_ method: SignInMethod) async throws(EditionError) -> SignedInAccount
    func signOut() async
    func changes() async -> AsyncStream<Int>
}

/// Company policy (the Enterprise module): which modules and features may act.
public protocol PolicyProviding: EditionCapability {
    func decision(for feature: PolicyFeature) async -> PolicyDecision  // .allowed or .denied(help:)
    func audit(_ event: AuditEvent) async
}
```

`DocumentChange` is an encoded command envelope (section 6), so sync carries
the same operations undo already records.

**The free defaults:**

| Protocol | Default | What it does | `unavailableHelp` |
|---|---|---|---|
| `AIProviding` | `NoAI` | No actions; `run` throws `.notAvailable` | "AI needs a Paw OS account." |
| `SyncProviding` | `NoHostedSync` | `attach` throws `.notAvailable`; streams finish at once | "Sync needs AfterGlow Team." (comments and history the same) |
| `IdentityProviding` | `NoAccount` | `current()` is nil; `signIn` throws | "Signing in needs AfterGlow Team or a Paw OS account." |
| `PolicyProviding` | `OpenPolicy` | Every feature `.allowed`; `audit` does nothing | nil: with no company policy, nothing is restricted |

Local co-editing between Macs on one network stays in the core (licensing.md).
When it is built it is a core conformance of `SyncProviding`
(`LocalPeerSync`), not a module, and it uses the same change format.

## 4. How a module registers at launch

**Packaging.** Each module is a loadable bundle,
`AfterGlow.app/Contents/PlugIns/<Name>.afterglowmodule` (Team, AI,
Enterprise), signed with the same team id as AfterGlow. Its `Info.plist`
names `NSPrincipalClass` and `AfterGlowEditionProtocolVersion`. The
protocols must come from the one shared `SuiteModel` framework (suite.md D2),
so the module and every app process see the same protocol types.

**Loading** (`EditionLoader`, run once per process before the first window,
in the launcher and in each embedded app):

1. List `Contents/PlugIns/*.afterglowmodule` of the outer `AfterGlow.app`
   (an embedded app finds it from its own bundle path). None: use the
   defaults and stop.
2. Skip a module whose protocol version the core doesn't know, or whose
   signature fails. Under the hardened runtime, library validation already
   refuses code not signed by Apple or by the main executable's team (Apple
   docs: "Disable Library Validation Entitlement"); AfterGlow never sets
   that entitlement. So the official build with modules needs the Developer
   ID signing of suite.md Q3.
3. Load the bundle and read `principalClass` (Apple docs:
   "Bundle.principalClass": nil when the code can't load); cast it to
   `EditionModule.Type`; on failure skip it.
4. Call `register(into: &registry)`. A module fills only its slots;
   `EditionRegistry` keeps the first conformance per slot and records a
   second as a conflict (shown in Settings ▸ About, never a crash).
5. Ask the policy slot (`OpenPolicy` unless Enterprise is present) for each
   filled slot's feature; a denied one goes back to its default, with the
   policy's help text.
6. Freeze: `registry.editions()` returns `SuiteEditions`, which the process
   passes into its Models with `SuiteServices` (suite.md 5.3). Slots never
   change while the process runs; signing in or out changes state inside a
   provider and is reported through its `changes()`.

```swift
public protocol EditionModule: AnyObject {
    static var id: EditionModuleID { get }   // .team, .ai, .enterprise
    static func register(into registry: inout EditionRegistry)
}
```

A failing module never stops the core: every skip falls back to the default
and is listed in Settings ▸ About with its reason.

## 5. The public GPL build

The public build is `scripts/bundle-apps` as today, with no `PlugIns`
folder. So:

- The loader finds nothing and every slot holds its default.
- Every control backed by a module is present and disabled, with the
  default's help as its tooltip; menu items for it have a nil action.
- No network call, no account prompt, no license check, no nag. Settings ▸
  About lists the editions in one plain line each ("AfterGlow Team: not
  installed").
- Every manual tool, local file, hand-off and (once built) local co-editing
  works exactly as in the official build.

How a Model exposes it: the app Model reads `editions.ai.unavailableHelp`
and friends and returns them from its existing `unavailableHelp(for:)` (as
Halo does), so a view never asks the registry directly.

## 6. Collaboration-ready documents

Team co-editing (and local co-editing) syncs the edits people make, as
operations. If documents are only built for single-user undo, co-editing
later means rewriting every app's document model. So these rules apply
from now on to every document format and command set. Each one marked
**[collab-ready]** is a requirement on creative-core's `CommandEngine` (and
on the Design and Photo histories that play its part) and goes there as a
`needs-core` issue with an acceptance test.

What exists today (creative-core c608d4b): scenes, symbols and layers have
`String` ids; every edit is a `Command` with a stable `Command.id`, Codable
params and an envelope through `CommandRegistry` ("journals, scripting,
replay"). That is the right base. The gaps:

1. **[collab-ready] Stable ids for everything a command can address.**
   Shapes, instances, guides and keyframes are addressed by position today
   (`shapeNotFound(Int)`, instance and guide indexes), swatches by name and
   keyframes by `(property, frame)`. Each gets a stable id made where it is
   created (on the device that made it, unique without a server) and kept
   through save, load, copy and undo. Positions stay as a view of order.
2. **[collab-ready] Commands name their targets by id, never by index.** A
   command made on one copy must mean the same thing on another copy that
   has had other edits.
3. **[collab-ready] Order by position keys, not array index.** Layer,
   shape, scene and keyframe order is stored as a sortable key between its
   neighbours, so two people inserting or reordering at once both land.
4. **[collab-ready] Each command declares its footprint**: the ids and
   properties it reads and writes. Commands with disjoint footprints commute;
   overlapping ones follow one written rule (last writer per property wins,
   a delete wins over an edit of the deleted element), tested in the engine.
5. **[collab-ready] Apply a remote command** without touching the local
   undo stack: `CommandEngine.applyRemote(_:)`, validated like `perform`.
   Undo then undoes only your own commands, rebased over the ones that
   arrived since.
6. **[collab-ready] A document id and revision** in every file, so a sync
   session knows what it is attached to (`SyncProviding.attach`).
7. **Snapshot histories are not enough.** Design (`DesignHistory`), Photo
   (`PhotoHistory`, tiles) and Halo (`HaloProject.edit`, state before) undo
   by restoring state. That is fine for v1; their engine work must move to
   command-based edits with rules 1–6 before co-editing reaches that app.
   Photo's pixel edits may sync as tile changes per layer id rather than
   per stroke; that call is the Team blueprint's.

None of this needs a network or an account, and each rule makes local
undo and the file format more robust on its own, so it can start before
Team is built.

## 7. How the journeys test both builds

- **Public build (every run).** The journeys run `.build/apps/AfterGlow.app`
  with no modules, as today. For each app, an editions journey step opens
  every module-backed control and checks it is disabled with the default's
  help as its tooltip; the app audit already checks disabled controls look
  dimmer. Then the app's core journey runs unchanged, which proves no core
  tool needs a module.
- **Module-shaped build.** A GPL test module, `EditionsTestModule`
  (`Tests/EditionsTestModule/`, never shipped), conforms to all four
  protocols with deterministic fakes: AI returns a fixed result, sync loops
  changes back from a second in-process peer, identity is signed in as
  "Test User", policy denies one named feature. A `bundle-apps` option
  (a protected script: its own approving issue) copies it into `PlugIns`.
  The same journeys then run and check the controls act, the denied one
  shows the policy's help, and undo after an AI result removes it.
- **Model tests (Linux, every `scripts/ci`).** Registry tests (first wins,
  conflicts recorded, policy fallback, unknown version skipped); the
  defaults' help strings; every app's tools test on defaults and fakes.
- **The closed modules** are tested in their own private repo against the
  conformance suites from `SuiteModelTests`, so a module that breaks a
  protocol fails there, not in the user's app.

## 8. Tasks (after BU-1)

| Id | What | Paths |
|---|---|---|
| ED-1 | Protocols, values, defaults, `SuiteEditions`, registry; tests | `Sources/SuiteModel/Editions/`, `Tests/SuiteModelTests/Editions*.swift`, `docs/c4/model.json` |
| ED-2 | Fakes and conformance suites | `Sources/SuiteModel/Fakes/Edition*.swift`, `Tests/SuiteModelTests/EditionConformance*.swift` |
| ED-3 | `EditionLoader` in SuiteShell; Settings ▸ About lines | `Sources/SuiteShell/Editions/` |
| ED-4 | Each app Model takes `SuiteEditions` and returns its help from `unavailableHelp(for:)`; tools test on defaults and fakes | one task per app line |
| ED-5 | `EditionsTestModule` and the `bundle-apps` option; journeys for both builds | `Tests/EditionsTestModule/`, `UITests/`, `scripts/bundle-apps` (approving issue) |
| ED-C1…6 | Section 6 rules 1–6 as `needs-core` issues on creative-core | creative-core |

## 9. Open questions for the captain

1. **Where AI-made content stands.** The core undoes it like any edit; does
   a document record that a step was AI-made (for example in its history)?
2. **Local co-editing.** Free in the core per the decision; when, and
   does it wait for Team's change format or set it?
3. **Protocol version policy.** How long the core keeps accepting an older
   `AfterGlowEditionProtocolVersion` after it moves.
