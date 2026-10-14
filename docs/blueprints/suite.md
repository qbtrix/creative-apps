# AfterGlow suite blueprint

AfterGlow is the one app people install. Inside it live the five apps of the
suite: Flare (2D animation), Design (vector and UI design), Photo (raster
editing), Library (photo catalog) and Halo (motion graphics). This blueprint
designs the shell around them and the connections between them: how they are
packaged, how a person starts and switches, and how work moves from one app
to another. The five app blueprints design the apps themselves; where this
one needs something from them, it says so by name (section 8.4).

The captain's decision (2026-10-14): AfterGlow ships as ONE app, "AfterGlow",
with the five apps inside. Switching between them is instant, and they work
together the way a well-made family of system apps does.

This is the gate before code. Nothing here is built yet. Feature packets
(`docs/blueprints/suite/features/`) come after the captain approves it.

Read on 2026-10-14: creative-apps `origin/dev` 4594082, the open app
blueprint PRs at their heads (#765 SuiteUI `dcc69b6`, #766 Design `c777402`,
#767 Halo `b829271`, #768 Photo `51989df`, #769 Library `fbe4193`), the Flare
blueprint on dev (`docs/blueprints/flare.md`), and every open issue in this
repo (169). creative-core was read only through what this repo's docs and
those blueprints say about it; core issues are named as they cite them.
Platform facts were checked with the `apple-docs` MCP tools (cited inline as
"Apple docs: <page>"); the `context7` tools answered "monthly quota
exceeded", so SwiftPM linking behavior is marked for the spike in section
2.5 instead of taken from docs.

Contents: 0 Status on dev · 1 Brief · 2 Pseudo-C4 and packaging · 3 Usage
map · 4 Journeys · 5 Contracts · 6 Look · 7 Quality bar · 8 Coverage and
waves · 9 Decisions for the captain · 10 Critic rounds

Files: this document; `docs/blueprints/suite/c4-planned.json` (section 2 as
data); `docs/blueprints/suite/contracts/` (section 5 as Swift that compiles
on Linux, with `check.sh`).

---

## 0. Status on dev (2026-10-14)

### 0.1 What exists

| Area | On dev today | Where |
|---|---|---|
| Packaging | Five separate bundles, `.build/apps/<X>App.app`, from one `swift build -c release`; each executable statically links its Model, SuiteUI and the creative-core engines it uses. Placeholder ids `org.creativesuite.<x>`. Info.plist has id, name, minimum macOS 26.0 and principal class only: no icon, no document types, no exported types, no entitlements. Ad-hoc signed (`codesign -s -`), checked with `plutil -lint` and `codesign --verify --deep --strict`, tarred as `app-builds.tar.gz` (2.4 MB when it shipped in PR #75) | `scripts/bundle-apps`, `.github/workflows/ci.yml` (`macos` job) |
| Binary size | Each release executable is 2.9 to 5.8 MB and repeats about 4,300 SuiteUI symbols (captain's measurement, 2026-10-14). SuiteUI is 36 files, 4,512 lines. Nothing in CI measures size | `Sources/SuiteUI/` |
| Targets | `<X>Model` (Linux + macOS), `<X>App` (macOS executable), `SuiteUI`, their tests, `AppAuditTests`. No suite-level target | `Package.swift` |
| Scenes | Each app is one `WindowGroup`. No `DocumentGroup`, `Settings`, `Window`, `MenuBarExtra` or app delegate anywhere. Menus reach the front window through focused scene values | `Sources/<X>App/<X>App.swift` |
| Files | Design: `.design` JSON, `NSOpenPanel`/`NSSavePanel`, `UTType(filenameExtension: "design")`. Photo: PNG, JPEG, HEIC through ImageIO, drop a file URL on the canvas. Flare: `FlareWorkspace` open and save API, a 10-item in-memory recent list, autosave due time, and `FlareAutosave` (recovery file, restore offer) written but not wired to the window (F17c #393 wires it). Halo and Library: nothing on disk | `DesignWindow.swift:45`, `PhotoEditor.swift:170`, `FlareFiles.swift`, `FlareAutosave.swift` |
| Launch arguments | `-DesignOpenFile`, `-DesignSaveTo`, `-PhotoOpenFile`, `-PhotoSaveTo`, `-PhotoExportTo`, read through `UserDefaults.standard`. Flare's `-Flare*` flags are designed (flare.md section 6.3) but not read yet | `DesignWindow.swift:143`, `PhotoWindow.swift:14` |
| Pasteboard | No `NSPasteboard` code. Flare's model copies `AddLayer` command envelopes as `Data`; Design's blueprint plans the type `org.creativesuite.design.layers` | `FlareEdit.swift:29`, PR #766 section 5.4 |
| Colours and swatches | One accent for every app (`SuitePalette.accent` #1877F2). Flare swatches live inside a Flare document (`LibraryManaging`); Design has `DesignColor` and no swatch list | `Tokens.swift`, `Contracts/LibraryContracts.swift` |
| Journeys | One XCUITest bundle per app in `project.yml`, each launching `.build/apps/<X>App.app` by path with `-ApplePersistenceIgnoreState YES`; the app audit runs on every shot against `UITests/audit-baseline.json` | `UITests/Journey.swift:30-44` |
| Probe | `FrameProbe`, `suite.perf` and `suite.controls` are designed (review rubric section 6, SuiteUI QH-1 #330) but not built; `UITests/Journey+Budgets.swift` and `Journey+Input.swift` do not exist | `docs/review-rubric.md` |

### 0.2 What the five app blueprints say about the suite

None of the five plans a launcher, app switcher, shared settings, onboarding,
updater, Dock icons, bundle ids, a shared asset or colour library, or binary
size. So this blueprint overlaps no owned file of theirs. What they do say:

| Blueprint | What touches the suite | Where |
|---|---|---|
| Photo #768 | v2 document is OpenRaster `.ora`; per-app Open Recent from the system list; autosave and restore offer in v2; pastes an image from the general pasteboard as a new image or layer (PV-2, `PhotoPasteboard.swift`). Q7: "Double-clicking an `.ora` in Finder … needs an exported type in Info.plist (`scripts/bundle-apps`, protected)." Q6 holds #274 | photo.md sections 5.1, 9 |
| Design #766 | `.design` JSON, one window per file; no Open Recent; autosave out of v1 (Q4); pasteboard type `org.creativesuite.design.layers` through `DesignPasteboardBridge.swift`; "a shared library across files" is tier 3 | design.md sections 1, 5.4, 9 |
| Halo #767 | `.halo` JSON, one project per window, its own model-held Open Recent (`HaloRecentFile`), `HaloDocumentType.swift` holds the UTType; "Flare scenes as layers (H10)" is Later; cites the suite plan in creative-core `docs/design/suite.md` | halo.md sections 1, 2 |
| Library #769 | One catalog in `Application Support/Library/catalog.json`, one `Window` scene; "round trip to Photo is later, section 1.4"; no Settings window in v1 | library.md sections 1.1, 1.4, 6.2 |
| SuiteUI #765 | No launcher, switcher, settings, onboarding or recents components planned; #274 (shared open and save panels) and #7 (command palette) are not v1; a gallery app target "needs `Package.swift` and `scripts/bundle-apps` (both protected)" | suiteui.md sections 0.3, 1, 9 |
| Flare (dev) | Recovery file and Open Recent in v1; "the shared suite library" and asset import (G51) are Later | flare.md sections 1, 9 |

The blueprints disagree on recents and recovery (Flare and Photo recover,
Design and Halo don't in v1; Photo uses the system recent list, Halo its
own, Design none). Section 1.4 sets one suite policy; section 8.4 lists what
each app adopts and when.

### 0.3 Open issues that touch packaging, launching or moving work

No open issue covers packaging for release, a launcher, Dock icons, document
type declarations, hand-offs between apps, a shared asset or colour library,
a settings window, onboarding or an updater. These touch the edges:

| Issue | What it asks | Relation |
|---|---|---|
| #274 | Share open/save panel plumbing (p3, line:suiteui) | Held by Photo Q6 and SuiteUI; recents-open-in builds on whatever lands |
| #415 | Design: cut, copy, paste layers, also between files (p1) | First pasteboard type; clipboard-drag adds cross-app representations |
| #384 | Flare F18: Edit menu and pasteboard (p1) | Second pasteboard type |
| #205, #209 | Save to `.flare`; Halo save and open (p1) | Feed the shared recents list |
| #212, #210, #424 | Library persist, import, export (p1) | Photo round trip reads and writes through these |
| #754, #393, #392 | Flare never-lose-work feature, recovery offer, open errors | The suite's recovery policy copies Flare's |
| #346, #347, #399 | Flare onto `EditorShell`, `suite.controls`, no-argument live launch | The launcher starts every app with no arguments |
| #7 | Command palette (p3) | Not v1 (SuiteUI agrees) |
| #20, #21, #380, #387, #363, #349 | Design variables and wide gamut; Flare swatches | The shared colour library sits beside them |
| #275, closed #133 | Menu and undo routing, menus with no window | Suite commands must work with no window open |
| #330, #331, #332, #333 | FrameProbe, goldens, snapshot host, journey helpers | Every suite budget is read from the probe |
| #215 → #579 (closed by PR #715) | Window minimum 880 pt, launch 1000 × 640 | The home window uses the same minimum |
| #763 | dev is red (macOS job, mac-platform range) | Blocker outside the ranking (priorities.md rule 4) |

### 0.4 What is missing

Everything this blueprint designs: the AfterGlow bundle and its launcher
process; shared frameworks; document and exported type declarations; app
icons; the home window; switching; one recents list; Open In; typed
pasteboard and drag data between apps; hand-offs; the Library to Photo round
trip; the shared asset and colour library; linked placement; Flare
animations in Halo; one settings window; one onboarding; one updater; size
measured in CI. Also a line for this work: there is no `line:suite` label,
and no target for code shared by the five apps that is not design system.

---

## 1. Brief

### 1.1 The problem

Five separate apps feel like five downloads, five Dock icons that don't know
each other, and five places to look for last week's work. A person who
culls photos in Library and wants to retouch one in Photo, or who draws a
logo in Design and wants it moving in Flare, today has to export a file,
find it, and import it, and the result has no memory of where it came from.
Each binary also carries its own copy of the design system and the engines.

AfterGlow fixes that with one install, one home, and connections that carry
typed data and links instead of loose files.

### 1.2 Who uses it

| Person | What they do across apps | What they need most |
|---|---|---|
| Hobby photographer (Library's main user) | Cull and develop in Library; open one photo in Photo for a deep fix; see the result back in the catalog | Round trip that never loses the original and lands the edit next to it |
| Designer-animator | Draw in Design; animate in Flare; composite with titles in Halo | Paste and place vector art with its colours intact, and keep it linked so a fix in Design reaches the animation |
| Everyone, every session | Start the suite, find recent work, start something new, switch apps | Instant switching, one recents list, no app forgetting where it was |

### 1.3 Non-goals

- Merging the five apps into one window or one menu bar. Each app keeps its
  own windows, menu bar, Dock icon and file types.
- Cloud sync, accounts, collaboration, or sharing to web services.
- A plugin API, scripting, or automation actions.
- Opening or writing closed file formats of other vendors.
- An iPad or iPhone build.
- A store-distributed sandboxed build in v1 (section 9, Q3).

### 1.4 The v1 line

| Area | In v1 | Out of v1 (later) |
|---|---|---|
| Packaging | One `AfterGlow.app` holding the launcher and the five apps as embedded app bundles; SuiteUI, the suite model and shell, and the engines linked once as shared frameworks in `AfterGlow.app/Contents/Frameworks`; each app keeps its own Dock icon, menu bar, windows and file types; document and exported types declared in the bundle; size measured and budgeted in CI | Notarized Developer ID release, delta updates, size optimization beyond the split (section 7.5) |
| Home | The AfterGlow home window: New by type (five tiles plus each app's presets), one recents list across all apps with thumbnails, search and an app filter, the running apps with a switch button | Pinned projects, folders of mixed work, tags |
| Switching | Window > Switch To (⌃⌘0 home, ⌃⌘1 to ⌃⌘5 the apps) in every app, also from the home; a running app comes forward with its windows as left; apps stay running when their last window closes; relaunch restores windows | Prewarming apps at login (section 9, Q5) |
| Files and recents | One recents list written by every app on open and save, shown in the home and in each app's File > Open Recent (filtered to that app); Finder double-click opens the right app; File > Open In ▸ (the apps that read this document) | Quick Look previews, Spotlight importers |
| Recovery policy | Every document app autosaves to a recovery file and offers a restore at next launch (Flare's mac-platform design, shared as the suite rule); each app adopts it on its own line | Version browser |
| Copy, paste, drag | Typed pasteboard and drag data between apps: colours everywhere; vector art Design ↔ Flare (as SVG plus the suite asset envelope); images into Photo and Library; plain text where text is accepted; files dropped on any app or the home open in the right app | Halo layers to Flare and back, pasting Photo layers with masks into other apps |
| Library ↔ Photo | Edit in Photo from Library; Photo opens the photo as a new document tied to the round trip; Save in Photo returns an edited copy to Library, stacked beside the original; the original is never changed | Develop settings carried into Photo as adjustment layers |
| Shared assets and colours | One asset library (colours, vector art, images, animations) in the home's Assets page and in each app's colour popover; add from any app; place into any app that reads that kind | Tags, smart folders, gradients and text styles as assets |
| Linked placement | Placing a Design asset in Flare or Halo keeps a link: an "Update available" mark when the asset changes; Update replaces it in one undo step; a missing source keeps the last copy | Live (unprompted) updates, editing the source in place from Flare |
| Flare in Halo | Open In ▸ Halo on a `.flare` makes a composition the scene's size, rate and length with one animation layer linked to the file | Several scenes, nested Halo comps from Flare symbols, time remapping |
| Settings | One Settings window in the launcher (⌘, from any app opens it at that app's pane): General (units, autosave interval, check for updates), one pane per app | Per-document defaults, keyboard shortcut editor |
| Onboarding | First launch of AfterGlow: three pages (the five apps, what you do most, open a sample), skippable, never again unless reset from Settings | Interactive tutorials inside the apps |
| Updater | One updater in the launcher: check (daily and on demand), show what's new, download, verify the signature, ask the running apps to quit (each runs its unsaved-changes flow), replace `AfterGlow.app`, relaunch | Background silent install, beta channel |

**The line in one sentence:** a person installs one app, opens it, finds
yesterday's work from any of the five apps in one list, moves between apps
with one keystroke without losing anything, and moves a photo, a colour or
a drawing to another app in a way that remembers where it came from.

Checklist:

- [x] Every bullet in the captain's brief (packaging, home, connections, one
      updater, settings, onboarding, size) has an "In v1" row.
- [x] Every non-goal names a behavior, not another company's product.
- [x] Every "out" item names where it goes (later).

---

## 2. Pseudo-C4 and packaging (drawn before code)

Marked **existing** when a path is on `origin/dev` 4594082, **planned**
otherwise. The same model as data is `docs/blueprints/suite/c4-planned.json`
(shape of `docs/c4/model.json`, each element with `status` and
`authored: true`). It is not read by `scripts/ci`; `docs/c4/model.json`
stays the gate, and task BU-1 (section 8) copies the planned containers into
it when the targets are created.

### 2.1 L1: the system

```
person ──uses──▶ AfterGlow.app (macOS) ──links once──▶ shared frameworks
                     │  launcher process: home, settings, onboarding, updater, file router
                     ├─ Flare.app   ┐
                     ├─ Design.app  │ embedded app bundles, one process each,
                     ├─ Photo.app   │ own Dock icon, menu bar, windows, file types
                     ├─ Library.app │
                     └─ Halo.app    ┘
                 all six processes ◀──▶ the suite store (~/Library/Application Support/AfterGlow)
                                    ◀──▶ the system pasteboard, Launch Services, distributed notifications
creative-core (FlareCore, CoreRaster, CoreColor) ◀── the Models, linked once as one shared engine framework
```

### 2.2 L2: containers

| Container | Status | Responsibility | Owned paths | Line |
|---|---|---|---|---|
| `SuiteModel` | planned | Linux-safe values, contracts, fakes and pure logic for everything shared between apps: app identity and type registry, document references, recents, routing, hand-offs, round trips, pasteboard coding, assets and links, preferences, onboarding, update feed, size budget. Foundation only; no engine import | `Sources/SuiteModel/` | `line:suite` |
| `SuiteShell` | planned | macOS glue every app process links: live conformances that need AppKit or Launch Services (open an app, hand-off transport, pasteboard and drag bridges, store change notifications, thumbnail writer), the shared menu commands (Switch To, Open In, Settings route) and the one modifier each app adds to its scene | `Sources/SuiteShell/` | `line:suite` |
| `AfterGlowApp` | planned | The launcher executable, `AfterGlow.app/Contents/MacOS/AfterGlow`: home window, Assets page, Settings scene, onboarding, updater, and the file router for document types | `Sources/AfterGlowApp/` | `line:suite` |
| AfterGlow bundle | planned | The packaged artifact and its inputs: Info.plists with document and exported types, icons, entitlements, the release build graph | `Bundle/` (plists, icons), the release section of `project.yml`, `scripts/bundle-apps`, `scripts/size-report` | `line:suite` (protected paths: supervisor merges) |
| `SuiteModelTests` | planned | Model tests, contract conformance suites against fakes and live stores, model budgets, registry-vs-plist checks | `Tests/SuiteModelTests/` | `line:suite` |
| AfterGlow journeys | planned | XCUITest bundle `AfterGlowJourneyTests` that drives the launcher and, through it, the apps | `UITests/AfterGlowJourneyTests*.swift` | `line:suite` |
| `SuiteUI` | existing | Design system; gains the home and settings parts listed in section 6.3 through `needs-ui` issues | `Sources/SuiteUI/` | `line:suiteui` |
| `<X>App`, `<X>Model` (×5) | existing | The apps. Each adopts the suite with small tasks on its own line (section 8.4): one modifier in `<X>App.swift`, its document kinds and pasteboard representations in `<X>Model` | `Sources/<X>App/`, `Sources/<X>Model/` | `line:<x>` |
| creative-core engines | existing (external) | FlareCore, CoreRaster, CoreColor; the suite asset model tasks (creative-core #148–#154, p3 today) | qbtrix/creative-core | `needs-core` |

Each `<X>Model` gains one dependency, `SuiteModel` (Foundation only, so the
Linux build stays as fast as today). `SuiteModel` never imports an app
Model or an engine: the apps convert between their own types and the suite's
values, so a shared store never needs to load five engines.

### 2.3 L3: components

**SuiteModel** (`Sources/SuiteModel/`, all planned)

| Component | Responsibility | Paths | Relationships |
|---|---|---|---|
| suite-identity | `SuiteApp` (the five apps plus the launcher), bundle ids, the one id prefix, and `SuiteTypeRegistry`: every document and pasteboard type each app reads and writes, with the default app per type | `Values/` | used by every other component; mirrored by `Bundle/Info/*.plist` (checked by a test) |
| suite-store | `SuiteLocations` (the support folder, overridable with `-SuiteSupportDir`), `FileStore`: JSON files written atomically with a revision number; a write against a stale revision re-reads and merges | `Store/` | used by recents, assets, preferences, hand-offs |
| suite-contracts | One protocol per use case (section 5) | `Contracts/` | implemented by fakes, stores and SuiteShell's live types |
| suite-fakes | A fake per contract with `unavailable:`; fixtures (`SuiteFixtures`: empty, week of work, round trip, assets) | `Fakes/` | used by snapshots, journeys, the apps' fake services |
| suite-services | `SuiteServices` with `.fake` and `.live` slots | `SuiteServices.swift` | assembled live in SuiteShell |
| suite-recents | `RecentsList` (merge, dedupe by file identity, cap 200, filter by app, search), recording rules | `Recents/` | store; home; each app's Open Recent |
| suite-routing | Which app opens a type, the Open In list for a document, Finder routing decisions | `Routing/` | registry; launcher router; Open In menu |
| suite-handoff | `HandOff` values (verb, payload, return address), codec and lifecycle | `HandOff/` | transport in SuiteShell; round trip; new document |
| suite-switching | Switch requests and receipts, run states, the Switch To menu model | `Switching/` | SuiteShell launcher; home |
| suite-home | Home state: new tiles and presets, recents grid sections, running apps strip, `HomeLayout` column math | `Home/` | AfterGlowApp home views |
| suite-pasteboard | `SuiteClipItem` and its typed representations; best-item choice for a target app | `Pasteboard/` | SuiteShell bridges; each app's paste |
| suite-roundtrip | Library → Photo → Library sessions and their states | `RoundTrip/` | hand-off; Library and Photo adoption |
| suite-assets | `SuiteAsset`, colours, the asset index (add, update with revision, remove, search) | `Assets/` | store; Assets page; each app's colour popover |
| suite-links | `AssetLink` and its status (current, update available, missing) | `Links/` | assets; Flare and Halo adoption |
| suite-animation | `AnimationSummary` of a `.flare` for Halo's import | `Animation/` | Halo adoption |
| suite-preferences | `SuitePreferences` (General plus a pane per app), defaults, change records | `Preferences/` | store; Settings scene; every app |
| suite-onboarding | Pages, choices, when to show | `Onboarding/` | AfterGlowApp |
| suite-update | Update feed parsing, version compare, offer, install plan | `Update/` | AfterGlowApp updater |
| suite-packaging | `BundleLayout` (where each executable and framework sits, the rpaths), `SizeReport` and `SizeBudget` with their evaluation | `Packaging/` | `scripts/size-report` output; CI |

**SuiteShell** (`Sources/SuiteShell/`, macOS, all planned)

| Component | Responsibility | Paths |
|---|---|---|
| shell-live | `SuiteServices.live` and one slot file per member (each feature swaps its own) | `SuiteServices+Live.swift`, `Live/` |
| shell-apps | Open or activate an app (`NSWorkspace.openApplication(at:configuration:)`, `NSRunningApplication.activate`), run states, the Switch To commands | `AppLauncher.swift`, `SuiteCommands.swift` |
| shell-handoff | Write a hand-off file and open it with the target app (`NSWorkspace.open(_:withApplicationAt:configuration:)`); receive one in `onOpenURL` | `HandOffTransport.swift` |
| shell-store-watch | Post and observe `DistributedNotificationCenter` changes for recents, assets and preferences | `StoreWatcher.swift` |
| shell-pasteboard | Map `SuiteClipItem` to `NSPasteboard` items and drag providers, and back | `PasteboardBridge.swift`, `DragBridge.swift` |
| shell-documents | Record opens and saves into recents, write thumbnails, the Open In submenu | `SuiteDocumentsBridge.swift`, `ThumbnailWriter.swift`, `OpenInMenu.swift` |
| shell-adoption | `.suiteApp(_:)`: the one modifier an app adds to its scene (installs the commands, the hand-off receiver, the store watcher, and the settings route) | `SuiteAppModifier.swift`, `SettingsRoute.swift` |

**AfterGlowApp** (`Sources/AfterGlowApp/`, macOS, all planned)

| Component | Responsibility | Paths |
|---|---|---|
| launcher-scene | `@main AfterGlowApp`: the home `Window`, the `Settings` scene, the onboarding window; an app delegate that routes opened files to the right app | `AfterGlowApp.swift`, `LauncherRouter.swift` |
| home | The home window: New tiles, recents grid, search, app filter, running apps strip | `Home*.swift` |
| assets-page | The Assets page of the home sidebar | `Assets*.swift` |
| settings | General and per-app panes | `Settings*.swift` |
| onboarding | The three first-launch pages | `Onboarding*.swift` |
| updater | Check, offer sheet, progress, install | `Update*.swift` |

### 2.4 Relationships

| From | To | What |
|---|---|---|
| each `<X>Model` | SuiteModel | declares its document kinds and pasteboard representations; reads preferences |
| each `<X>App` | SuiteShell | `.suiteApp(.<x>)` on its scene; Open In and Switch To menus; records recents |
| AfterGlowApp | SuiteShell, SuiteModel, SuiteUI | home, settings, onboarding, updater |
| SuiteShell | SuiteModel, SuiteUI | live conformances; menu commands built from SuiteUI parts |
| every process | suite store | JSON files under `~/Library/Application Support/AfterGlow/` |
| every process | each other | hand-off files opened with the target app; distributed notifications for store changes; the system pasteboard |
| `<X>Model` | creative-core | unchanged, but linked through one shared engine framework (2.5) |

### 2.5 Packaging: one process or six

The captain's brief requires three things at once: one bundle; each app keeps
its own Dock icon, windows and file types; switching is instant. Two shapes
can give one bundle:

| | A: one process, per-app scenes | B: embedded app bundles, one process each (chosen) |
|---|---|---|
| Layout | `AfterGlow.app/Contents/MacOS/AfterGlow` holds all five apps as scenes | `AfterGlow.app/Contents/Helpers/<X>.app` (Apple docs: "Placing content in a bundle", help apps and helper tools go in `Contents/Helpers/`); frameworks in `AfterGlow.app/Contents/Frameworks/` |
| Own Dock icon per app | **No.** One process is one Dock tile; it could only swap its icon as the front app changes | Yes: each process has its tile, its Command-Tab entry, its "Keep in Dock" |
| Own menu bar | One menu bar re-keyed by the focused scene; the app menu always reads "AfterGlow" | Yes, natively: the Flare menu bar reads "Flare" |
| Own file types | One bundle declares all types and routes to scenes | Each embedded app declares its own; the outer bundle also declares them and routes (2.6), so Finder works even if Launch Services does not index nested bundles |
| Switching an app that is running | A scene comes forward: ~1 frame | The process activates: no launch; measured by QB-S1 (section 7) |
| First open of an app | A scene opens: no launch | A cold process launch; QB-S2 budgets it, and apps stay running after their last window closes so it happens once per session |
| Shared code | Linked once by construction | Linked once only if built as frameworks (below) |
| Memory | One heap; closing an app frees little | Five heaps, but framework code pages are file-backed and shared between processes; quitting an app frees all of it |
| A crash | Takes every app and every unsaved document down | Takes one app; the others keep running |
| Cross-app data | In memory | Pasteboard, hand-off files, the suite store (2.6) |
| Today's code | Five `@main` apps must become scene libraries; five sets of `Commands` must merge into one menu bar; focused values must be scoped per app | The five `@main` apps stay as they are; each adds one modifier |
| UI journeys | One XCUIApplication for everything | One per app, as today (`UITests/Journey.swift` launches a bundle by path) plus the launcher's |

**Pick B.** It is the only shape that meets "each app keeps its own Dock
icon" without faking it, it keeps a crash in one app from losing work in
four others, and it changes almost nothing in today's five apps. Its two
costs are paid for explicitly: code is linked once as frameworks (below),
and the first open of each app per session is a cold launch with its own
budget, after which switching is an activation.

**Measured so far.** On Linux (this session, swift 6.3.3, `swift build -c
release` of every Model target at 4594082 and creative-core `main`), the
engine object code each app carries is:
| Engine (creative-core `cfad97f`) | Code (`size` text, KB) | Linked into today | Copies today | Copies after the split |
|---|---|---|---|---|
| FlareCore | 894 | Flare, Halo | 2 | 1 |
| CoreRaster | 121 | Photo, Library, Halo | 3 | 1 |
| CoreColor | 18 | Design, Photo, Library | 3 | 1 |
| Total | | | 2,205 KB | 1,033 KB |

So the engines alone repeat about 1.2 MB of code across the five
executables on Linux x86_64 (Mach-O arm64 differs; BU-0 measures it). For
scale, the app Models compile to 741 KB (Flare), 234 (Design), 215
(Photo), 69 (Library) and 85 (Halo) of code, and each is used by one app
only, so they stay inside their app. creative-core `main` also has
`CoreAsset` and `CoreCatalog` modules, each holding only an error type
today (`AssetError.swift`, `CatalogError.swift`).
The macOS numbers (per-executable size, duplicated SuiteUI symbols, cold
launch and activation times, resident memory) are measured by task BU-0 on
the macOS runner before any packaging change lands, and recorded in that
task's PR; the gates in section 7 start report-only from those numbers.

**Shared frameworks: how.** SwiftPM links a library target into an
executable of the same package statically, and a package cannot depend on
its own products, so `Package.swift` alone cannot make SuiteUI a shared
framework without moving its sources into a second package (which would
rename every SuiteUI path that six lines are editing). Two routes:

| Route | What changes | Risk |
|---|---|---|
| R1 (chosen): the release graph in `project.yml` | XcodeGen already builds the journey bundles. A `Release` section adds framework targets compiled from the existing folders: `SuiteUI.framework` (`Sources/SuiteUI`), `SuiteModel.framework`, `SuiteShell.framework`, and `CreativeEngines.framework` (one source file, `Bundle/Engines/CreativeEngines.swift`, that re-exports FlareCore, CoreRaster and CoreColor, and is the only target that links the creative-core package products). Each `<X>Model` becomes a static library that links `CreativeEngines`; each `<X>App` an application target with `@executable_path/../../../../Frameworks` on its run path. `Package.swift` keeps its Linux and test graph; no source path moves | Two build descriptions can drift: `BuildGraphTests` (Linux, `Tests/SuiteModelTests`) reads both files and fails when a target in one is missing from the other. Model sources import FlareCore through the re-export: BU-0 proves it builds |
| R2: second package | `Packages/Shared/Package.swift` with `.dynamic` products; SuiteUI sources move there | Renames every SuiteUI path mid-flight (six open blueprints plan edits there); C4, the design lint and the app-state rule move with it |

If BU-0 shows R1 cannot link the engines once (for example a module that
will not re-export), the fallback is "needs a new core issue": creative-core
declares `.library(name: "CreativeEngines", type: .dynamic, targets:
["FlareCore", "CoreRaster", "CoreColor"])`, and the apps' release graph
links that product instead of the re-export file.

**Changes this needs** (every one is a protected path, so each task is
marked "supervisor merges" in section 8):

1. `Package.swift`: add `SuiteModel` and `SuiteModelTests` (all platforms),
   `SuiteShell` and the `AfterGlowApp` executable (macOS); `model()` adds
   `"SuiteModel"` to every `<X>Model`; every `<X>App` adds `"SuiteShell"`;
   `AppSnapshotTests` adds `AfterGlowApp` and `SuiteShell`. Shape:
   ```swift
   let suite: [Target] = [
       .target(name: "SuiteModel"),
       .testTarget(name: "SuiteModelTests", dependencies: ["SuiteModel"]),
   ]
   func model(_ name: String, _ engines: [String]) -> [Target] {
       [
           .target(name: "\(name)Model",
                   dependencies: ["SuiteModel"] + engines.map { .product(name: $0, package: core) }),
           .testTarget(name: "\(name)ModelTests", dependencies: [.target(name: "\(name)Model")]),
       ]
   }
   #if os(macOS)
   products += [.executable(name: "AfterGlowApp", targets: ["AfterGlowApp"])]
   targets += [
       .target(name: "SuiteShell", dependencies: ["SuiteUI", "SuiteModel"]),
       .executableTarget(name: "AfterGlowApp", dependencies: ["SuiteUI", "SuiteShell", "SuiteModel"]),
   ]
   targets += apps.map { .executableTarget(name: "\($0)App",
                                           dependencies: ["SuiteUI", "SuiteShell", .target(name: "\($0)Model")]) }
   #endif
   ```
2. `project.yml` (not protected, but it travels with the next item): the
   `Release` framework and app targets of R1, and an `AfterGlowJourneyTests`
   bundle in the `Journeys` scheme.
3. `scripts/bundle-apps`: build the `Release` graph with `xcodebuild`, then
   assemble `AfterGlow.app` (launcher executable; `Contents/Helpers/<X>.app`
   ×5; `Contents/Frameworks/` ×4); copy the Info.plists from `Bundle/Info/`
   (document types, exported types, icons, `LSMinimumSystemVersion` 26.0);
   sign inside out (frameworks, then each helper app, then the outer app;
   ad-hoc until a Developer ID exists); keep `plutil -lint` and `codesign
   --verify --deep --strict`; tar as `app-builds.tar.gz`. Journeys keep
   working because the five `.build/apps/<X>App.app` paths become symlinks
   into the bundle (BU-4 acceptance) until each journey moves to the
   `AfterGlow.app` paths.
4. `scripts/size-report` (new): reads the assembled bundle and writes
   `.build/size-report.json` (`SizeReport`, section 5): bytes per
   executable, per framework, per app bundle and for the whole bundle,
   uncompressed and in the tarball, and the count of SuiteUI symbols
   defined in each app executable (`nm -U`; must be 0 after the split).
   The decision (over or under budget) is `SizeBudget.evaluate` in
   SuiteModel, run by `swift run`-free means: the script calls the
   SuiteModelTests filter `SizeGateTests` with `SUITE_SIZE_REPORT` set.
5. `.github/workflows/ci.yml`, `macos` job: after `scripts/bundle-apps`, run
   `scripts/size-report`, upload `size-report` (the JSON), add the table to
   the job summary, and fail on an over-budget row once the gate is set.
   The `linux` job is unchanged (it never sees SuiteShell or AfterGlowApp).
6. `scripts/ci`: no new lint; the C4 check already covers new `Sources/`
   folders once `docs/c4/model.json` names them (BU-1).

### 2.6 Processes, the store and the wires between them

**Processes.** The launcher (`AfterGlow`) and each app run as their own
process. An app never quits when its last window closes (SwiftUI's
`WindowGroup` default on macOS), so returning to it is an activation. Every
app restores its windows at relaunch (system window restoration, plus each
app's recovery file for unsaved work).

**The suite store.** One folder, `~/Library/Application Support/AfterGlow/`
(`SuiteLocations`; journeys pass `-SuiteSupportDir <tmp>`):

| Path | Content | Writers |
|---|---|---|
| `recents.json` | `RecentsList` (revisioned) | every app on open and save; the home on remove |
| `preferences.json` | `SuitePreferences` (revisioned) | the Settings scene |
| `assets/index.json`, `assets/<id>/<revision>.<ext>` | the asset index and payloads (SVG, PNG, `.flare`, colour JSON) | any app's "Add to Assets"; the Assets page |
| `handoffs/<id>.aghandoff` | one `HandOff` (JSON) per hand-off, deleted when complete or after 7 days | the sending app; the receiving app updates `state` |
| `thumbnails/<file id>.png` | a 512 px thumbnail per recent document | the app that saved it |

Writes are atomic replace with a revision: a writer reads the revision,
writes `revision + 1`, and on a mismatch re-reads, merges (the merge is pure
Model code) and tries again. After a write, the writer posts the
distributed notification `org.creativesuite.suite.changed` with the file
name; every process re-reads that file. The folder is shared by plain path
because the bundle is ad-hoc signed and not sandboxed in v1. An app group
container needs a team identifier to sign with (Apple docs: "Accessing app
group containers in your existing macOS app"); moving there is Q3.

**Hand-off transport.** A hand-off is a small file of the exported type
`org.creativesuite.suite.handoff`, which every app declares it opens. The
sender writes it and opens it with the target app
(`NSWorkspace.open(_:withApplicationAt:configuration:)`), so the same path
works whether the target is running (an open-document event) or not (a
launch with the file). Launch arguments are not used for this: they are
ignored when the app is already running (Apple docs:
`NSWorkspace.LaunchConfigurationKey.arguments`, "Ignored if a new instance of
the app is not launched").

**File router.** The outer `AfterGlow.app` declares every suite document
type (role Editor, rank Owner) and exports the suite's types. Opening a
`.flare` from Finder that reaches the launcher is forwarded to
`Contents/Helpers/Flare.app` the same way as a hand-off, and the launcher
shows no window for it. Each embedded app declares its own types too, so if
Launch Services indexes the nested bundles the file goes there directly.
Either way the file opens in Flare; QB-S6 times it.

**Exported and imported types** (`SuiteTypeRegistry`, mirrored in
`Bundle/Info/AfterGlow.plist`):

| Identifier | Extension | Conforms to | Opened by | Note |
|---|---|---|---|---|
| `org.creativesuite.flare.animation` | `flare` | `public.data`, `public.content` | Flare; Halo (Open In, import) | JSON inside, not declared as `public.json` so text editors don't claim it |
| `org.creativesuite.design.document` | `design` | `public.data`, `public.content` | Design | |
| `org.creativesuite.halo.project` | `halo` | `public.data`, `public.content` | Halo | Halo's `HaloDocumentType.swift` uses this id (#767 names the file, not the id) |
| OpenRaster (imported) | `ora` | `public.image`, `public.zip-archive` | Photo | Photo v2's format (#768). BU-5 checks whether macOS 26 declares it; if not, imported as `org.creativesuite.photo.openraster` |
| `public.png`, `public.jpeg`, `public.heic` | | | Photo (Editor, Alternate), Library (import) | never Owner |
| `org.creativesuite.suite.handoff` | `aghandoff` | `public.data` | every app (Viewer) | 2.6 transport |
| `org.creativesuite.suite.asset` | (pasteboard only) | `public.data` | every app | the asset envelope, section 5 |
| `org.creativesuite.design.layers` | (pasteboard only) | `public.data` | Design | already planned in #766 |
| `org.creativesuite.flare.layers` | (pasteboard only) | `public.data` | Flare | the `AddLayer` envelopes of #384 |

The id prefix stays `org.creativesuite` (today's placeholder in
`scripts/bundle-apps` and `project.yml`) until the captain names the real
one (Q1); it is one constant, `SuiteIdentity.prefix`.

**Threads.** Store reads and writes, thumbnail writes and hand-off file I/O
run off the main thread in each process; the main thread only applies the
decoded value. Nothing in the suite store blocks a window.

---

## 3. Usage map

`docs/priorities.md` ranks features inside each app. The suite's own
features rank the same way: tier 1 is touched in nearly every session, tier
2 weekly, tier 3 occasionally or once. A dependency is never ranked below
what needs it. Clean-room as priorities.md: public sources only, no other
app opened or run, and no product named.

Sources added for the suite rows (public, platform guidance and surveys):

- Apple HIG, Onboarding: "design a flow that's fast, fun, and optional … If
  you let people skip the tutorial … don't present it again on subsequent
  launches" (https://developer.apple.com/design/human-interface-guidelines/onboarding).
- Apple HIG, File management, Drag and drop, Settings, The menu bar
  (https://developer.apple.com/design/human-interface-guidelines/file-management,
  …/drag-and-drop, …/settings, …/the-menu-bar): recents and Open Recent,
  dropping files, one Settings window per app opened with Command-comma.
- The surveys priorities.md already cites: the 2019 motion design survey
  (most respondents use several creative apps together in one project), the
  photo editing software survey (a catalog plus an editor as the common
  pair), and the 2022 UX tools survey (designers hand assets to animation
  and prototyping tools).

No public study counts how often people switch apps or paste between them.
Rows marked *inferred* rest on the platform guidance and on the shape of
the apps' own tier-1 loops; they are the first to move if usage data turns
up.

### Tier 1: nearly every session (`p1`)

| # | Feature | Why tier 1 | Source |
|---|---|---|---|
| 1 | Packaging: one bundle, shared frameworks, document types | Nothing else can ship without it ("p1 by dependency") | captain's brief |
| 2 | Home: recents across apps, open one | Every session starts by finding work; the menu bar's Open Recent is the platform's first route back to work | HIG File management |
| 3 | New document by type (home tiles and presets) | Every new piece of work starts here | each app's tier 1 ("open or create a document", CLAUDE.md Journeys first) |
| 4 | Switch between apps, state kept | The captain's brief: switching is instant; mixed-app projects are the norm | motion survey; brief |
| 5 | One recents list (home and each app's Open Recent) | Same as 2, from inside an app | HIG File management |
| 6 | Finder routing: double-click a suite document opens the right app | The platform's main route to a file; Photo's Q7 asks for it | HIG File management; #768 Q7 |
| 7 | Copy and paste between apps (colours, vector art, images, text) | Copy and paste is in every app's tier 1 (#415, #384, Photo PV-2); across apps it is the cheapest connection. *Inferred* | priorities.md (Flare 5, Design 7) |

### Tier 2: weekly (`p2`)

| # | Feature | Why | Source |
|---|---|---|---|
| 8 | Library → Photo → Library round trip | The catalog-plus-editor pair; Library's "rare deep edit" | photo survey; #769 section 1.1 |
| 9 | Open In ▸ (another app that reads this document) | The route for 8, 15 and for images | *inferred* |
| 10 | Drag and drop between apps and from the Finder onto the home | Second route after paste | HIG Drag and drop |
| 11 | Shared colour library | Designers reuse brand colours across files and tools | UX tools survey; Design #20 |
| 12 | Shared asset library (vector art, images, animations) | Reuse across apps; Flare's "shared suite library" Later item | UX tools survey; flare.md section 1 |
| 13 | Settings window (one, per-app panes) | ⌘, must work in every app (no dead menu items); few options | HIG Settings |
| 14 | Updater | Weekly to monthly; must exist before the first public build | *inferred* |

### Tier 3: specialist or occasional (`p3`)

| # | Feature | Why | Source |
|---|---|---|---|
| 15 | Linked placement (Design asset in Flare or Halo, update when it changes) | A pro workflow on top of 12 | *inferred* |
| 16 | Flare animation in Halo | Halo calls it Later (H10); specialist | #767 section 1 |
| 17 | Onboarding | Once per install, skippable | HIG Onboarding |
| 18 | Size measured and budgeted in CI | Release quality; no user touches it, but it gates packaging (1) | captain's brief |

Size measurement (18) is built with packaging (1) because packaging's
acceptance needs it; its rank says it never blocks a tier-1 journey.

---

## 4. Journeys

### 4.1 How the journeys run

- **Bundle.** `UITests/AfterGlowJourneyTests*.swift`, one `XCTestCase` per
  file, in the `AfterGlowJourneyTests` bundle that BU-3 adds to
  `project.yml`. They need the per-file journey template of SuiteUI QH-4
  (#333, SuiteUI wave 1), which compiles `UITests/<target>*.swift`; until it
  lands the suite's first journeys live in `UITests/AfterGlowJourneyTests.swift`.
- **Launch.** `Journey` launches `.build/apps/AfterGlow.app` by path with
  `-ApplePersistenceIgnoreState YES`, `-SuiteSupportDir <tmp>` (a fresh store
  per test), `-SuiteSkipOnboarding YES` (except SJ18), `-SuiteFixture <name>`
  and, for perf, `-SuitePerfProbe YES`. The launcher passes `-SuiteSupportDir`,
  `-SuitePerfProbe` and each app's fixture flag on to an app it launches cold
  (`NSWorkspace.OpenConfiguration.arguments`). An embedded app is driven
  through `XCUIApplication(bundleIdentifier:)` once it runs. `tearDown`
  terminates every suite process.
- **Fixtures** (`SuiteFixtures`, SuiteModel, written into the tmp store at
  launch; each app's documents come from that app's own fixtures):

| Fixture | Contents |
|---|---|
| `empty` | no recents, no assets |
| `weekOfWork` | 8 recents over 7 days: `Logo.design`, `Cards.design`, `Bounce.flare`, `Intro.halo`, `beach.ora`, `Title.flare`, `Sunset.png`, `Logo animated.flare`; thumbnails; files written into `<tmp>/Documents` from each app's fixture (`cards`, `bounce`, a Halo comp, a two-layer `.ora`) |
| `missing` | `weekOfWork` with `Cards.design` deleted from disk |
| `roundTrip` | a Library catalog of 3 photos (Library's `LibrarySample` seed 2026) and an empty Photo |
| `assets` | 6 colours (two in Display P3), 2 vector assets (from Design's `cards`), 1 image, 1 animation (`bounce`) |

- **Waiting and timing.** As the Flare blueprint: state changes are awaited
  with `waitForExistence` or a value predicate (2 s); timing claims come
  only from probe marks. Cross-process timings use marks from two processes
  on the same clock (`mach_continuous_time`, system wide), written by the
  launcher's and the app's `FrameProbe` and read from both `suite.perf`
  values.
- **Identifiers.** Every control the suite adds carries `afterglow.<area>.<name>`
  (home, assets, settings, onboarding, update) or `suite.<name>` (the shared
  menus inside the apps).
- Every step shoots the window; the audit runs on every shot under the new
  `afterglow` key in `UITests/audit-baseline.json`, starting at 0 for every
  check (adding an app at 0 is not a loosening; app-audit.md).

### 4.2 Tier-1 journeys

Each row: the test (file, owning feature), the fixture, steps (each a
shot), what it asserts, and the empty, error and loading states it passes
through.

**SJ0 `testLaunchShowsHomeAndEveryMenu`** (`AfterGlowJourneyTests.swift`, home) · `weekOfWork`
1. Launch. The home window is frontmost: sidebar (Home, Assets, then one
   row per app), the New row (five tiles), Recents grid, running apps strip
   (empty).
2. `openEachMenu()`: AfterGlow, File, Edit, View, Window, Help.
3. Read `suite.controls`; click each enabled `afterglow.*` control, Escape.

Asserts: 8 recent cards newest first; every menu's item count equals
section 6.2's list; every enabled control changed the shot or a value, every
disabled one has a reason. *Empty:* none here (SJ1b). *Error:* none.
*Loading:* the probe's `recents-ready` mark precedes the first shot.

**SJ1 `testHomeFindsAndOpensRecentWork`** (`+Home`, home) · `weekOfWork`, then `missing`, then `empty`
1. Launch; type "logo" in the search field → 2 cards (`Logo.design`,
   `Logo animated.flare`).
2. Click the Design filter chip → 1 card.
3. Return on the card → Design comes forward with "Logo.design" as its
   window title; the launcher stays running.
4. ⌃⌘0 → the home is frontmost again.
5. Relaunch on `missing`: the `Cards.design` card shows "Missing" with the
   warning symbol; Return on it → inline "Cards.design was moved or deleted."
   with Locate… and Remove from Recents; Remove → 7 cards.
6. Relaunch on `empty`: the empty state.

Asserts: counts per step; Design's `XCUIApplication` state is
`runningForeground` and its window title; the home's after ⌃⌘0. *Empty:*
"No recent work yet. Start something new above, or open a file." with
Open… as the one prominent button. *Error:* the missing-file message in
place, never an alert. *Loading:* a card whose thumbnail has not loaded
shows its app's symbol on the `panel` fill (snapshot `afterglow-home-loading`).

**SJ2 `testNewDocumentByType`** (`+New`, home) · `empty`
1. Click the "Vertical 9:16" preset chip under New Animation → Flare comes
   forward with a new untitled animation.
2. ⌃⌘0; New Design → Design's new untitled file.
3. ⌃⌘0; New Image → Photo's New Image sheet.
4. ⌃⌘0; New Composition → Halo's New Composition sheet.
5. ⌃⌘0; Import Photos… → Library comes forward with its Import Folder panel.

Asserts: each app frontmost with the named window or sheet; Flare's info
card reads 1080 × 1920 (once Flare's F11b #350/#351 land; until then the
window title "Untitled" only). *Empty:* the empty home is the start state.
*Error:* launched with `-SuiteFixture empty -SuiteHideApp halo` (test-only
flag that makes the router treat Halo as missing): the Halo tile is
disabled with "Halo is missing from AfterGlow. Reinstall AfterGlow to get
it back." *Loading:* while an app launches cold, its tile shows a progress
ring after 100 ms (probe mark `tile-progress`, QB-L9).

**SJ3 `testSwitchKeepsEachAppAsLeft`** (`+Switch`, switching) · `weekOfWork`
1. Open `Bounce.flare` from the home; in Flare go to frame 12, select Ball,
   zoom to 200%.
2. ⌃⌘2 → Design comes forward (opens with no document: its empty state).
3. ⌃⌘1 → Flare comes forward.
4. Window > Switch To > Home (⌃⌘0); in the running strip click Flare.
5. In Flare ⌘W (close the last window), then ⌃⌘1.

Asserts: after 3 and 4, Flare's frame readout 12, selection Ball, zoom pill
200%, same window; after 5 Flare is still running (it never quit) and
opens a window (the empty state, as a reopen). The strip lists Flare and
Design with a running dot. *Empty:* Design's own empty state at step 2.
*Error:* switching to an app that crashed since: the strip drops it within
1 s and ⌃⌘<n> launches it cold (Model test `SwitchRunStateTests`; the
journey kills Design with `terminate()` and asserts the strip). *Loading:*
the cold launch at step 2 shows the menu item's progress in the home strip
(probe `switch-cold`).

**SJ4 `testOneRecentsList`** (`+Recents`, recents-open-in) · `empty`
1. New Design; draw a rectangle; ⌘S (`-DesignSaveTo <tmp>/Card.design`).
2. ⌃⌘0 → the home's first card is `Card.design` with a thumbnail.
3. New Animation; ⌘S (`-FlareSaveTo <tmp>/Hop.flare`).
4. In Flare, File > Open Recent → `Hop.flare` only; in Design → `Card.design`
   only.
5. In Design, File > Open Recent > Clear Menu → the home shows only
   `Hop.flare`.

Asserts: the lists at each step; the thumbnail file exists in the store.
*Empty:* Open Recent's "No Recent Files" state in a fresh app (before step
1). *Error:* save fails (read-only folder) → nothing is added (the app's own
"Not saved" state). *Loading:* none (the list is local).

**SJ5 `testFinderOpenRoutesToTheRightApp`** (`+Routing`, recents-open-in) · `weekOfWork`
1. The test runner opens `<tmp>/Documents/Cards.design` with
   `NSWorkspace.open(_:withApplicationAt:configuration:)` at `AfterGlow.app`.
2. The same for `Bounce.flare`, `Intro.halo`, `beach.ora`, `Sunset.png`.
3. The same for `notes.txt`.

Asserts: each file's app is frontmost with that window title; the launcher
opened no window for steps 1–2 (its window count is unchanged); `Sunset.png`
opens in Photo. *Error:* step 3 shows the home with "AfterGlow can't open
“notes.txt”. It isn't a suite document or an image." *Empty:* none.
*Loading:* the app's own open progress (QB-L9 in that app).

**SJ6 `testCopyPasteBetweenApps`** (`+Paste`, clipboard-drag) · `weekOfWork`
1. In Design (`Cards.design`) select the blue card; ⌘C.
2. ⌃⌘1; in Flare (new animation) ⌘V.
3. In Design, the card's FILL row > Copy Color; in Flare select the pasted
   layer, FILL row > Paste Color.
4. In Library (fixture photos) select a photo in the loupe; ⌘C; ⌃⌘3; in
   Photo File > New from Clipboard (or ⌘V on the empty state).
5. In Flare, with an image on the pasteboard, open the Edit menu.

Asserts: Flare's layer list gains "Card" with the card's fill hex and a
path of the same bounds (±0.5 pt); after 3 the fill hex equals Design's;
Photo's new image has the photo's pixel size; at 5 Paste is disabled with
"Flare can't paste images yet." Each paste is one undo step ("Undo Paste").
*Empty:* paste with an empty pasteboard is disabled "Nothing to paste."
*Error:* a damaged suite envelope falls back to the next representation
(SVG, then PNG) and says nothing; with none readable, the disabled reason.
*Loading:* pasting a 24 MP image shows progress after 100 ms (probe
`paste-progress`).

### 4.3 Tier-2 and tier-3 journeys

| # | Test (file, feature) | Fixture | Steps | Asserts; empty / error / loading |
|---|---|---|---|---|
| SJ10 | `testEditInPhotoAndBack` (`+RoundTrip`, photo-round-trip) | `roundTrip` | Library loupe on photo 2; Photo menu Edit in Photo (⌘E); in Photo raise exposure via a Photo tool; ⌘S; ⌃⌘4 | Photo's title "IMG_0002 (Library edit)"; Library shows a stack of 2 with the edited copy first and the original unchanged byte for byte; the edit's thumbnail differs from the original's. Error: original missing → "The original of IMG_0002 is missing. Locate it in Library first."; Photo closed without saving → the session ends, nothing added; loading: progress in Library's status pill while Photo opens (probe) |
| SJ11 | `testOpenIn` (`+OpenIn`, recents-open-in) | `weekOfWork` | In Photo with `Sunset.png`, File > Open In ▸; pick Library | the submenu lists Library only (Photo excluded); Library imports the file and selects it. Empty: a document no other app reads → the submenu item is disabled "No other app opens PNG files." |
| SJ12 | `testSettingsFromAnyApp` (`+Settings`, settings) | `empty` | In Flare ⌘, ; change General > Units to Centimeters; open Design; its rulers | the AfterGlow Settings window opens at the Flare pane; Design's ruler unit reads cm within 500 ms (QB-S8); ⌘, in the launcher opens General |
| SJ13 | `testSharedColoursAndAssets` (`+Assets`, shared-assets) | `assets` | Home > Assets; add a colour from Design's colour popover ("Add to Suite Colours"); in Flare the FILL popover's Suite Colours section; click it | the Assets page count +1; Flare shows the same 7 swatches; the fill equals the swatch exactly (sRGB and P3 kept). Empty: "No assets yet. Use Add to Assets in any app." |
| SJ14 | `testDragBetweenApps` (`+Drag`, clipboard-drag) | `weekOfWork` | drag the `Sunset.png` card from the home onto Photo's empty canvas; drag a Library thumbnail onto Photo | Photo opens it / adds it as a layer; the drag source shows a drag preview (probe) |
| SJ15 | `testCheckForUpdates` (`+Update`, updater) | `-SuiteUpdateFeed file://<tmp>/feed.json` with a newer version | AfterGlow > Check for Updates… | the offer sheet with version and notes; Later closes it; a bad signature fixture → "This update couldn't be verified, so it wasn't installed." Loading: progress within 100 ms |
| SJ16 | `testPlaceLinkedDesignAsset` (`+Links`, linked-assets) | `assets` | Assets page: drag the vector asset into Flare's stage; in Design edit the asset and Update Asset; back in Flare | Flare's layer shows the link badge; then "Update available"; Update → one undo step "Undo Update Linked Asset"; Missing source → "Linked asset is missing; using the last copy." |
| SJ17 | `testOpenFlareInHalo` (`+FlareInHalo`, flare-in-halo) | `weekOfWork` | In Flare with `Bounce.flare`, File > Open In ▸ Halo | Halo makes a composition 1920 × 1080, 24 fps, 48 frames with one animation layer "Bounce"; Halo's frame 12 equals Flare's PNG export of frame 12 (QB-SV4) |
| SJ18 | `testFirstLaunchOnboarding` (`+Onboarding`, onboarding) | `empty`, no skip flag | launch; Continue ×2 choosing "Photos"; Open Sample | the home orders Library and Photo first; relaunch shows no onboarding; Settings > General > Show Welcome Again brings it back |
| SJ19 | `testEveryControlActsOrSaysWhy` (`+EveryControl`, home) | `weekOfWork` | the `suite.controls` sweep for home, Assets, Settings | as Flare's J29; never cited by the matrix |

### 4.4 Perf journeys (`+Perf`, each feature its own)

| # | Test | Measures | Budget (section 7.1) |
|---|---|---|---|
| SP1 | `testSwitchToRunningAppLatency` | 30 switches ⌃⌘1/⌃⌘2 between two running apps; marks: key event in the source, `didBecomeActive` and first frame of the key window in the target | QB-S1 |
| SP2 | `testColdOpenEachApp` | home tile → first frame of the app's window, each app once, after a purge of the app's process | QB-S2 |
| SP3 | `testHomeFirstFrameAndRecents` | AfterGlow launch → first frame; first frame → `recents-ready` with 200 recents | QB-S3 |
| SP4 | `testRecentsSearchKeystrokes` | 20 keystrokes in search over 200 recents | QB-S4 |
| SP5 | `testPasteAcrossApps` | ⌘V of a 50-shape Design selection in Flare; of a 24 MP image in Photo | QB-S5 |
| SP6 | `testRoutedOpen` | `NSWorkspace.open` at the launcher → first frame of the document window, app running and app cold | QB-S6 |
| SP7 | `testRoundTripLatency` | Edit in Photo → Photo's first frame with the image; Photo ⌘S → Library's thumbnail updated | QB-S7 |
| SP8 | `testPreferencePropagation` | a setting changed in Settings → the change applied in each running app | QB-S8 |
