# Feature packet: file-flow

**Feature:** files move the way a Mac user expects, in every AfterGlow app.
Drop a file from Finder on any app or on the home: the app opens it, places
it (an image into Photo or Library), or hands it to the app that reads it.
Drag a Library photo or a Design selection onto another app. Every app's
File menu has Open Recent ▸ (this app's files from the one suite list, with
Clear Menu) and Open In ▸ (the other apps that read the document). The
suite already has the contracts (`RecentWork`, `DocumentRouting`,
`PasteboardCoding`, `HandOffSending`, `SuiteDocumentHost`); this packet adds
the one drop rule, the file commands, and the SuiteShell glue that every
app adds with two lines.
**Line:** `line:suite` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/file-flow`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 7: suite v1 rows
F6 and F7, which the beta cut had put out). Labels `beta` and `p0` when filed.

**Covers:** suite.md 1.4's v1 rows "Files and recents" and "Copy, paste,
drag" (F6, F7), the planned `shell-documents` component (suite.md 2.3:
`SuiteDocumentsBridge.swift`, `OpenInMenu.swift`), journeys SJ11
`testOpenIn` and SJ14 `testDragBetweenApps` with `DropRoutingTests` on
Linux; real job RJ-X43 (new). Five adopts, each its own packet on its line:
`design/file-flow`, `photo/file-flow`, `flare/file-flow`, `halo/file-flow`
and `library/file-flow`, each waiting on SF-a. Each adopt also covers its
app's open "adopt the suite" gap (#861 to #865: `SuiteDocumentHost` and
`.suiteApp`), since the drop and Open In run through that host.

**Depends on:** suite-contracts, switching and home (built). No
creative-core issue. Cross-line: SF-9 waits on suiteui `export-pack`'s XP-z
for `FakeCanvasDocument.swift`.

**Rule 20.** One recents list (`RecentsList`, `StoreRecents`), one routing
(`DocumentRouting`), one drop rule (`DropPlan`). Photo's, Flare's and Halo's
app-local Open Recent lists are deleted by their adopts and their entries
imported into the suite list once. **Where the drop rule lives:** the
command catalog is SuiteKernel's and SuiteKernel can't import SuiteModel, so
`DropPlan` and the file commands are a small kernel `Files/` module over
plain values (file names, app ids, a readers lookup); SuiteShell feeds it
from `DocumentRouting`, and each app's `<X>FileFlow+Kernel.swift` adapter
does the same for the CLI. Data drops that aren't files (a Design selection,
a colour) stay `PasteboardCoding.bestItem`'s, unchanged.

**C4:** new component parts `suite-kernel/kernel-files.json` (SF-1) and
`suite-shell/shell-documents.json` (SF-2), the latter as suite.md plans it.

**Clean-room.** The HIG's file management, drag and drop and menu bar
pages; no task reads another product's code.

Blueprint sections: suite.md 1.4 (v1 rows), 2.3 (`shell-documents`), 4.3
(SJ11, SJ14), 5.2 (pasteboard), 1.5 (commands).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SF-a | The kernel's drop rule and file commands exist as stubs, SuiteShell's menu group, drop modifier, drag source and documents bridge exist on the fakes, the home takes a drop and shows Open Recent, and the checks are written, disabled. | SF-1, SF-2 | SJ-F1 | targets, home, switching (built; they own HomeWindow.swift and plan OpenInMenu.swift) |
| SF-u | Open Recent lists the app's files newest first with Clear Menu, Open In lists the readers or says why not, and a drag over a window shows what the drop will do, every control identified, within the render budget. | SF-3, SF-4 | SJ-F1 (`SuiteFileFlowJourneyTests.testDropOnHomeAndOpenRecent`) | SF-a |
| SF-m | The drop rule opens, places, hands off or refuses each file, the file commands run on a target with the right why-nots, and the bridge records every open and save in the one list and opens a document in another app. | SF-5, SF-6, SF-7 | KJ-files, `SuiteDocumentsBridgeTests` (macOS) | SF-a |
| SF-z | Drops, drags, Open Recent and Open In run on live services from the home, the fake app takes `file.drop` so RJ-X43 runs on the CLI, and the feature is built. | SF-8, SF-9, SF-10 | SJ-F1, SJ11 (`testOpenIn`), SJ14 (`testDragBetweenApps`), KJ-files | SF-u, SF-m; afterglow-cli (built, `Tests/RealJobs/fake/`), suiteui export-pack:XP-z (SF-9, cross-line) |

SF-u waits only on SF-a (rule 18); SF-m never waits on SF-u. KJ-files is the
drop rule's and commands' Linux walk in `SuiteKernelTests`. SJ11 and SJ14
need two adopts live (Photo and Library); until then they run on the home
and the fake app, and each adopt's own journey covers its app.

## Journey steps

1. Launch AfterGlow with the `weekOfWork` fixture (SF-2,
   `SuiteFileFlowJourneyTests.testDropOnHomeAndOpenRecent`); File > Open
   Recent ▸ on the home lists the week's files across apps, newest first.
2. Drop `Intro.halo` from a helper window on the home: the drop mark reads
   "Open in Halo" while hovering (SF-3); on release Halo opens it (SF-8).
3. Drop `notes.xyz`: the mark reads "AfterGlow can't open .xyz files." and
   the drop does nothing.
4. In Photo with `Sunset.png`, File > Open In ▸ (SJ11 `testOpenIn`): Library
   only; pick it: Library imports and selects it. In Design, Open In is off
   with "No other app opens Design Document files."
5. Drag a Library thumbnail onto Photo's open image (SJ14
   `testDragBetweenApps`): a new layer named after the photo.
6. Open Recent > Clear Menu in Design: Design's files leave the list; the
   home still shows the other apps' files.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X43 | adds, closes with `suite/file-flow` | C | `Tests/RealJobs/fake/file-flow/file-flow.jobs.json`: `file.drop` with `Intro.halo`, `Sunset.png` and `notes.xyz` on the fake document, then `file.recent` | `input/one.fake`, the three files beside it |

Trap: a dropped document from another app opens here as an import (or as
text), a file nobody reads is silently ignored, or Open Recent lists every
app's files. Assertion: the drop's result is exactly `[{"path":
"Intro.halo", "action": "handOff", "app": "halo"}, {"path": "Sunset.png",
"action": "handOff", "app": "photo"}, {"path": "notes.xyz", "action":
"refuse", "reason": "AfterGlow can't open .xyz files."}]` (the fake reads no
images), and `file.recent` lists only the fake app's own entries. Mutations:
`SuiteKernel.DropPlan.json` (another app's native type placed instead of
handed off; the refusal dropped).

## Screens and states

`suite-open-recent` (the menu, light and dark), `suite-open-in-off` (the
reason), `suite-drop-mark-open`, `suite-drop-mark-refuse`.

## Contract slice

```swift
// Sources/SuiteKernel/Files/DropPlan.swift (SF-1 stub returning .refuse("Not built yet (SF-5)."), SF-5 body)
public enum DropAction: Hashable, Codable, Sendable {
    case open(path: String)                    // this app's own document: a window for it
    case place(path: String)                   // content this app takes into the open document (one "Place" step)
    case handOff(path: String, app: String)    // another app's document: that app opens it
    case refuse(path: String, reason: String)
}
public enum DropPlan {
    /// One action per path, in order. `readers(ext)` is the apps that read an extension, default first
    /// (DocumentRouting's answer); `places` the extensions this app takes into an open document.
    public static func plan(_ paths: [String], into app: String, hasDocument: Bool, places: Set<String>,
                            readers: (String) -> [String]) -> [DropAction]
}
// Sources/SuiteKernel/Files/FileFlowCommands.swift (SF-1 specs with real ids, schemas and availability, runs throwing
// `NotBuilt`; SF-6 bodies)
public struct RecentFileEntry: Hashable, Codable, Sendable { public let fileID, name, path, app: String; public let lastUsed: Date }
public protocol FileFlowTarget: Sendable {
    var appID: String { get }
    var recentFiles: [RecentFileEntry] { get }          // this app's, newest first
    var hasDocument: Bool { get }
    var placesExtensions: Set<String> { get }
    var openInApps: [String] { get }                    // the open document's readers, never this app
    var openInHelp: String? { get }                     // DocumentRouting.openInRefusal's sentence, or "Save <name> first."
    func readers(ofExtension ext: String) -> [String]
    mutating func openRecent(_ fileID: String) throws   // a missing file: removed from the list, and the error says so
    mutating func clearRecent() throws
    mutating func openIn(_ app: String) throws
    mutating func perform(_ actions: [DropAction]) throws
}
public enum FileFlowCommands { public static func specs<T: FileFlowTarget>(_ target: T.Type) -> [CommandSpec<T>] }
// Sources/SuiteShell/OpenInMenu.swift (SF-2 on fakes, SF-3 views)
public struct SuiteFileCommands: Commands { public init(app: SuiteApp, bridge: SuiteDocumentsBridge) }
// File > Open Recent ▸ (Clear Menu; "No Recent Files" when empty) and Open In ▸, after the app's Open… item
// Sources/SuiteShell/SuiteFileDrop.swift, SuiteDragSource.swift (SF-2 on fakes, SF-3 mark, SF-8 live)
extension View {
    public func suiteFileDrop(_ app: SuiteApp, bridge: SuiteDocumentsBridge, hasDocument: Bool,
                              places: Set<String>, perform: @escaping ([DropAction]) -> Void) -> some View
    public func suiteDraggable(_ item: @escaping () -> SuiteClipItem?) -> some View   // PasteboardCoding's representations
}
// Sources/SuiteShell/SuiteDocumentsBridge.swift (SF-2 stub over FakeRecents, SF-7 live)
@MainActor public final class SuiteDocumentsBridge {
    public func noted(_ ref: SuiteDocumentRef, _ event: RecentEvent)        // every open and save
    public func recents(for app: SuiteApp) -> [RecentFileEntry]
    public func openIn(_ ref: SuiteDocumentRef, app: SuiteApp) async throws(SuiteError)   // a hand-off, verb open
    public func readers(ofExtension ext: String) -> [String]
}
```

Commands (ids go in each adopter's `Tests/command-ids/<app>.txt`; Photo's
and Flare's existing `file.open-recent` and `file.clear-recent` become these
specs, so the ledger keeps the ids):

| id | kind | params | unavailable when |
|---|---|---|---|
| `file.recent` | query | – → `[{fileID, name, path, lastUsed}]` | – |
| `file.open-recent` | action | `{fileID}` | not in the list |
| `file.clear-recent` | action | – | the list is empty ("No Recent Files") |
| `file.open-in` | action | `{app}` | `openInHelp` |
| `file.drop` | action | `{paths: [..]}` → the actions taken | no paths |

## Pseudocode

- **plan.** Per path, by extension (lowercased): `readers(ext)` empty →
  refuse "AfterGlow can't open .<ext> files."; this app is the first reader
  (its own document type) → open; `hasDocument` and `ext ∈ places` → place;
  this app reads it but nothing is open → open; else hand off to the first
  reader. A folder → each file inside, one level, in name order.
- **commands.** Each runs the target's one method; `file.drop` runs
  `DropPlan.plan` with the target's values, then `perform` once (a place is
  one "Place" undo step however many files).
- **bridge.** `noted` → `RecentWork.note`; `recents(for:)` filters the list
  to the app, drops entries whose file is gone; `openIn` sends
  `HandOff(verb: .open)` through `HandOffSending`.
- **drop modifier.** On hover, plan the offered file URLs and show the first
  action as the mark ("Open in Halo", "Place in Sunset", or the reason);
  non-file data goes to `PasteboardCoding.bestItem` as today's paste does.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SF-1 | – | The kernel `Files/` module as stubs: `DropAction`, `DropPlan`, `RecentFileEntry`, `FileFlowTarget`, the five specs with ids, schemas and availability; the C4 part; the two suites written, disabled | `Sources/SuiteKernel/Files/DropPlan.swift`, `Sources/SuiteKernel/Files/FileFlowCommands.swift`, `Tests/SuiteKernelTests/DropRoutingTests.swift`, `Tests/SuiteKernelTests/FileFlowCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-files.json` | – | ~300, 5 |
| SF-2 | – | SuiteShell's `SuiteFileCommands`, `.suiteFileDrop`, `.suiteDraggable` and `SuiteDocumentsBridge` on the fakes; the home takes drops and shows Open Recent; the C4 part; the journey written and skipped (`XCTSkip("waits on SF-4")`) | `Sources/SuiteShell/OpenInMenu.swift`, `Sources/SuiteShell/SuiteFileDrop.swift`, `Sources/SuiteShell/SuiteDragSource.swift`, `Sources/SuiteShell/SuiteDocumentsBridge.swift`, `Sources/AfterGlowApp/HomeWindow.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-documents.json`, `UITests/SuiteJourneyTests+FileFlow.swift` | SF-1 | ~320, 7 |
| SF-3 | – | The views: Open Recent and Open In submenus with their empty and off states, the drop mark with its sentence, identifiers `suite.file.*` | `Sources/SuiteShell/OpenInMenu.swift`, `Sources/SuiteShell/SuiteFileDrop.swift`, `Tests/AppSnapshotTests/SuiteFileFlowViewTests.swift` | SF-2 | ~260, 3 |
| SF-4 | – | Snapshots, the render budget test, the journey turned on (on the fakes) | `Tests/AppSnapshotTests/SuiteFileFlowSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFileDropTests.swift`, `UITests/SuiteJourneyTests+FileFlow.swift` | SF-3 | ~200, 3 |
| SF-5 | – | `DropPlan.plan` body; turns on `DropRoutingTests` | `Sources/SuiteKernel/Files/DropPlan.swift`, `Tests/SuiteKernelTests/DropRoutingTests.swift`, `Tests/mutations/SuiteKernel.DropPlan.json` | SF-1 | ~200, 3 |
| SF-6 | – | `FileFlowCommands` bodies; turns on `FileFlowCommandsTests` on a test target | `Sources/SuiteKernel/Files/FileFlowCommands.swift`, `Tests/SuiteKernelTests/FileFlowCommandsTests.swift`, `Tests/mutations/SuiteKernel.FileFlowCommands.json` | SF-5 | ~220, 3 |
| SF-7 | – | `SuiteDocumentsBridge` live over `StoreRecents`, the routing slot and `HandOffTransport` | `Sources/SuiteShell/SuiteDocumentsBridge.swift`, `Tests/AppSnapshotTests/SuiteDocumentsBridgeTests.swift` | SF-2 | ~200, 2 |
| SF-8 | – | Live: the modifier performs its plan (open and place through the app's `SuiteDocumentHost`, hand-off through the bridge), the drag source writes `PasteboardCoding`'s representations; the journeys on live | `Sources/SuiteShell/SuiteFileDrop.swift`, `Sources/SuiteShell/SuiteDragSource.swift`, `Tests/AppSnapshotTests/SuiteFileDropLiveTests.swift` | SF-4, SF-5, SF-7 | ~240, 3 |
| SF-9 | – | The fake app conforms to `FileFlowTarget` over fixed readers and lists the specs; RJ-X43's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeCanvasFileFlowTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/file-flow/` | SF-6, export-pack:XP-z (cross-line) | ~180, 4 |
| SF-10 | – | The two C4 parts name the commands and the glue; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-files.json`, `docs/c4/parts/creative-apps/suite-shell/shell-documents.json`, `docs/blueprints/suite/features/file-flow.wave.json` | SF-8, SF-9 | ~30, 3 |

SF-1 declares every rule and spec so SF-5 and SF-6 each fill one file. No
`suite.md` edit: its v1 rows already describe this, and the C4 parts carry
the components.

## Build waves

- Wave 1: SF-1. Independent in this wave: SF-1 alone.
- Wave 2: SF-2, SF-5. Independent in this wave: both.
- Wave 3: SF-3, SF-6, SF-7. Independent in this wave: all three.
- Wave 4: SF-4, SF-9. Independent in this wave: both.
- Wave 5: SF-8. Independent in this wave: SF-8 alone.
- Wave 6: SF-10 (`feature-done`, final). Independent in this wave: SF-10 alone.

Longest chain: SF-1 → SF-2 → SF-3 → SF-4 → SF-8 → SF-10 (6). Chain of 6: the shell glue needs the kernel's types, the views fill the stubs, the budget and journey time them, the live drop performs under the journey, and SF-10 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| SF-1 | the two suites compile, disabled by name; `KernelShapeTests` passes over `Files/` | the module imports SuiteModel | – (stubs) |
| SF-2 | SJ-F1 step 1 (skipped until SF-4) compiles; the home builds with the menu and modifier | the home doesn't build | – (UI) |
| SF-3 | `SuiteFileFlowViewTests`: an empty list shows "No Recent Files" disabled; Open In with no readers is off with its sentence; the mark shows the first action's sentence | a state or a sentence is wrong | – (UI) |
| SF-4 | `SuiteFileFlowSnapshots`; `RenderBudgetFileDropTests.dragHoverInTwoBodies`; `testDropOnHomeAndOpenRecent` steps 1 to 3 on the fakes | budget over, or a step fails | – (UI) |
| SF-5 | `DropRoutingTests`: `.halo` on Design hands off to Halo; `.png` on Photo with a document places, without one opens; `.png` on Library places (imports); `.xyz` is refused with its sentence; a folder expands one level in name order; `.HALO` routes like `.halo` | an action or a sentence is wrong | `SuiteKernel.DropPlan`: own type placed instead of opened → `.ownTypeOpens`; another app's type placed → `.othersHandOff`; extension not lowercased → `.caseInsensitive` |
| SF-6 | `FileFlowCommandsTests`: `file.drop` performs once with the plan; `file.open-in` with help is unavailable with it; `file.clear-recent` on an empty list is unavailable; `file.open-recent` of a missing file removes it and says so | a command runs twice or a why-not is missing | `SuiteKernel.FileFlowCommands`: perform called per path → `.dropPerformsOnce`; help ignored → `.openInSaysWhy` |
| SF-7 | `SuiteDocumentsBridgeTests` (macOS): an open and a save note two events; `recents(for: .design)` lists only Design's and drops a deleted file; `openIn` sends one hand-off with verb open | an event is lost or another app's file shows | – (macOS) |
| SF-8 | `SuiteFileDropLiveTests`: a dropped `.halo` reaches the hand-off transport; a Library thumbnail drag offers the suite envelope, PNG and the file URL; SJ-F1, SJ11 and SJ14 on live (SJ11 and SJ14 once two adopts are live) | a drop does nothing or a representation is missing | – (UI) |
| SF-9 | `FakeCanvasFileFlowTests`: the fake's drop returns RJ-X43's actions; old jobs unchanged; RJ-X43 passes on Linux | an action or an old job changes | `SuiteKernel.FakeCanvasDocument`: readers ignored (everything refused) → `.handsOff` |
| SF-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: a drag hovering over a window, 120 moves | ≤ 2 window bodies (the mark changes once) | `RenderBudgetFileDropTests.dragHoverInTwoBodies` |
| Drop latency | release to the hand-off sent ≤ 100 ms (reported) | `SuiteFileDropLiveTests.latency` |
| No dead controls | Open Recent and Open In say why when off | `SuiteFileFlowViewTests` |
| Keyboard parity | both submenus reachable from the menu bar with the keyboard | `testDropOnHomeAndOpenRecent` |
| Audit | zero new over the suite baseline | `audit-suite-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): SF-m merged-done on the Linux job with
`Mutate:` clean and `SuiteDocumentsBridgeTests` green on macOS; SF-u's feel
gate and `Mac-Finish:`; SF-z's journeys on live and RJ-X43 green in the Linux
job. Then `Belt-Contact-Sheet:` with `suite-open-recent-*`, `suite-drop-mark-*`.

## Adopted by

`design/file-flow` (Open Recent for the first time, drop, drag a selection
out), `photo/file-flow`, `flare/file-flow` and `halo/file-flow` (their own
recents replaced by the suite list, drop, Open In), `library/file-flow` (drop
to import, drag thumbnails out). Each waits on SF-a and runs its UI on these
stubs.

## Not in this packet

Quick Look previews and Spotlight importers (suite.md lists them for later),
Halo layers to Flare and back, pasting Photo layers with masks into other
apps, a recents search field in each app (the home has one), Settings.
