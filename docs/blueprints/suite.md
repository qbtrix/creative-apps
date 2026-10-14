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

---

## 5. Contracts

One Swift protocol per use case, exact signatures, and a fake for each, so
the home, the apps' menus and the stores can be built in parallel. They
live in `SuiteModel` (Linux-safe, Foundation only, the
`FoundationEssentials` import pattern, Swift 6, value types and actors,
`Sendable`). The four files below are also committed as
`docs/blueprints/suite/contracts/{Values,Contracts,Fakes,Services}.swift`
with `main.swift` (smoke checks of every fake against the behavior this
blueprint states) and `check.sh`, which compiles them with `swiftc
-swift-version 6 -warnings-as-errors` and runs them. On this session's
Linux toolchain (swift 6.3.3) it prints `contracts: PASS`. Task SC-1 moves
them into `Sources/SuiteModel/` (one file per protocol and per fake) and
their checks into `SuiteModelTests`.

Every throwing requirement uses typed throws, `throws(SuiteError)`;
`SuiteError.message` is the sentence the UI shows, so journeys assert the
same text the Model test does.

### 5.1 Use cases at a glance

| UC | Protocol | Tier | Fake | Live (who builds it) | Feature |
|---|---|---|---|---|---|
| 1 | `AppSwitching` | 1 | `FakeSwitching` (run states, a missing app, a terminate hook) | SuiteShell `AppLauncher`: `NSRunningApplication.activate`, else `NSWorkspace.openApplication(at:configuration:)` at `SuiteApp.bundlePath` | switching |
| 2 | `RecentWork` | 1 | `FakeRecents` | `FileStore` over `recents.json` + `StoreWatcher` | recents-open-in |
| 3 | `DocumentCreating` | 1 | `FakeCreating` (also the reference: tiles and presets) | same type, moved to `Home/` | home |
| 4 | `DocumentRouting` | 1 | `FakeRouting` (reference) | same type, in `Routing/` | recents-open-in |
| 5 | `HandOffSending`, `HandOffReceiving` | 1 | `FakeHandOffs` | SuiteShell `HandOffTransport` + `FileStore` over `handoffs/` | switching |
| 6 | `RoundTripEditing` | 2 | `FakeRoundTrips` | `FileStore` over `roundtrips/`; Library and Photo call their halves | photo-round-trip |
| 7 | `PasteboardCoding` | 1 | `FakePasteboard` (reference: what each app accepts, best first) | same type in `Pasteboard/`; SuiteShell `PasteboardBridge`, `DragBridge` map it to AppKit | clipboard-drag |
| 8 | `AssetLibrary` | 2 | `FakeAssets` | `FileStore` over `assets/` | shared-assets |
| 9 | `AssetLinking` | 3 | `FakeLinking` (reference) | same type in `Links/` | linked-assets |
| 10 | `AnimationSourceReading` | 3 | `FakeAnimationSource` | in HaloModel (it links FlareCore; SuiteModel never imports an engine) | flare-in-halo |
| 11 | `PreferencesStoring` | 2 | `FakePreferences` (refuses a stale revision) | `FileStore` over `preferences.json` | settings |
| 12 | `SettingsRouting` | 2 | `FakeSettingsRoute` | an `.openSettings` hand-off to the launcher | settings |
| 13 | `OnboardingFlowing` | 3 | `FakeOnboarding` (reference) | same type in `Onboarding/` | onboarding |
| 14 | `UpdateChecking` | 2 | `FakeUpdates` (feed and accepted signatures injected) | AfterGlowApp: URLSession, CryptoKit Ed25519 verify, replace the bundle | updater |
| 15 | `ThumbnailPublishing` | 1 | `FakeThumbnails` | SuiteShell `ThumbnailWriter` | recents-open-in |
| 16 | `HomeBuilding` | 1 | `FakeHome` (reference; the live one formats dates with the locale) | same type in `Home/` | home |
| 17 | `SizeBudgetChecking` | 3 | `FakeSizeBudget` (reference) | same type in `Packaging/` | bundle |

Which journey each contract serves: UC-1 SJ3, SP1, SP2; UC-2 SJ1, SJ4; UC-3
SJ2; UC-4 SJ5, SJ11; UC-5 SJ1, SJ2, SJ5, SJ10; UC-6 SJ10; UC-7 SJ6, SJ14;
UC-8 SJ13; UC-9 SJ16; UC-10 SJ17; UC-11 SJ12, SP8; UC-12 SJ12; UC-13 SJ18;
UC-14 SJ15; UC-15 SJ4; UC-16 SJ0, SJ1, SP3, SP4; UC-17 the size gate
(section 7.5).

**Which services a launch gets.** `-SuiteFixture <name>`: `.fake` seeded
from that fixture (journeys, snapshots), with the "Preview data" pill. No
arguments (a person's launch): `.live`, built by SuiteShell from its slot
files; a slot whose feature has not landed holds the fake with
`unavailable: "Not connected yet (<feature>)."`, so its controls are
disabled with that reason, never dead.

### 5.2 The protocols (`Contracts.swift`)

```swift
// Contracts.swift: one protocol per suite use case (SuiteModel, planned
// `Sources/SuiteModel/Contracts/`, one file per protocol there). UI and
// logic build against these in parallel: the home and the apps' menus on
// the fakes in Fakes.swift, the stores and SuiteShell's live types behind
// them. Every throwing requirement throws `SuiteError`, whose `message` is
// the sentence the UI shows.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-1 Switch between apps (tier 1). Live: SuiteShell `AppLauncher`
/// (NSRunningApplication.activate, else NSWorkspace.openApplication).
public protocol AppSwitching: Sendable {
    func runState(of app: SuiteApp) async -> AppRunState
    /// Brings the app forward, launching it if needed; never opens a document.
    func switchTo(_ app: SuiteApp, reason: SwitchReason) async throws(SuiteError) -> SwitchReceipt
}

/// UC-2 One recents list (tier 1). Live: `FileStore` over `recents.json`
/// plus SuiteShell's change notification.
public protocol RecentWork: Sendable {
    func list() async throws(SuiteError) -> RecentsList
    func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) async throws(SuiteError)
    func remove(fileID: String) async throws(SuiteError)
    func clear(app: SuiteApp) async throws(SuiteError)
}

/// UC-3 New document by type (tier 1). Pure: presets come from each app's
/// own preset list (mirrored here), creating one makes the hand-off to send.
public protocol DocumentCreating: Sendable {
    func tiles(missing: Set<SuiteApp>) -> [NewTile]
    func handOff(for preset: NewDocumentPreset, id: String, at date: Date) -> HandOff
}

/// UC-4 Route a file to its app, and list Open In targets (tier 1 and 2). Pure.
public protocol DocumentRouting: Sendable {
    /// The app a file opens in, or `.unsupportedFile`.
    func route(fileName: String) throws(SuiteError) -> SuiteApp
    /// Other apps that read this type, default first, never `from` itself.
    func openInTargets(for type: SuiteTypeID, from app: SuiteApp) -> [SuiteApp]
}

/// UC-5 Send a hand-off to another process (tier 1: home opens and new
/// documents ride on it). Live: SuiteShell `HandOffTransport`.
public protocol HandOffSending: Sendable {
    func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt
}

/// UC-5b Receive and settle hand-offs (every app). Live: `FileStore` over `handoffs/`.
public protocol HandOffReceiving: Sendable {
    func receive(_ data: Data, now: Date) async throws(SuiteError) -> HandOff
    func settle(id: String, as state: HandOffState) async throws(SuiteError)
}

/// UC-6 Library to Photo and back (tier 2). Live: a store over `roundtrips/`
/// and hand-offs; Library and Photo each call their half.
public protocol RoundTripEditing: Sendable {
    /// Library: start; Photo receives an `.edit` hand-off with the session id.
    func begin(_ source: RoundTripSource, id: String, at date: Date) async throws(SuiteError) -> RoundTripSession
    /// Photo: the person saved; the flattened copy is for Library, the layered one for re-editing.
    func photoSaved(session id: String, flattened: SuiteDocumentRef, layered: SuiteDocumentRef) async throws(SuiteError) -> RoundTripSession
    /// Library: the copy is in the catalog, stacked on the original.
    func returned(session id: String, as ref: SuiteDocumentRef) async throws(SuiteError) -> RoundTripSession
    func cancel(session id: String) async throws(SuiteError)
    func session(_ id: String) async -> RoundTripSession?
}

/// UC-7 Typed pasteboard and drag data between apps (tier 1). Pure; SuiteShell
/// maps `TypedData` to and from NSPasteboard items and drag providers.
public protocol PasteboardCoding: Sendable {
    /// Richest first: the suite envelope, then SVG or PNG, then text.
    func representations(of item: SuiteClipItem) -> [TypedData]
    /// The best item this app can take from what is offered, or nil.
    func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem?
    /// nil when Paste can act in this app; else why it is disabled.
    func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError?
}

/// UC-8 The shared asset and colour library (tier 2). Live: `FileStore` over `assets/`.
public protocol AssetLibrary: Sendable {
    func index() async throws(SuiteError) -> AssetIndex
    func add(_ draft: AssetDraft, id: String, at date: Date) async throws(SuiteError) -> SuiteAsset
    /// New payload or colour; the revision goes up by one.
    func update(_ id: String, payload: Data?, color: SuiteColorValue?, at date: Date) async throws(SuiteError) -> SuiteAsset
    func remove(_ id: String) async throws(SuiteError)
    func payload(of asset: SuiteAsset) async throws(SuiteError) -> Data
}

/// UC-9 Placed assets keep their link (tier 3). Pure over the index.
public protocol AssetLinking: Sendable {
    func link(to asset: SuiteAsset) -> AssetLink
    func status(of link: AssetLink, in index: AssetIndex) -> LinkStatus
    /// The link after Update; nil when there is nothing newer.
    func updated(_ link: AssetLink, in index: AssetIndex) -> AssetLink?
}

/// UC-10 Read a Flare animation for Halo (tier 3). Live: in HaloModel, which
/// already links FlareCore (SuiteModel never imports an engine).
public protocol AnimationSourceReading: Sendable {
    func summary(of ref: SuiteDocumentRef) async throws(SuiteError) -> AnimationSummary
}

/// UC-11 Shared preferences (tier 2). Live: `FileStore` over `preferences.json`.
public protocol PreferencesStoring: Sendable {
    func load() async throws(SuiteError) -> SuitePreferences
    /// Writes `revision + 1`; `.staleRevision` when another writer won (the caller reloads).
    func save(_ preferences: SuitePreferences) async throws(SuiteError) -> SuitePreferences
}

/// UC-12 Open the one Settings window at a pane from any app (tier 2).
/// Live: an `.openSettings` hand-off to the launcher.
public protocol SettingsRouting: Sendable {
    func open(_ pane: SettingsPane, from app: SuiteApp) async throws(SuiteError)
}

/// UC-13 First-launch onboarding (tier 3). Pure.
public protocol OnboardingFlowing: Sendable {
    var pages: [OnboardingPage] { get }
    func shouldShow(_ preferences: SuitePreferences, version: Int) -> Bool
    func finishing(_ preferences: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences
}

/// UC-14 One updater (tier 2). Live: URLSession download, CryptoKit Ed25519
/// verify, replace the bundle (in AfterGlowApp).
public protocol UpdateChecking: Sendable {
    func check(current: SuiteVersion) async throws(SuiteError) -> UpdateOffer?
    /// Downloads and verifies; returns the local path of the verified zip.
    func download(_ offer: UpdateOffer) async throws(SuiteError) -> String
    /// Asks every running suite app to quit (each runs its own unsaved flow), then replaces and relaunches.
    func install(zipAt path: String) async throws(SuiteError)
}

/// UC-15 Thumbnails for the home (tier 1). Live: SuiteShell `ThumbnailWriter`.
public protocol ThumbnailPublishing: Sendable {
    /// Writes a 512 px PNG; returns its store-relative path.
    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String
}

/// UC-16 Build the home's state (tier 1). Pure.
public protocol HomeBuilding: Sendable {
    func home(recents: RecentsList, running: [SuiteApp], query: String, filter: SuiteApp?,
              order: [SuiteApp], missingApps: Set<SuiteApp>, missingFiles: Set<String>, now: Date) -> HomeState
}

/// UC-17 Size budget (tier 3, gates packaging). Pure; `scripts/size-report` feeds it.
public protocol SizeBudgetChecking: Sendable {
    func evaluate(_ report: SizeReport, against budget: SizeBudget) -> [SizeFinding]
}
```

### 5.3 Wiring (`Services.swift`)

```swift
// Services.swift: SuiteServices (SuiteModel, planned
// `Sources/SuiteModel/SuiteServices.swift`). One member per contract.
// `.fake` is every fake; SuiteShell builds `.live` from one slot file per
// member (`Sources/SuiteShell/Live/<Member>Slot.swift`), each returning the
// fake with an `unavailable` reason until its feature swaps it, so features
// in one wave never edit the same file.

public struct SuiteServices: Sendable {
    public var switching: any AppSwitching
    public var recents: any RecentWork
    public var creating: any DocumentCreating
    public var routing: any DocumentRouting
    public var sending: any HandOffSending
    public var receiving: any HandOffReceiving
    public var roundTrips: any RoundTripEditing
    public var pasteboard: any PasteboardCoding
    public var assets: any AssetLibrary
    public var linking: any AssetLinking
    public var animations: any AnimationSourceReading
    public var preferences: any PreferencesStoring
    public var settings: any SettingsRouting
    public var onboarding: any OnboardingFlowing
    public var updates: any UpdateChecking
    public var thumbnails: any ThumbnailPublishing
    public var home: any HomeBuilding
    public var size: any SizeBudgetChecking
    /// True while any member is a fake; drives a "Preview data" pill in the home.
    public var isPreview: Bool

    public init(switching: any AppSwitching, recents: any RecentWork, creating: any DocumentCreating,
                routing: any DocumentRouting, sending: any HandOffSending, receiving: any HandOffReceiving,
                roundTrips: any RoundTripEditing, pasteboard: any PasteboardCoding, assets: any AssetLibrary,
                linking: any AssetLinking, animations: any AnimationSourceReading, preferences: any PreferencesStoring,
                settings: any SettingsRouting, onboarding: any OnboardingFlowing, updates: any UpdateChecking,
                thumbnails: any ThumbnailPublishing, home: any HomeBuilding, size: any SizeBudgetChecking, isPreview: Bool) {
        self.switching = switching; self.recents = recents; self.creating = creating; self.routing = routing
        self.sending = sending; self.receiving = receiving; self.roundTrips = roundTrips; self.pasteboard = pasteboard
        self.assets = assets; self.linking = linking; self.animations = animations; self.preferences = preferences
        self.settings = settings; self.onboarding = onboarding; self.updates = updates; self.thumbnails = thumbnails
        self.home = home; self.size = size; self.isPreview = isPreview
    }

    /// Every member a fake, seeded from a fixture's recents and assets.
    public static func fake(recents: RecentsList = RecentsList(), assets: AssetIndex = AssetIndex(),
                            running: [SuiteApp] = [], missing: Set<SuiteApp> = []) -> SuiteServices {
        let switching = FakeSwitching(running: running, missing: missing)
        let handOffs = FakeHandOffs(switching: switching)
        return SuiteServices(switching: switching, recents: FakeRecents(recents), creating: FakeCreating(),
                             routing: FakeRouting(), sending: handOffs, receiving: handOffs,
                             roundTrips: FakeRoundTrips(), pasteboard: FakePasteboard(), assets: FakeAssets(assets),
                             linking: FakeLinking(), animations: FakeAnimationSource(), preferences: FakePreferences(),
                             settings: FakeSettingsRoute(), onboarding: FakeOnboarding(), updates: FakeUpdates(),
                             thumbnails: FakeThumbnails(), home: FakeHome(), size: FakeSizeBudget(), isPreview: true)
    }
}
```

### 5.4 Shared values (`Values.swift`)

<details><summary>Values.swift (identity, type registry, document refs, errors, recents, hand-offs, round trip, colours and assets, pasteboard, preferences, onboarding, updates, home, packaging)</summary>

```swift
// Values.swift: the values every suite contract shares (SuiteModel,
// planned `Sources/SuiteModel/Values/`). Foundation only, Linux-safe,
// Sendable. Pure logic that several features need (recents merge, the type
// registry, version compare) lives on these values so it is tested once.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: identity

/// The one id prefix. Placeholder until the captain names the real one (Q1).
public enum SuiteIdentity {
    public static let prefix = "org.creativesuite"
}

/// The launcher and the five apps inside AfterGlow.app.
public enum SuiteApp: String, CaseIterable, Codable, Hashable, Sendable {
    case launcher, flare, design, photo, library, halo

    /// The five apps, in the home's default order.
    public static let apps: [SuiteApp] = [.flare, .design, .photo, .library, .halo]

    public var displayName: String {
        switch self {
        case .launcher: "AfterGlow"
        case .flare: "Flare"
        case .design: "Design"
        case .photo: "Photo"
        case .library: "Library"
        case .halo: "Halo"
        }
    }

    public var bundleID: String {
        SuiteIdentity.prefix + "." + (self == .launcher ? "afterglow" : rawValue)
    }

    /// Path inside AfterGlow.app; the launcher is the bundle itself.
    public var bundlePath: String {
        self == .launcher ? "" : "Contents/Helpers/\(displayName).app"
    }

    /// Window > Switch To shortcut: Control-Command and this digit.
    public var switchDigit: Int {
        switch self {
        case .launcher: 0
        case .flare: 1
        case .design: 2
        case .photo: 3
        case .library: 4
        case .halo: 5
        }
    }
}

// MARK: types

/// A uniform type identifier, as a string so the Model stays Linux-safe.
public struct SuiteTypeID: RawRepresentable, Hashable, Codable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let flareAnimation = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".flare.animation")
    public static let designDocument = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".design.document")
    public static let haloProject = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".halo.project")
    public static let photoOpenRaster = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".photo.openraster")
    public static let handOff = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".suite.handoff")
    public static let assetEnvelope = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".suite.asset")
    public static let designLayers = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".design.layers")
    public static let flareLayers = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".flare.layers")
    public static let png = SuiteTypeID(rawValue: "public.png")
    public static let jpeg = SuiteTypeID(rawValue: "public.jpeg")
    public static let heic = SuiteTypeID(rawValue: "public.heic")
    public static let svg = SuiteTypeID(rawValue: "public.svg-image")
    public static let plainText = SuiteTypeID(rawValue: "public.utf8-plain-text")
}

/// One file type the suite reads: who owns it and who else can open it.
public struct SuiteDocumentType: Hashable, Sendable {
    public var id: SuiteTypeID
    public var name: String              // "Flare Animation"; used in messages
    public var extensions: [String]      // lowercased, no dot
    public var owner: SuiteApp?          // Editor, rank Owner; nil for public types
    public var readers: [SuiteApp]       // Open In targets, default app first
    public init(id: SuiteTypeID, name: String, extensions: [String], owner: SuiteApp?, readers: [SuiteApp]) {
        self.id = id; self.name = name; self.extensions = extensions; self.owner = owner; self.readers = readers
    }
}

/// Every document type in the suite. `Bundle/Info/*.plist` mirror it, and
/// `TypeRegistryPlistTests` fails when they differ.
public struct SuiteTypeRegistry: Sendable {
    public var types: [SuiteDocumentType]
    public init(types: [SuiteDocumentType]) { self.types = types }

    public static let standard = SuiteTypeRegistry(types: [
        SuiteDocumentType(id: .flareAnimation, name: "Flare Animation", extensions: ["flare"],
                          owner: .flare, readers: [.flare, .halo]),
        SuiteDocumentType(id: .designDocument, name: "Design Document", extensions: ["design"],
                          owner: .design, readers: [.design]),
        SuiteDocumentType(id: .haloProject, name: "Halo Project", extensions: ["halo"],
                          owner: .halo, readers: [.halo]),
        SuiteDocumentType(id: .photoOpenRaster, name: "Photo Document", extensions: ["ora"],
                          owner: .photo, readers: [.photo]),
        SuiteDocumentType(id: .png, name: "PNG image", extensions: ["png"], owner: nil, readers: [.photo, .library]),
        SuiteDocumentType(id: .jpeg, name: "JPEG image", extensions: ["jpg", "jpeg"], owner: nil, readers: [.photo, .library]),
        SuiteDocumentType(id: .heic, name: "HEIC image", extensions: ["heic"], owner: nil, readers: [.photo, .library]),
    ])

    public func type(forExtension ext: String) -> SuiteDocumentType? {
        let e = ext.lowercased()
        return types.first { $0.extensions.contains(e) }
    }

    public func type(_ id: SuiteTypeID) -> SuiteDocumentType? { types.first { $0.id == id } }

    /// The app a routed open goes to: the owner, else the first reader.
    public func defaultApp(for id: SuiteTypeID) -> SuiteApp? {
        guard let t = type(id) else { return nil }
        return t.owner ?? t.readers.first
    }
}

// MARK: documents

/// A document on disk, as every app and the launcher refer to it.
public struct SuiteDocumentRef: Hashable, Codable, Sendable {
    public var path: String          // absolute path
    public var fileID: String        // stable identity (volume and file number from the app; the path when unknown)
    public var app: SuiteApp         // the app that last opened or saved it
    public var type: SuiteTypeID
    public var displayName: String   // file name with extension
    public var bookmark: Data?       // macOS bookmark data when the app has it; nil in tests and on Linux
    public init(path: String, fileID: String, app: SuiteApp, type: SuiteTypeID, displayName: String, bookmark: Data? = nil) {
        self.path = path; self.fileID = fileID; self.app = app; self.type = type
        self.displayName = displayName; self.bookmark = bookmark
    }
}

// MARK: errors

/// Every suite failure, each with the sentence the UI shows.
public enum SuiteError: Error, Equatable, Sendable {
    case appMissing(SuiteApp)
    case fileMissing(name: String)
    case unsupportedFile(name: String)
    case nothingToPaste
    case cannotPaste(app: SuiteApp, kind: String)
    case staleRevision
    case damaged(String)
    case notAvailable(String)
    case cancelled
    case timedOut
    case updateNotVerified
    case ioFailed(String)

    public var message: String {
        switch self {
        case .appMissing(let a): "\(a.displayName) is missing from AfterGlow. Reinstall AfterGlow to get it back."
        case .fileMissing(let n): "\(n) was moved or deleted."
        case .unsupportedFile(let n): "AfterGlow can't open \u{201C}\(n)\u{201D}. It isn't a suite document or an image."
        case .nothingToPaste: "Nothing to paste."
        case .cannotPaste(let a, let k): "\(a.displayName) can't paste \(k) yet."
        case .staleRevision: "Another app changed this at the same time. Try again."
        case .damaged(let d): "This file is damaged: \(d)."
        case .notAvailable(let r): r
        case .cancelled: "Cancelled."
        case .timedOut: "This took too long. Try again."
        case .updateNotVerified: "This update couldn't be verified, so it wasn't installed."
        case .ioFailed(let d): "Couldn't save: \(d)."
        }
    }
}

// MARK: recents

public enum RecentEvent: String, Codable, Sendable { case opened, saved }

public struct RecentItem: Hashable, Codable, Sendable {
    public var ref: SuiteDocumentRef
    public var lastUsed: Date
    public var thumbnail: String?    // path relative to the store, e.g. "thumbnails/<fileID>.png"
    public init(ref: SuiteDocumentRef, lastUsed: Date, thumbnail: String? = nil) {
        self.ref = ref; self.lastUsed = lastUsed; self.thumbnail = thumbnail
    }
}

/// The one recents list. Newest first, one entry per file, at most `cap`.
public struct RecentsList: Codable, Equatable, Sendable {
    public static let cap = 200
    public var revision: Int
    public private(set) var items: [RecentItem]

    public init(revision: Int = 0, items: [RecentItem] = []) {
        self.revision = revision
        self.items = []
        for item in items { note(item) }
    }

    /// Puts the item first, replacing an older entry for the same file.
    public mutating func note(_ item: RecentItem) {
        items.removeAll { $0.ref.fileID == item.ref.fileID }
        let at = items.firstIndex { $0.lastUsed < item.lastUsed } ?? items.count
        items.insert(item, at: at)
        if items.count > Self.cap { items.removeLast(items.count - Self.cap) }
    }

    public mutating func remove(fileID: String) { items.removeAll { $0.ref.fileID == fileID } }
    public mutating func clear(app: SuiteApp) { items.removeAll { $0.ref.app == app } }

    /// Items for one app (nil: all) whose name contains the query, any case.
    public func filtered(app: SuiteApp?, query: String) -> [RecentItem] {
        let q = query.lowercased()
        return items.filter { item in
            (app == nil || item.ref.app == app) && (q.isEmpty || item.ref.displayName.lowercased().contains(q))
        }
    }

    /// Two writers raced: keep the newest entry per file from both.
    public func merging(_ other: RecentsList) -> RecentsList {
        var merged = RecentsList(revision: max(revision, other.revision), items: items)
        for item in other.items {
            if let mine = merged.items.first(where: { $0.ref.fileID == item.ref.fileID }), mine.lastUsed >= item.lastUsed {
                continue
            }
            merged.note(item)
        }
        return merged
    }
}

// MARK: new documents

public struct NewDocumentPreset: Hashable, Codable, Sendable {
    public var id: String               // "flare.vertical"
    public var app: SuiteApp
    public var title: String            // "Vertical 9:16"
    public var detail: String           // "1080 × 1920, 30 fps"
    public var parameters: [String: String]   // read by the app, e.g. ["width": "1080"]
    public init(id: String, app: SuiteApp, title: String, detail: String, parameters: [String: String] = [:]) {
        self.id = id; self.app = app; self.title = title; self.detail = detail; self.parameters = parameters
    }
}

// MARK: switching

public enum AppRunState: Equatable, Sendable {
    case notRunning, launching, running(windows: Int), missing
}

public enum SwitchReason: String, Codable, Sendable { case shortcut, menu, home, handOff }

public struct SwitchReceipt: Equatable, Sendable {
    public var app: SuiteApp
    public var wasRunning: Bool
    public var requestedAt: UInt64      // mach_continuous_time ticks; the probe pairs it with the target's frame
    public init(app: SuiteApp, wasRunning: Bool, requestedAt: UInt64) {
        self.app = app; self.wasRunning = wasRunning; self.requestedAt = requestedAt
    }
}

// MARK: hand-offs

public enum HandOffVerb: String, Codable, Sendable {
    case open, new, edit, place, importAnimation, returnEdit, openSettings
}

public enum HandOffState: String, Codable, Sendable { case pending, accepted, returned, cancelled, expired }

/// One request from one suite process to another, written as a `.aghandoff` file.
public struct HandOff: Codable, Equatable, Identifiable, Sendable {
    public static let formatVersion = 1
    public var format: Int
    public var id: String
    public var from: SuiteApp
    public var to: SuiteApp
    public var verb: HandOffVerb
    public var documents: [SuiteDocumentRef]
    public var preset: NewDocumentPreset?
    public var asset: AssetLink?
    public var settingsPane: SettingsPane?
    public var session: String?          // a round-trip session id
    public var returnTo: SuiteApp?
    public var createdAt: Date
    public var state: HandOffState

    public init(id: String, from: SuiteApp, to: SuiteApp, verb: HandOffVerb, documents: [SuiteDocumentRef] = [],
                preset: NewDocumentPreset? = nil, asset: AssetLink? = nil, settingsPane: SettingsPane? = nil,
                session: String? = nil, returnTo: SuiteApp? = nil, createdAt: Date, state: HandOffState = .pending) {
        self.format = Self.formatVersion
        self.id = id; self.from = from; self.to = to; self.verb = verb; self.documents = documents
        self.preset = preset; self.asset = asset; self.settingsPane = settingsPane; self.session = session
        self.returnTo = returnTo; self.createdAt = createdAt; self.state = state
    }

    /// Pending hand-offs older than this are expired by the next reader.
    public static let lifetime: Double = 7 * 24 * 3600

    public func isExpired(now: Date) -> Bool {
        state == .pending && now.timeIntervalSince(createdAt) > Self.lifetime
    }
}

/// The `.aghandoff` file format: sorted-key JSON; a newer format is refused by name.
public enum HandOffCodec {
    public static func encode(_ h: HandOff) throws(SuiteError) -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        do { return try e.encode(h) } catch { throw .damaged("hand-off could not be written") }
    }

    public static func decode(_ data: Data) throws(SuiteError) -> HandOff {
        struct Head: Decodable { var format: Int }
        guard let head = try? JSONDecoder().decode(Head.self, from: data) else { throw .damaged("not a hand-off") }
        guard head.format <= HandOff.formatVersion else {
            throw .notAvailable("This was sent by a newer AfterGlow. Update AfterGlow to open it.")
        }
        do { return try JSONDecoder().decode(HandOff.self, from: data) } catch { throw .damaged("hand-off fields") }
    }
}

// MARK: round trip

public struct RoundTripSource: Codable, Equatable, Sendable {
    public var catalogPhotoID: String    // Library's photo id
    public var original: SuiteDocumentRef
    public init(catalogPhotoID: String, original: SuiteDocumentRef) {
        self.catalogPhotoID = catalogPhotoID; self.original = original
    }
}

public enum RoundTripState: Codable, Equatable, Sendable {
    case open                              // Photo has it
    case saved(flattened: SuiteDocumentRef, layered: SuiteDocumentRef)
    case returned(SuiteDocumentRef)        // in Library's catalog, stacked on the original
    case cancelled
    case failed(String)
}

public struct RoundTripSession: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var source: RoundTripSource
    public var title: String               // "IMG_0002 (Library edit)"
    public var state: RoundTripState
    public var startedAt: Date
    public init(id: String, source: RoundTripSource, title: String, state: RoundTripState, startedAt: Date) {
        self.id = id; self.source = source; self.title = title; self.state = state; self.startedAt = startedAt
    }
}

// MARK: colours and assets

public enum SuiteColorSpace: String, Codable, Sendable { case sRGB, displayP3 }

/// A colour as stored: components 0...1 in their own space, never converted on save.
public struct SuiteColorValue: Codable, Hashable, Sendable {
    public var space: SuiteColorSpace
    public var red: Double, green: Double, blue: Double, alpha: Double
    public init(space: SuiteColorSpace, red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.space = space; self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// "RRGGBB" (alpha dropped), for hex rows; components clamped to 0...1.
    public var hex: String {
        func byte(_ v: Double) -> String {
            let n = Int((min(max(v, 0), 1) * 255).rounded())
            let s = String(n, radix: 16, uppercase: true)
            return s.count == 1 ? "0" + s : s
        }
        return byte(red) + byte(green) + byte(blue)
    }
}

public enum AssetKind: String, Codable, CaseIterable, Sendable { case color, vector, image, animation }

public struct SuiteAsset: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: AssetKind
    public var name: String
    public var revision: Int               // +1 on every update
    public var color: SuiteColorValue?     // kind == .color
    public var payload: String?            // "assets/<id>/<revision>.svg" for the other kinds
    public var source: SuiteDocumentRef?   // where it was added from, if anywhere
    public var modifiedAt: Date
    public init(id: String, kind: AssetKind, name: String, revision: Int = 1, color: SuiteColorValue? = nil,
                payload: String? = nil, source: SuiteDocumentRef? = nil, modifiedAt: Date) {
        self.id = id; self.kind = kind; self.name = name; self.revision = revision; self.color = color
        self.payload = payload; self.source = source; self.modifiedAt = modifiedAt
    }
}

/// What an app hands to Add to Assets.
public struct AssetDraft: Equatable, Sendable {
    public var kind: AssetKind
    public var name: String
    public var color: SuiteColorValue?
    public var payload: Data?              // SVG text, PNG bytes or a .flare file's bytes
    public var payloadExtension: String?   // "svg", "png", "flare"
    public var source: SuiteDocumentRef?
    public init(kind: AssetKind, name: String, color: SuiteColorValue? = nil, payload: Data? = nil,
                payloadExtension: String? = nil, source: SuiteDocumentRef? = nil) {
        self.kind = kind; self.name = name; self.color = color; self.payload = payload
        self.payloadExtension = payloadExtension; self.source = source
    }
}

public struct AssetIndex: Codable, Equatable, Sendable {
    public var revision: Int
    public var assets: [SuiteAsset]
    public init(revision: Int = 0, assets: [SuiteAsset] = []) { self.revision = revision; self.assets = assets }

    public func asset(_ id: String) -> SuiteAsset? { assets.first { $0.id == id } }

    /// By kind (nil: all) and name, any case, newest first.
    public func search(_ query: String, kind: AssetKind?) -> [SuiteAsset] {
        let q = query.lowercased()
        return assets
            .filter { (kind == nil || $0.kind == kind) && (q.isEmpty || $0.name.lowercased().contains(q)) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Two writers raced: per asset keep the higher revision; removals are not resurrected
    /// because a remove bumps the index revision and the remover writes last.
    public func merging(_ other: AssetIndex) -> AssetIndex {
        var byID: [String: SuiteAsset] = [:]
        for a in assets + other.assets {
            if let have = byID[a.id], have.revision >= a.revision { continue }
            byID[a.id] = a
        }
        return AssetIndex(revision: max(revision, other.revision),
                          assets: byID.values.sorted { $0.modifiedAt > $1.modifiedAt })
    }
}

/// A placed asset's memory of where it came from. Stored inside the host document.
public struct AssetLink: Codable, Hashable, Sendable {
    public var assetID: String
    public var kind: AssetKind
    public var placedRevision: Int
    public init(assetID: String, kind: AssetKind, placedRevision: Int) {
        self.assetID = assetID; self.kind = kind; self.placedRevision = placedRevision
    }
}

public enum LinkStatus: Equatable, Sendable { case current, updateAvailable(revision: Int), missing }

// MARK: pasteboard

/// One representation on the pasteboard or in a drag.
public struct TypedData: Equatable, Sendable {
    public var type: SuiteTypeID
    public var data: Data
    public init(type: SuiteTypeID, data: Data) { self.type = type; self.data = data }
}

/// The suite's own envelope: what was copied, from where, and its link if it is an asset.
public struct AssetEnvelope: Codable, Equatable, Sendable {
    public var name: String
    public var kind: AssetKind
    public var from: SuiteApp
    public var link: AssetLink?
    public var color: SuiteColorValue?
    public var svg: String?
    public init(name: String, kind: AssetKind, from: SuiteApp, link: AssetLink? = nil,
                color: SuiteColorValue? = nil, svg: String? = nil) {
        self.name = name; self.kind = kind; self.from = from; self.link = link; self.color = color; self.svg = svg
    }
}

/// What a paste or drop delivers to an app, after the suite chose the best representation.
public enum SuiteClipItem: Equatable, Sendable {
    case envelope(AssetEnvelope)
    case vector(svg: String, name: String)
    case image(png: Data, pixelWidth: Int, pixelHeight: Int)
    case color(SuiteColorValue)
    case text(String)
    case files([SuiteDocumentRef])

    public var kindName: String {
        switch self {
        case .envelope(let e): e.kind == .image ? "images" : e.kind == .color ? "colours" : "vector art"
        case .vector: "vector art"
        case .image: "images"
        case .color: "colours"
        case .text: "text"
        case .files: "files"
        }
    }
}

// MARK: preferences and settings

public enum LengthUnit: String, Codable, CaseIterable, Sendable { case points, pixels, millimeters, centimeters, inches }

public enum SettingsPane: Codable, Hashable, Sendable { case general, app(SuiteApp) }

public struct SuitePreferences: Codable, Equatable, Sendable {
    public var revision: Int
    public var units: LengthUnit
    public var autosaveSeconds: Int          // 10...600
    public var checkForUpdates: Bool
    public var onboardingDoneVersion: Int?   // nil: never finished or skipped
    public var homeOrder: [SuiteApp]
    public var perApp: [String: [String: String]]   // keyed by SuiteApp.rawValue; each app owns its keys
    public init(revision: Int = 0, units: LengthUnit = .points, autosaveSeconds: Int = 30, checkForUpdates: Bool = true,
                onboardingDoneVersion: Int? = nil, homeOrder: [SuiteApp] = SuiteApp.apps, perApp: [String: [String: String]] = [:]) {
        self.revision = revision; self.units = units; self.autosaveSeconds = min(max(autosaveSeconds, 10), 600)
        self.checkForUpdates = checkForUpdates; self.onboardingDoneVersion = onboardingDoneVersion
        self.homeOrder = homeOrder; self.perApp = perApp
    }
}

// MARK: onboarding

public enum OnboardingFocus: String, Codable, CaseIterable, Sendable { case animation, design, photos, motion, everything }

public struct OnboardingPage: Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var choices: [OnboardingFocus]    // empty except on the "what you do" page
    public init(id: String, title: String, body: String, choices: [OnboardingFocus] = []) {
        self.id = id; self.title = title; self.body = body; self.choices = choices
    }
}

// MARK: updates

public struct SuiteVersion: Comparable, Codable, Hashable, Sendable {
    public var major: Int, minor: Int, patch: Int
    public init(_ major: Int, _ minor: Int, _ patch: Int) { self.major = major; self.minor = minor; self.patch = patch }
    public init?(_ text: String) {
        let parts = text.split(separator: ".").map { Int($0) }
        guard (1...3).contains(parts.count), parts.allSatisfy({ $0 != nil }) else { return nil }
        let n = parts.compactMap { $0 } + [0, 0]
        self.init(n[0], n[1], n[2])
    }
    public static func < (a: SuiteVersion, b: SuiteVersion) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }
}

public struct UpdateOffer: Codable, Equatable, Sendable {
    public var version: SuiteVersion
    public var notes: String
    public var url: String                  // https zip of AfterGlow.app
    public var byteCount: Int
    public var signature: String            // base64 Ed25519 over the zip
    public var minimumSystem: String        // "26.0"
    public init(version: SuiteVersion, notes: String, url: String, byteCount: Int, signature: String, minimumSystem: String) {
        self.version = version; self.notes = notes; self.url = url; self.byteCount = byteCount
        self.signature = signature; self.minimumSystem = minimumSystem
    }
}

public enum UpdateFeed {
    /// The feed is a JSON array of offers; the newest above `current` wins.
    public static func newest(in data: Data, above current: SuiteVersion) throws(SuiteError) -> UpdateOffer? {
        guard let offers = try? JSONDecoder().decode([UpdateOffer].self, from: data) else { throw .damaged("update feed") }
        return offers.filter { $0.version > current }.max { $0.version < $1.version }
    }
}

// MARK: Flare in Halo

public struct AnimationSummary: Codable, Equatable, Sendable {
    public var name: String
    public var width: Double, height: Double
    public var framesPerSecond: Double
    public var frameCount: Int
    public var sceneNames: [String]
    public init(name: String, width: Double, height: Double, framesPerSecond: Double, frameCount: Int, sceneNames: [String]) {
        self.name = name; self.width = width; self.height = height
        self.framesPerSecond = framesPerSecond; self.frameCount = frameCount; self.sceneNames = sceneNames
    }
}

// MARK: home

public struct NewTile: Equatable, Sendable {
    public var app: SuiteApp
    public var title: String                 // "New Animation"
    public var presets: [NewDocumentPreset]
    public var disabledReason: String?
    public init(app: SuiteApp, title: String, presets: [NewDocumentPreset], disabledReason: String? = nil) {
        self.app = app; self.title = title; self.presets = presets; self.disabledReason = disabledReason
    }
}

public struct RecentCard: Equatable, Sendable {
    public var item: RecentItem
    public var age: String                   // "Today", "Yesterday", "Monday", "3 Oct"
    public var isMissing: Bool
    public init(item: RecentItem, age: String, isMissing: Bool) { self.item = item; self.age = age; self.isMissing = isMissing }
}

public struct HomeState: Equatable, Sendable {
    public var tiles: [NewTile]
    public var cards: [RecentCard]
    public var running: [SuiteApp]
    public var emptyMessage: String?          // set when there are no cards
    public init(tiles: [NewTile], cards: [RecentCard], running: [SuiteApp], emptyMessage: String?) {
        self.tiles = tiles; self.cards = cards; self.running = running; self.emptyMessage = emptyMessage
    }
}

/// Column math for the home's tile row and recents grid (section 7.3).
public enum HomeLayout {
    public static let sidebar = 200.0, margin = 24.0, gap = 16.0, cardMin = 168.0, cardMax = 240.0

    public static func columns(windowWidth: Double) -> Int {
        let content = windowWidth - sidebar - 2 * margin
        guard content > cardMin else { return 1 }
        return max(1, Int((content + gap) / (cardMin + gap)))
    }

    public static func cardWidth(windowWidth: Double) -> Double {
        let n = Double(columns(windowWidth: windowWidth))
        let content = max(windowWidth - sidebar - 2 * margin, cardMin)
        return min(cardMax, ((content - gap * (n - 1)) / n).rounded(.down))
    }
}

// MARK: packaging

public enum SizeEntryKind: String, Codable, Sendable { case executable, framework, appBundle, wholeBundle, tarball }

public struct SizeEntry: Codable, Equatable, Sendable {
    public var name: String                  // "Flare", "SuiteUI.framework", "AfterGlow.app"
    public var kind: SizeEntryKind
    public var bytes: Int
    public init(name: String, kind: SizeEntryKind, bytes: Int) { self.name = name; self.kind = kind; self.bytes = bytes }
}

public struct SizeReport: Codable, Equatable, Sendable {
    public var commit: String
    public var entries: [SizeEntry]
    public var suiteUISymbols: [String: Int]  // per app executable; 0 once SuiteUI is a framework
    public init(commit: String, entries: [SizeEntry], suiteUISymbols: [String: Int]) {
        self.commit = commit; self.entries = entries; self.suiteUISymbols = suiteUISymbols
    }
}

public struct SizeBudget: Codable, Equatable, Sendable {
    public var limits: [String: Int]          // entry name -> bytes
    public var maxSuiteUISymbols: Int
    public init(limits: [String: Int], maxSuiteUISymbols: Int = 0) { self.limits = limits; self.maxSuiteUISymbols = maxSuiteUISymbols }
}

public struct SizeFinding: Equatable, Sendable {
    public var name: String
    public var measured: Int
    public var limit: Int
    public init(name: String, measured: Int, limit: Int) { self.name = name; self.measured = measured; self.limit = limit }
}
```

</details>

### 5.5 Fakes (`Fakes.swift`)

<details><summary>Fakes.swift (one per contract)</summary>

```swift
// Fakes.swift: one fake per contract (SuiteModel, planned
// `Sources/SuiteModel/Fakes/`, one file each there). In memory, no disk, no
// AppKit. Every fake takes `unavailable:`; set, its reads are empty and its
// writes throw `.notAvailable(reason)`, so `.live` can point at a fake that
// isn't integrated yet and the control shows disabled with that reason.
// The pure contracts' fakes are also their reference behavior: the live
// type for those is this code moved to its component folder.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeSwitching: AppSwitching {
    public private(set) var states: [SuiteApp: AppRunState]
    public private(set) var ticks: UInt64 = 0
    let unavailable: String?
    public init(running: [SuiteApp] = [], missing: Set<SuiteApp> = [], unavailable: String? = nil) {
        var s: [SuiteApp: AppRunState] = [:]
        for app in SuiteApp.allCases { s[app] = missing.contains(app) ? .missing : running.contains(app) ? .running(windows: 1) : .notRunning }
        s[.launcher] = .running(windows: 1)
        states = s
        self.unavailable = unavailable
    }
    public func runState(of app: SuiteApp) -> AppRunState { states[app] ?? .notRunning }
    public func switchTo(_ app: SuiteApp, reason: SwitchReason) throws(SuiteError) -> SwitchReceipt {
        if let unavailable { throw .notAvailable(unavailable) }
        let before = states[app] ?? .notRunning
        if before == .missing { throw .appMissing(app) }
        ticks += 1
        if case .running = before {} else { states[app] = .running(windows: 1) }
        if case .running = before { return SwitchReceipt(app: app, wasRunning: true, requestedAt: ticks) }
        return SwitchReceipt(app: app, wasRunning: false, requestedAt: ticks)
    }
    /// Test hook: the app quit or crashed.
    public func terminate(_ app: SuiteApp) { states[app] = .notRunning }
}

public actor FakeRecents: RecentWork {
    public private(set) var stored: RecentsList
    let unavailable: String?
    public init(_ list: RecentsList = RecentsList(), unavailable: String? = nil) { stored = list; self.unavailable = unavailable }
    public func list() throws(SuiteError) -> RecentsList { if let unavailable { throw .notAvailable(unavailable) }; return stored }
    public func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        let keep = stored.items.first { $0.ref.fileID == ref.fileID }?.thumbnail
        stored.note(RecentItem(ref: ref, lastUsed: date, thumbnail: thumbnail ?? keep))
        stored.revision += 1
    }
    public func remove(fileID: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        stored.remove(fileID: fileID); stored.revision += 1
    }
    public func clear(app: SuiteApp) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        stored.clear(app: app); stored.revision += 1
    }
}

public struct FakeCreating: DocumentCreating {
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// Mirrors each app's own preset list (Flare's New Animation sheet, Halo's New Composition, …).
    public static let presets: [SuiteApp: [NewDocumentPreset]] = [
        .flare: [NewDocumentPreset(id: "flare.hd", app: .flare, title: "1080p 16:9", detail: "1920 × 1080, 24 fps", parameters: ["width": "1920", "height": "1080", "fps": "24"]),
                 NewDocumentPreset(id: "flare.square", app: .flare, title: "Square", detail: "1080 × 1080, 24 fps", parameters: ["width": "1080", "height": "1080", "fps": "24"]),
                 NewDocumentPreset(id: "flare.vertical", app: .flare, title: "Vertical 9:16", detail: "1080 × 1920, 30 fps", parameters: ["width": "1080", "height": "1920", "fps": "30"])],
        .design: [NewDocumentPreset(id: "design.blank", app: .design, title: "Blank", detail: "One page")],
        .photo: [NewDocumentPreset(id: "photo.sheet", app: .photo, title: "New Image…", detail: "Choose a size")],
        .library: [NewDocumentPreset(id: "library.import", app: .library, title: "Import Folder…", detail: "PNG, JPEG, HEIC")],
        .halo: [NewDocumentPreset(id: "halo.sheet", app: .halo, title: "New Composition…", detail: "Choose size, rate and length")],
    ]

    public func tiles(missing: Set<SuiteApp>) -> [NewTile] {
        let titles: [SuiteApp: String] = [.flare: "New Animation", .design: "New Design", .photo: "New Image",
                                          .library: "Import Photos…", .halo: "New Composition"]
        return SuiteApp.apps.map { app in
            let reason = missing.contains(app) ? SuiteError.appMissing(app).message : unavailable
            return NewTile(app: app, title: titles[app] ?? app.displayName, presets: Self.presets[app] ?? [], disabledReason: reason)
        }
    }

    public func handOff(for preset: NewDocumentPreset, id: String, at date: Date) -> HandOff {
        HandOff(id: id, from: .launcher, to: preset.app, verb: .new, preset: preset, createdAt: date)
    }
}

public struct FakeRouting: DocumentRouting {
    public var registry: SuiteTypeRegistry
    public init(registry: SuiteTypeRegistry = .standard) { self.registry = registry }

    public func route(fileName: String) throws(SuiteError) -> SuiteApp {
        let ext = fileName.split(separator: ".").last.map(String.init) ?? ""
        if fileName.hasSuffix(".aghandoff") { return .launcher }
        guard fileName.contains("."), let t = registry.type(forExtension: ext), let app = registry.defaultApp(for: t.id) else {
            throw .unsupportedFile(name: fileName)
        }
        return app
    }

    public func openInTargets(for type: SuiteTypeID, from app: SuiteApp) -> [SuiteApp] {
        (registry.type(type)?.readers ?? []).filter { $0 != app }
    }
}

public actor FakeHandOffs: HandOffSending, HandOffReceiving {
    public private(set) var sent: [HandOff] = []
    public private(set) var settled: [String: HandOffState] = [:]
    let unavailable: String?
    let switching: FakeSwitching
    public init(switching: FakeSwitching = FakeSwitching(), unavailable: String? = nil) {
        self.switching = switching; self.unavailable = unavailable
    }
    public func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt {
        if let unavailable { throw .notAvailable(unavailable) }
        sent.append(handOff)
        return try await switching.switchTo(handOff.to, reason: .handOff)
    }
    public func receive(_ data: Data, now: Date) throws(SuiteError) -> HandOff {
        var h = try HandOffCodec.decode(data)
        if h.isExpired(now: now) { h.state = .expired; settled[h.id] = .expired; throw .notAvailable("This request expired.") }
        h.state = .accepted
        settled[h.id] = .accepted
        return h
    }
    public func settle(id: String, as state: HandOffState) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        settled[id] = state
    }
}

public actor FakeRoundTrips: RoundTripEditing {
    public private(set) var sessions: [String: RoundTripSession] = [:]
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    public func begin(_ source: RoundTripSource, id: String, at date: Date) throws(SuiteError) -> RoundTripSession {
        if let unavailable { throw .notAvailable(unavailable) }
        let base = source.original.displayName.split(separator: ".").first.map(String.init) ?? source.original.displayName
        let s = RoundTripSession(id: id, source: source, title: "\(base) (Library edit)", state: .open, startedAt: date)
        sessions[id] = s
        return s
    }
    public func photoSaved(session id: String, flattened: SuiteDocumentRef, layered: SuiteDocumentRef) throws(SuiteError) -> RoundTripSession {
        guard var s = sessions[id], s.state == .open || isSaved(s.state) else { throw .notAvailable("This edit is no longer open in Library.") }
        s.state = .saved(flattened: flattened, layered: layered)
        sessions[id] = s
        return s
    }
    public func returned(session id: String, as ref: SuiteDocumentRef) throws(SuiteError) -> RoundTripSession {
        guard var s = sessions[id], isSaved(s.state) else { throw .notAvailable("Nothing to bring back yet.") }
        s.state = .returned(ref)
        sessions[id] = s
        return s
    }
    public func cancel(session id: String) throws(SuiteError) {
        guard var s = sessions[id] else { return }
        s.state = .cancelled
        sessions[id] = s
    }
    public func session(_ id: String) -> RoundTripSession? { sessions[id] }

    func isSaved(_ state: RoundTripState) -> Bool { if case .saved = state { return true }; return false }
}

public struct FakePasteboard: PasteboardCoding {
    public init() {}

    /// What each app can take, best first.
    public static let accepts: [SuiteApp: [SuiteTypeID]] = [
        .flare: [.assetEnvelope, .flareLayers, .svg, .plainText],
        .design: [.assetEnvelope, .designLayers, .svg, .png, .plainText],
        .photo: [.assetEnvelope, .png, .jpeg, .heic, .plainText],
        .library: [.png, .jpeg, .heic],
        .halo: [.assetEnvelope, .plainText],
        .launcher: [.assetEnvelope, .svg, .png],
    ]

    public func representations(of item: SuiteClipItem) -> [TypedData] {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        switch item {
        case .envelope(let e):
            var reps = [TypedData]()
            if let d = try? enc.encode(e) { reps.append(TypedData(type: .assetEnvelope, data: d)) }
            if let svg = e.svg { reps.append(TypedData(type: .svg, data: Data(svg.utf8))) }
            if let c = e.color { reps.append(TypedData(type: .plainText, data: Data(("#" + c.hex).utf8))) }
            return reps
        case .vector(let svg, _): return [TypedData(type: .svg, data: Data(svg.utf8))]
        case .image(let png, _, _): return [TypedData(type: .png, data: png)]
        case .color(let c):
            let e = AssetEnvelope(name: "#" + c.hex, kind: .color, from: .launcher, color: c)
            return representations(of: .envelope(e))
        case .text(let t): return [TypedData(type: .plainText, data: Data(t.utf8))]
        case .files: return []
        }
    }

    public func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem? {
        for type in Self.accepts[app] ?? [] {
            guard let rep = offered.first(where: { $0.type == type }) else { continue }
            switch type {
            case .assetEnvelope:
                guard let e = try? JSONDecoder().decode(AssetEnvelope.self, from: rep.data) else { continue }   // damaged: fall back
                if e.kind == .image, app == .flare || app == .halo { continue }
                return .envelope(e)
            case .svg: return .vector(svg: String(decoding: rep.data, as: UTF8.self), name: "Pasted art")
            case .png, .jpeg, .heic: return .image(png: rep.data, pixelWidth: 0, pixelHeight: 0)
            case .plainText: return .text(String(decoding: rep.data, as: UTF8.self))
            default: continue   // an app's own layer types are read by that app's model, not here
            }
        }
        return nil
    }

    public func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError? {
        if offered.isEmpty { return .nothingToPaste }
        if bestItem(from: offered, for: app) != nil { return nil }
        if offered.contains(where: { [.png, .jpeg, .heic].contains($0.type) }) { return .cannotPaste(app: app, kind: "images") }
        return .cannotPaste(app: app, kind: "this")
    }
}

public actor FakeAssets: AssetLibrary {
    public private(set) var stored: AssetIndex
    var payloads: [String: Data] = [:]
    let unavailable: String?
    public init(_ index: AssetIndex = AssetIndex(), unavailable: String? = nil) { stored = index; self.unavailable = unavailable }

    public func index() throws(SuiteError) -> AssetIndex { if let unavailable { throw .notAvailable(unavailable) }; return stored }
    public func add(_ draft: AssetDraft, id: String, at date: Date) throws(SuiteError) -> SuiteAsset {
        if let unavailable { throw .notAvailable(unavailable) }
        let path = draft.payload == nil ? nil : "assets/\(id)/1.\(draft.payloadExtension ?? "bin")"
        let a = SuiteAsset(id: id, kind: draft.kind, name: draft.name, color: draft.color, payload: path, source: draft.source, modifiedAt: date)
        if let p = path, let d = draft.payload { payloads[p] = d }
        stored.assets.insert(a, at: 0); stored.revision += 1
        return a
    }
    public func update(_ id: String, payload: Data?, color: SuiteColorValue?, at date: Date) throws(SuiteError) -> SuiteAsset {
        if let unavailable { throw .notAvailable(unavailable) }
        guard let i = stored.assets.firstIndex(where: { $0.id == id }) else { throw .notAvailable("This asset was removed.") }
        var a = stored.assets[i]
        a.revision += 1; a.modifiedAt = date
        if let color { a.color = color }
        if let payload, let old = a.payload {
            let ext = old.split(separator: ".").last.map(String.init) ?? "bin"
            a.payload = "assets/\(id)/\(a.revision).\(ext)"
            if let p = a.payload { payloads[p] = payload }
        }
        stored.assets[i] = a; stored.revision += 1
        return a
    }
    public func remove(_ id: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        stored.assets.removeAll { $0.id == id }; stored.revision += 1
    }
    public func payload(of asset: SuiteAsset) throws(SuiteError) -> Data {
        guard let p = asset.payload, let d = payloads[p] else { throw .fileMissing(name: asset.name) }
        return d
    }
}

public struct FakeLinking: AssetLinking {
    public init() {}
    public func link(to asset: SuiteAsset) -> AssetLink { AssetLink(assetID: asset.id, kind: asset.kind, placedRevision: asset.revision) }
    public func status(of link: AssetLink, in index: AssetIndex) -> LinkStatus {
        guard let a = index.asset(link.assetID) else { return .missing }
        return a.revision > link.placedRevision ? .updateAvailable(revision: a.revision) : .current
    }
    public func updated(_ link: AssetLink, in index: AssetIndex) -> AssetLink? {
        guard case .updateAvailable(let r) = status(of: link, in: index) else { return nil }
        return AssetLink(assetID: link.assetID, kind: link.kind, placedRevision: r)
    }
}

public struct FakeAnimationSource: AnimationSourceReading {
    public var summaries: [String: AnimationSummary]   // keyed by fileID
    let unavailable: String?
    public init(summaries: [String: AnimationSummary] = [:], unavailable: String? = nil) {
        self.summaries = summaries; self.unavailable = unavailable
    }
    public func summary(of ref: SuiteDocumentRef) throws(SuiteError) -> AnimationSummary {
        if let unavailable { throw .notAvailable(unavailable) }
        guard let s = summaries[ref.fileID] else { throw .fileMissing(name: ref.displayName) }
        return s
    }
}

public actor FakePreferences: PreferencesStoring {
    public private(set) var stored: SuitePreferences
    let unavailable: String?
    public init(_ p: SuitePreferences = SuitePreferences(), unavailable: String? = nil) { stored = p; self.unavailable = unavailable }
    public func load() throws(SuiteError) -> SuitePreferences { if let unavailable { throw .notAvailable(unavailable) }; return stored }
    public func save(_ p: SuitePreferences) throws(SuiteError) -> SuitePreferences {
        if let unavailable { throw .notAvailable(unavailable) }
        guard p.revision == stored.revision else { throw .staleRevision }
        var next = p
        next.revision += 1
        stored = next
        return next
    }
}

public actor FakeSettingsRoute: SettingsRouting {
    public private(set) var opened: [SettingsPane] = []
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }
    public func open(_ pane: SettingsPane, from app: SuiteApp) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        opened.append(pane)
    }
}

public struct FakeOnboarding: OnboardingFlowing {
    public init() {}
    public var pages: [OnboardingPage] {
        [OnboardingPage(id: "apps", title: "Five apps, one AfterGlow",
                        body: "Flare animates, Design draws, Photo retouches, Library sorts your photos, Halo composites. Switch with Control-Command 1 to 5."),
         OnboardingPage(id: "focus", title: "What do you make most?", body: "AfterGlow puts those apps first. You can change this in Settings.",
                        choices: OnboardingFocus.allCases),
         OnboardingPage(id: "start", title: "Start with a sample", body: "Open a sample to see each app at work, or start from an empty home.")]
    }
    public func shouldShow(_ p: SuitePreferences, version: Int) -> Bool { p.onboardingDoneVersion == nil }
    public func finishing(_ p: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences {
        var next = p
        next.onboardingDoneVersion = version
        let first: [SuiteApp]
        switch focus {
        case .animation: first = [.flare, .halo]
        case .design: first = [.design]
        case .photos: first = [.library, .photo]
        case .motion: first = [.halo, .flare]
        case .everything, nil: first = []
        }
        next.homeOrder = first + SuiteApp.apps.filter { !first.contains($0) }
        return next
    }
}

public actor FakeUpdates: UpdateChecking {
    public var feed: Data
    public private(set) var installed: [String] = []
    let unavailable: String?
    let validSignatures: Set<String>
    public init(feed: Data = Data("[]".utf8), validSignatures: Set<String> = [], unavailable: String? = nil) {
        self.feed = feed; self.validSignatures = validSignatures; self.unavailable = unavailable
    }
    public func check(current: SuiteVersion) throws(SuiteError) -> UpdateOffer? {
        if let unavailable { throw .notAvailable(unavailable) }
        return try UpdateFeed.newest(in: feed, above: current)
    }
    public func download(_ offer: UpdateOffer) throws(SuiteError) -> String {
        guard validSignatures.contains(offer.signature) else { throw .updateNotVerified }
        return "/tmp/AfterGlow-\(offer.version.major).\(offer.version.minor).\(offer.version.patch).zip"
    }
    public func install(zipAt path: String) throws(SuiteError) { installed.append(path) }
}

public actor FakeThumbnails: ThumbnailPublishing {
    public private(set) var written: [String: Data] = [:]
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }
    public func publish(png: Data, for ref: SuiteDocumentRef) throws(SuiteError) -> String {
        if let unavailable { throw .notAvailable(unavailable) }
        let path = "thumbnails/\(ref.fileID).png"
        written[path] = png
        return path
    }
}

public struct FakeHome: HomeBuilding {
    let creating: any DocumentCreating
    public init(creating: any DocumentCreating = FakeCreating()) { self.creating = creating }

    public func home(recents: RecentsList, running: [SuiteApp], query: String, filter: SuiteApp?,
                     order: [SuiteApp], missingApps: Set<SuiteApp>, missingFiles: Set<String>, now: Date) -> HomeState {
        let tiles = creating.tiles(missing: missingApps)
        let ordered = order.compactMap { app in tiles.first { $0.app == app } }
        let cards = recents.filtered(app: filter, query: query).map {
            RecentCard(item: $0, age: Self.age(of: $0.lastUsed, now: now), isMissing: missingFiles.contains($0.ref.fileID))
        }
        let empty: String?
        if !cards.isEmpty { empty = nil }
        else if recents.items.isEmpty { empty = "No recent work yet. Start something new above, or open a file." }
        else { empty = "Nothing matches \u{201C}\(query)\u{201D}." }
        return HomeState(tiles: ordered, cards: cards, running: running.filter { $0 != .launcher }, emptyMessage: empty)
    }

    /// "Today", "Yesterday", else days ago; the live type formats weekday and date with the locale.
    static func age(of date: Date, now: Date) -> String {
        let days = Int(now.timeIntervalSince(date) / 86_400)
        return days <= 0 ? "Today" : days == 1 ? "Yesterday" : "\(days) days ago"
    }
}

public struct FakeSizeBudget: SizeBudgetChecking {
    public init() {}
    public func evaluate(_ report: SizeReport, against budget: SizeBudget) -> [SizeFinding] {
        var out = report.entries.compactMap { e -> SizeFinding? in
            guard let limit = budget.limits[e.name], e.bytes > limit else { return nil }
            return SizeFinding(name: e.name, measured: e.bytes, limit: limit)
        }
        for (app, n) in report.suiteUISymbols.sorted(by: { $0.key < $1.key }) where n > budget.maxSuiteUISymbols {
            out.append(SizeFinding(name: "\(app) SuiteUI symbols", measured: n, limit: budget.maxSuiteUISymbols))
        }
        return out
    }
}
```

</details>

### 5.6 Hand-off flows, step by step

**New document from the home (UC-3, UC-5).** The home asks
`creating.handOff(for: preset, …)`, `sending.send` writes
`handoffs/<id>.aghandoff` and opens it with the app; the app's
`.suiteApp(_:)` modifier receives it (`onOpenURL`), `receiving.receive`
decodes and marks it accepted, the app runs its own New with the preset's
parameters, then `settle(id:as: .returned)`.

**Round trip (UC-6).** Library: Photo > Edit in Photo calls
`roundTrips.begin`, then sends an `.edit` hand-off carrying the original's
ref and the session id. Photo opens the original as a new untitled document
titled `session.title`; its Save writes the layered `.ora` and a flattened
copy in the original's format (PNG or JPEG; HEIC becomes JPEG) next to the
original, named `<name> edit <n>`, calls `photoSaved`, and sends a
`.returnEdit` hand-off to Library. Library imports the flattened copy,
stacks it on the original, calls `returned`. The original is never written.
Closing Photo's document unsaved calls `cancel`.

**Paste and drop (UC-7).** Copy in any app writes every representation
`pasteboard.representations(of:)` returns, richest first, plus the app's
own private type (Design's `org.creativesuite.design.layers`, Flare's
`org.creativesuite.flare.layers`) so a paste inside the same app keeps full
fidelity. Paste in an app first tries its own private type (its own model
reads it), then `bestItem(from:for:)`. The Edit menu's Paste is disabled
with `pasteRefusal(for:in:)`'s message. Drops use the same coding through
`DragBridge`.

**Linked placement (UC-8, UC-9).** Place from the Assets page or the colour
popover writes the asset's payload into the host document and stores its
`AssetLink` there. On activation and on every `assets` change notification
the host calls `linking.status`; `.updateAvailable` shows the mark, Update
replaces the payload in one undo step and stores `linking.updated`.
`.missing` keeps the last copy and says so.

---

## 6. Look

The suite look is `docs/design.md`. The house reference for every
inspector-like surface is Flare's easing editor: `StudioScrubRow` for
numbers, `ChoiceChips` and `PresetGrid` for presets, flat filled controls,
color only for state. This section says what AfterGlow adds. It edits no
shared doc: the `docs/design.md` additions in 6.4 land with the home
feature's last task (owned there, section 8), after SuiteUI's suite-record
wave, so the two never touch the file in the same wave.

### 6.1 Screens and their components

Component names are SuiteUI unless marked **new** (a `needs-ui` issue on
`line:suiteui`, 6.3) or system.

| Screen | Window | Region | Components |
|---|---|---|---|
| Home | `Window("AfterGlow", id: "home")`, `SuiteWindow` (follows the system appearance; it is a content window, not an editor), minimum 880 × 560, launch 1000 × 640 (#715's numbers) | Sidebar: Home, Assets, then APPS (the five, each with a running dot; a click filters the recents, a double-click switches) | `SidebarSection`, `SidebarRow` with the **new** trailing accessory slot for the running dot |
| | | New row: five tiles with their presets | **new** `AppTile` (app symbol, title, `ChoiceChips` of presets under it, disabled reason, progress ring after 100 ms); `ChoiceChips` |
| | | Recents: header, app filter chips, grid | `Text` in `SuiteFont.sectionCaps`; `ChipRow` (one chip per app plus All); `ThumbnailGrid` with **new** `ThumbnailBadges` app symbol and "Missing" warning badge; `.searchable` in the toolbar |
| | | Empty, error | `EmptyStateView` ("No recent work yet…", Open… prominent); the missing-file message in place under the card (Library's **requested** `InlineNotice`, S-L4 in #769) |
| | | Inspector (selected card) | `InspectorHeader` (name, app, modified, size), `InspectorAction` (Open, Open In ▸, Show in Finder, Remove from Recents) |
| | | Toolbar | Open… (`ToolbarAction`), search, the inspector toggle; "Preview data" pill while `isPreview` |
| Assets page | the home window's content when Assets is selected | Kind picker, grid, colours | `Picker(.segmented)` (All, Colours, Vector, Images, Animations); `ThumbnailGrid`; **new** `SwatchChip` grid for colours (swatch, hex, P3 badge) |
| | | Inspector (selected asset) | `InspectorHeader` (kind, revision, "From Cards.design"), `InspectorColorRow` for a colour, `InspectorAction` (Place In ▸, Copy, Remove) |
| Settings | `Settings` scene, `TabView` with General and one tab per app | Each tab is a `Form` | `Picker` (units; autosave 10 s, 30 s, 1 min, 5 min), `Toggle` (check for updates), `Button` (Check Now, Show Welcome Again); per-app tabs: the app's default New preset (`Picker`) and "At launch: reopen last documents / start empty" (`Picker(.radioGroup)`) |
| Onboarding | `Window` 720 × 520, opened once | Three pages | system `VStack` with `SuiteFont`; page 1: the five app symbols and names; page 2: `ChoiceChips` (Animation, Design, Photos, Motion, Everything); page 3: three sample `Button`s; Continue (prominent), Skip |
| Update | sheet on the home window | Offer, progress, error | `Text` (version, notes in a `ScrollView`), `ProgressView`, Install and Relaunch (prominent), Later; error with `stateError` and its symbol |
| Inside each app | the app's own menu bar | Window > Switch To ▸, File > Open In ▸, AppName > Settings… | system `Menu`/`Button` in `SuiteCommands` |
| | colour popovers (Flare FILL, Design fill, Photo foreground) | SUITE COLOURS section | **new** `SwatchChip` row; "Add to Suite Colours" `InspectorAction` |
| | Flare and Halo layer rows | linked asset | **new** `LayerList` accessory (link symbol; `stateWarning` triangle with "Update available"); SuiteUI's planned `LayerList` (#765 wave 2 lists-and-layers) |

### 6.2 Menus

Every item works or is disabled with a reason, never hidden (design.md
Commands).

- **AfterGlow** (launcher): About AfterGlow, Check for Updates…, Settings… ⌘,, Hide, Quit ⌘Q.
- **File**: New ▸ (New Animation, New Design, New Image, Import Photos…, New Composition), Open… ⌘O (routes by type), Open Recent ▸ (all apps, 20 newest, Clear Menu), Close ⌘W.
- **Edit**: Undo/Redo (Remove from Recents is undoable), Cut, Copy (a selected asset), Paste (into Assets: Add from Clipboard), Delete (Remove from Recents / Remove Asset), Select All.
- **View**: Show Sidebar, Show Inspector ⌥⌘I, Larger Thumbnails ⌘+, Smaller Thumbnails ⌘−.
- **Window**: Switch To ▸ (Home ⌃⌘0, Flare ⌃⌘1, Design ⌃⌘2, Photo ⌃⌘3, Library ⌃⌘4, Halo ⌃⌘5), Assets ⌥⌘A, then the system items.
- **Help**: AfterGlow Help (system).
- **In each app, added by `SuiteCommands`**: Window > Switch To ▸ (the same six, the current app checked and disabled "You're in Flare."); File > Open In ▸ (the readers of the front document, else disabled "No other app opens <type name> files."); <App> > Settings… ⌘, (opens AfterGlow Settings at that app's tab); <App> > AfterGlow Home ⌃⌘0. Library adds Photo > Edit in Photo (⌘E) through its own adoption task; Design adds Object > Add to Assets; Flare and Halo add Object > Update Linked Asset.

Control-Command with a digit is not one of the standard shortcuts design.md
reserves; BU-1's `SuiteCommandsTests` checks that no app's menus already
bind ⌃⌘0–⌃⌘5.

### 6.3 What SuiteUI needs to add (filed by the home and shared-assets features as `needs-ui`)

| Component | For | Spec |
|---|---|---|
| `AppTile` | home New row | A `Button` whose label is the app symbol (32 pt), title in `SuiteFont.body` semibold, and an optional `ChoiceChips` under it; flat `panel` fill, radius `SuiteRadius.card`; disabled at 40% with `.help(reason)`; a `ProgressView` ring replaces the symbol while launching. Goldens in four appearances (QB-V5) |
| `ThumbnailBadges` app symbol + missing | recents grid | Extends the existing `ThumbnailBadges`: a leading app symbol badge and a trailing `stateWarning` triangle with "Missing". Library's S-L2 (`ThumbnailGrid` hooks) is the same file: one issue, filed against Library's |
| `SidebarRow` trailing accessory | running dot | A 6 pt dot in `textSecondary` (running) next to the title; the dot has an accessibility value "Running" |
| `SwatchChip` | Assets page, colour popovers | 24 pt rounded swatch (radius `SuiteRadius.row`) with the hex under it in `SuiteFont.caption` tabular; a "P3" caption badge for Display P3 colours; selected = `stateSelected` outline |
| `LayerList` accessory | link mark on layer rows | The planned `LayerList` (#765) gains a trailing accessory slot; the suite puts the `link` symbol there, or the `stateWarning` triangle when an update is available |

None of these is in #765's plan; each is a `needs-ui` issue filed by the
feature that first needs it (home: `AppTile`, `ThumbnailBadges`, `SidebarRow`
accessory; shared-assets: `SwatchChip`; linked-assets: `LayerList`
accessory). Until it merges, the feature uses a plain SwiftUI placeholder
and keeps going (CLAUDE.md).

### 6.4 Additions to `docs/design.md` (a new "AfterGlow" section)

1. **One family, one mark per app.** In UI each app is its SF Symbol and
   name: Flare `scribble.variable`, Design `square.on.circle`, Photo
   `paintbrush.pointed`, Library `photo.on.rectangle.angled`, Halo
   `film.stack`, AfterGlow `square.grid.3x3.square`. SF Symbols are never
   used as Dock icons (their license reserves them for UI); Dock icons come
   from `Bundle/Icons/` (art: Q4).
2. **The home is a content window.** It follows the system appearance; the
   editors stay dark (Editor shell). Cards and tiles are flat content, no
   glass; the sidebar and toolbar are the system's.
3. **Cross-app commands live in the same place in every app**: Window >
   Switch To, File > Open In, <App> > Settings…, Edit > Paste with the
   suite's refusal text. Never a toolbar-only route.
4. **Moving work keeps its memory**: a linked item shows the `link` symbol;
   "Update available" uses `stateWarning` with its triangle; a missing
   source says "using the last copy" in `textSecondary`.
5. **A hand-off is never silent**: the target app comes forward; if it
   takes longer than 100 ms the source shows progress (QB-L9).

---

## 7. Quality bar

Every item names what measures it and where it runs: **Linux** (`scripts/ci`,
any PR), **macOS CI** (the `macos` job on `dev`: snapshots, journeys, the
audit, the size report), or **local** (`scripts/ui-test` on a Mac). Ids
`QB-S…` are the suite's rows; they join `docs/review-rubric.md` section 6
when the switching feature's last task lands (it owns that file in its
wave, section 8). Gates follow the rubric's "How gates are set": a new perf
row ships report-only, and after ten green CI runs its gate is the measured
CI p95 × 1.5, never tighter than the device target, written as a constant in
`UITests/Journey+Budgets.swift`.

### 7.1 Input-to-screen budgets (interactive)

Cross-process times pair a mark from the process that took the input with a
mark from the process that drew the result. Both stamp
`mach_continuous_time` (one system-wide clock), so the difference is valid
across processes; frames late are counted against the target process's
display refreshes, as the rubric counts them.

| id | Interaction | Device target | CI gate | Test |
|---|---|---|---|---|
| QB-S1 | Switch to a running app (⌃⌘<n>, home row, Switch To menu): key event → first frame of the target's key window drawn frontmost | p95 ≤ 6 refreshes (100 ms at 60 Hz) | report-only, then set from CI | SP1, 30 switches, at least 30 samples or the test fails as invalid |
| QB-S2 | First open of an app per session (cold launch from the home): click → first frame of its window | ≤ 700 ms median, ≤ 1 s p95 | report-only, then set from CI | SP2, each app 5 times after terminating it |
| QB-S3 | AfterGlow cold launch → home first frame; first frame → recents shown (200 recents) | ≤ 500 ms; ≤ 100 ms | report-only | SP3 |
| QB-S4 | Type in recents search → filtered grid drawn | p95 ≤ 2 frames late | placeholder 3 | SP4, 20 keystrokes |
| QB-S5 | Paste across apps → pasted item drawn (50 shapes from Design into Flare; a 24 MP image into Photo) | ≤ 100 ms; ≤ 300 ms, with progress shown by 100 ms (QB-L9) | report-only | SP5 |
| QB-S6 | Routed open (Finder or Open In) → document window's first frame; target running / cold | ≤ 300 ms / ≤ 1 s | report-only | SP6 |
| QB-S7 | Edit in Photo → Photo shows the image (24 MP, Photo running); Photo Save → Library's thumbnail updated | ≤ 1 s; ≤ 1 s | report-only | SP7 |
| QB-S8 | A setting changed → applied in every running app | ≤ 500 ms | report-only | SP8 |
| QB-S9 | Drag a card or asset across apps: the drag image follows the pointer; the drop target highlights | p95 ≤ 2 frames late in the source; highlight ≤ 1 frame after enter | report-only | SJ14 with the probe |
| QB-L9 | Any action that waits (cold open, round trip, update check, large paste) shows progress | ≤ 100 ms after the command, by the probe mark | as the rubric | the journeys' `*-progress` marks |

**Model budgets** (Linux and macOS, `Tests/SuiteModelTests/Budget.swift`,
debug gate ×10 like the rubric):

| id | Call | Device target | Debug gate |
|---|---|---|---|
| QB-SM1 | `RecentsList.note` into 200 items; `merging` two lists of 200 | ≤ 0.2 ms; ≤ 2 ms | ≤ 2 ms; ≤ 20 ms |
| QB-SM2 | `HomeBuilding.home` over 200 recents with a query | ≤ 2 ms | ≤ 20 ms |
| QB-SM3 | `AssetIndex.search` over 5,000 assets | ≤ 5 ms | ≤ 50 ms |
| QB-SM4 | `HandOffCodec` encode + decode | ≤ 0.2 ms | ≤ 2 ms |
| QB-SM5 | `PasteboardCoding.bestItem` over 6 representations | ≤ 0.1 ms | ≤ 1 ms |
| QB-SM6 | `FileStore` write with a revision race: two tasks each note 500 recents into one temp store | no entry lost (1,000 present), each write ≤ 5 ms median | ≤ 50 ms |

### 7.2 App audit

All six checks of `docs/blueprints/app-audit.md` apply to every AfterGlow
shot (home, Assets, Settings, onboarding, update sheet): `disabled-dim`,
`overlap`, `contrast`, `identifier`, `offscreen`, `unnamed`. The launcher
gets the key `afterglow` in `UITests/audit-baseline.json` with every count
at 0 (a new app at 0 is not a loosening), so any violation fails the
journeys from the first run. The suite commands added inside the apps are
audited under each app's own key; their PRs must not raise those counts.

### 7.3 Layout spec

The home's column math is `HomeLayout` (section 5.4): sidebar 200 pt,
margins 24 pt, gap 16 pt, card 168–240 pt. Tiles share the row:
`min(240, (content − 4 × 16) / 5)`.

| Window width | Content | Grid columns | Card width | Tile width |
|---|---|---|---|---|
| 880 (minimum) | 632 | 3 | 200 | 113 |
| 1000 (launch) | 752 | 4 | 176 | 137 |
| 1280 | 1032 | 5 | 193 | 193 |
| 1728 | 1480 | 8 | 171 | 240 |

Checked, at each of the four widths:

1. **Linux**, `HomeLayoutTests`: the table above, exactly; columns never 0;
   card width within 168–240 for every width from 880 to 2560 in 1 pt
   steps.
2. **macOS CI**, `AfterGlowHomeLayoutTests` (AppSnapshotTests): the home on
   the `weekOfWork` fixture rendered at the four widths; frames read through
   anchor preferences. The tile row, the RECENT header and the grid share
   one left edge (±0.5 pt); no card or tile crosses the content's right
   edge; no two cards overlap; card origins sit on the 4 pt grid; the
   sidebar is 200 pt. The same check for Settings (fixed 560 pt wide: every
   `Form` row's leading labels align, ±0.5 pt) and onboarding (720 × 520:
   Continue and Skip inside the window with 24 pt margins).
3. **macOS CI**, journey `testHomeAtEveryWidth` (`+Layout`, home): resizes
   the window to the four widths and shoots each; the audit's `offscreen`
   and `overlap` stay at 0.

### 7.4 Fidelity (output equals a reference)

| id | Check | Reference | Test |
|---|---|---|---|
| QB-SV1 | A home thumbnail is the app's own picture of the document: the 512 px PNG equals the app's export of the first frame or page scaled to 512 px | the app's PNG export, QB-V2 tolerance | `ThumbnailFidelityTests` per app (macOS, each app's adoption task) |
| QB-SV2 | Colours cross apps exactly: a colour copied from Design, pasted in Flare, added to Suite Colours and placed in Photo keeps its space and components (no conversion on the way) | `SuiteColorValue` equality, both sRGB and Display P3 | Linux `PasteboardColorTests`; SJ6 and SJ13 read the hex |
| QB-SV3 | Vector art crosses apps: Design's selection pasted into Flare draws the same as Design's own render of it | Design's PNG export of the selection, QB-V2 tolerance; curves stay curves (QB-V1) | `CrossAppVectorGoldenTests` (AppSnapshotTests, clipboard-drag) |
| QB-SV4 | Flare in Halo: Halo's frame N of an imported animation equals Flare's PNG export of frame N | Flare's export, QB-V2 tolerance, N = 0, 12, 47 | `FlareInHaloGoldenTests` (flare-in-halo) |
| QB-SV5 | Round trip keeps the original: after SJ10, the original file's bytes are unchanged; with no edit, the returned copy equals the original's pixels | SHA-256 of the original; pixel equality (tolerance 0) | `RoundTripFidelityTests` (macOS) and SJ10 |
| QB-SV6 | A linked asset placed in Flare draws the same as the asset's payload rendered by Design | Design's render, QB-V2 tolerance | `LinkedAssetGoldenTests` (linked-assets) |
| QB-SV7 | Every new component and screen has goldens: home, Assets, Settings tabs, onboarding pages, update sheet, in Light, Dark and both with Increase Contrast (QB-V5) | committed goldens | `AfterGlowSnapshots` (AppSnapshotTests) |
| QB-SV8 | Hand-off files and the store files round trip byte for byte (encode → decode → encode) | the first encoding | Linux `StoreRoundTripTests` |

### 7.5 Size budget

`scripts/size-report` (BU-5) measures, on every macOS CI run on `dev`:
bytes of each app executable, each framework, each embedded app bundle, the
launcher, the whole `AfterGlow.app` and the tarball; and the SuiteUI symbols
defined in each app executable (`nm -U`). `SizeBudget.evaluate` decides.

| Entry | Budget (provisional) | Gate |
|---|---|---|
| Each app executable (`Contents/Helpers/<X>.app/Contents/MacOS/<X>`) | its own code and Model only; at most 60% of today's size for that app (today 2.9 to 5.8 MB) | report-only for the first ten runs, then the measured maximum × 1.10, never above the provisional number |
| `SuiteUI.framework` | ≤ 4 MB | as above |
| `CreativeEngines.framework` | ≤ 6 MB | as above |
| `SuiteModel.framework` + `SuiteShell.framework` | ≤ 2 MB together | as above |
| Launcher executable | ≤ 2 MB | as above |
| Whole `AfterGlow.app` (uncompressed) | ≤ the sum of today's five executables + 10% (BU-0 records the sum) | as above |
| `app-builds.tar.gz` | ≤ 15 MB | as above |
| SuiteUI symbols defined in any app executable | 0 | hard from the first run after BU-4 |

Detailed size work (dead-code stripping, asset compression, per-framework
trimming) is a later phase; this gate only stops growth and proves the
split worked.

### 7.6 Reliability

| Check | Measured by |
|---|---|
| No work lost when switching: SJ3's state after two switches equals the state before | SJ3 asserts the frame, selection and zoom values |
| A crash in one app leaves the others running with their documents | journey `testCrashIsolation` (`+Switch`): kill Flare's process; Design's window, document and dirty dot unchanged; the home drops Flare from the running rows within 1 s |
| Two processes writing the store at once lose nothing | QB-SM6 (Linux) |
| An expired or newer-format hand-off never acts | Linux `HandOffCodecTests` (main.swift's checks, moved) |
| Quit from the updater runs each app's unsaved-changes flow; a Cancel stops the update | journey `testUpdateWaitsForUnsavedWork` (`+Update`): a dirty Design document, Install → Design's save prompt → Cancel → the update stops with "Update postponed: Design has unsaved changes." |
