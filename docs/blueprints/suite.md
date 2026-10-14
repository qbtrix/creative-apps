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
| #763 | dev is red (macOS job, mac-platform range) | Blocks every merge, the way priorities.md rule 4 treats creative-core #211 |

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
| Recovery policy | The suite rule: a document app autosaves to a recovery file and offers a restore at next launch (Flare's mac-platform design). Each app adopts it on its own line when its blueprint schedules it: Flare v1, Photo v2; Design and Halo per Q6. Settings shows the autosave interval only for apps that autosave, and says why for the others | Version browser |
| Copy, paste, drag | Typed pasteboard and drag data between apps: colours everywhere; vector art Design → Flare (as SVG plus the suite asset envelope), and Flare → Design once Flare's SVG export (#366) and Design's SVG import land; images into Photo and Library; plain text where text is accepted; files (`public.file-url`) dropped on any app or the home open in the right app | Halo layers to Flare and back, pasting Photo layers with masks into other apps |
| Library ↔ Photo | Edit in Photo from Library; Photo opens the photo as a new document tied to the round trip; Save in Photo returns an edited copy to Library, stacked beside the original; the original is never changed | Develop settings carried into Photo as adjustment layers |
| Shared assets and colours | One asset library (colours, vector art, images, animations) in the home's Assets page and in each app's colour popover; add from any app; place into any app that reads that kind | Tags, smart folders, gradients and text styles as assets |
| Linked placement | Placing a Design asset in Flare or Halo keeps a link: an "Update available" mark when the asset changes; Update replaces it in one undo step; a missing source keeps the last copy | Live (unprompted) updates, editing the source in place from Flare |
| Flare in Halo | **Conditional:** in v1 only if Halo's "Flare scene as a layer" (H10, Later in #767) and the engine issues of 8.5 land in time; otherwise v1.1. Open In ▸ Halo on a `.flare` makes a composition the scene's size, rate and length with one animation layer linked to the file | Several scenes, nested Halo comps from Flare symbols, time remapping |
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
| suite-identity | `SuiteApp` (the five apps plus the launcher), bundle ids, the one id prefix (`Values/SuiteIdentity.swift`, BU-1's placeholder), and `SuiteTypeRegistry`: every document and pasteboard type each app reads and writes, with the default app per type | `Values/` | used by every other component; mirrored by `Bundle/Info/*.plist` (checked by a test) |
| suite-store | `SuiteLocations` (the support folder, overridable with `-SuiteSupportDir`), `FileStore`: JSON files written atomically with a revision number under an exclusive lock file (`<name>.lock`, POSIX `flock`), so two processes never interleave read-merge-write | `Store/` | used by recents, assets, preferences, hand-offs |
| suite-contracts | One protocol per use case (section 5) | `Contracts/` | implemented by fakes, stores and SuiteShell's live types |
| suite-fakes | A fake per contract with `unavailable:`; `SuiteFixtures` (the journeys' store contents, written into the live store by the launcher) | `Fakes/` | used by snapshots and Model tests; journeys use the live store seeded from the fixtures |
| suite-services | `SuiteServices` with `.fake` and `.live` slots | `SuiteServices.swift` | assembled live in SuiteShell |
| suite-recents | `RecentsList` (merge, dedupe by file identity, cap 200, filter by app, search), recording rules | `Recents/` | store; home; each app's Open Recent |
| suite-routing | Which app opens a type, the Open In list for a document, Finder routing decisions | `Routing/` | registry; launcher router; Open In menu |
| suite-handoff | `HandOff` values (verb, payload, return address), codec and lifecycle | `HandOff/` | transport in SuiteShell; round trip; new document |
| suite-switching | Switch requests and receipts, run states, the Switch To menu model | `Switching/` | SuiteShell launcher; home |
| suite-home | Home state: new tiles and presets, recents grid sections, running apps strip, `HomeLayout` column math, and `HomeModel`, the home window's `@Observable` view-model (`public private(set)` state, a method for every action; section 5.6) | `Home/` | AfterGlowApp home views |
| suite-pasteboard | `SuiteClipItem` and its typed representations; best-item choice for a target app | `Pasteboard/` | SuiteShell bridges; each app's paste |
| suite-roundtrip | Library → Photo → Library sessions and their states | `RoundTrip/` | hand-off; Library and Photo adoption |
| suite-assets | `SuiteAsset`, colours, the asset index (add, update with revision, remove, search), `AssetsModel` (the Assets page's view-model) | `Assets/` | store; Assets page; each app's colour popover |
| suite-links | `AssetLink` and its status (current, update available, missing) | `Links/` | assets; Flare and Halo adoption |
| suite-animation | `AnimationSummary` of a `.flare` for Halo's import | `Animation/` | Halo adoption |
| suite-preferences | `SuitePreferences` (General plus a pane per app), defaults, change records, `SettingsModel` | `Preferences/` | store; Settings scene; every app |
| suite-onboarding | Pages, choices, when to show, `OnboardingModel` | `Onboarding/` | AfterGlowApp |
| suite-update | Update feed parsing, version compare, offer, install plan, `UpdateModel` | `Update/` | AfterGlowApp updater |
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
| shell-adoption | `.suiteApp(_:host:)`: the modifier an app adds to its scene (the commands, the store watcher, the settings route), and `SuiteAppDelegate`, an open class the app's `@NSApplicationDelegateAdaptor` uses (or subclasses, as Photo's PV-1 delegate will): its `application(_:open:)` receives hand-off files even with no window open and passes each to the app's `SuiteDocumentHost` | `SuiteAppModifier.swift`, `SuiteAppDelegate.swift`, `SettingsRoute.swift` |

**AfterGlowApp** (`Sources/AfterGlowApp/`, macOS, all planned)

| Component | Responsibility | Paths |
|---|---|---|
| launcher-scene | `@main AfterGlowApp`: the home `Window`, the `Settings` scene, the onboarding window, the update sheet; an app delegate that routes opened files to the right app. Its menus are separate `Commands` types, one file per feature (`LauncherCommands+Home.swift`, `+Settings`, `+Assets`, `+Update`), all created as stubs by BU-1 so no later feature edits `AfterGlowApp.swift` | `AfterGlowApp.swift`, `LauncherRouter.swift`, `LauncherCommands*.swift` |
| home | The home window: New tiles, recents grid, search, app filter, running apps strip | `Home*.swift` |
| assets-page | The Assets page of the home sidebar | `Assets*.swift` |
| settings | General and per-app panes | `Settings*.swift` |
| onboarding | The three first-launch pages | `Onboarding*.swift` |
| updater | Check, offer sheet, progress, install | `Update*.swift` |

### 2.4 Relationships

| From | To | What |
|---|---|---|
| each `<X>Model` | SuiteModel | conforms to `SuiteDocumentHost` (acts on hand-offs); declares its document kinds and pasteboard representations; reads preferences |
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
The macOS numbers are measured before any packaging change lands, by two
wave-0 tasks: BU-0 (sizes and duplicated SuiteUI symbols of today's five
bundles, from the `macos` job's new `size-report`) and BU-S, a spike run
locally on a Mac with `scripts/ui-test` (no CI dispatch needed): it times
shape B's two costs on today's bundles (cold launch to first window, and
activation of a running app, each 20 times with `ProcessInfo.systemUptime`
stamps from a tiny launcher harness) against shape A's equivalent (a second
scene opened inside one running process), and resident memory of five
running apps against one. Its numbers go into `docs/blueprints/suite/spike.md`
and decide Q12 (approve B as measured, or reconsider). The R1 linking spike
is BU-3 (one owner).

**Shared frameworks: how.** SwiftPM links a library target into an
executable of the same package statically, and a package cannot depend on
its own products, so `Package.swift` alone cannot make SuiteUI a shared
framework without moving its sources into a second package (which would
rename every SuiteUI path that six lines are editing). Two routes:

| Route | What changes | Risk |
|---|---|---|
| R1 (chosen): the release graph in `project.yml` | XcodeGen already builds the journey bundles. A `Release` section adds framework targets compiled from the existing folders: `SuiteUI.framework` (`Sources/SuiteUI`), `SuiteModel.framework`, `SuiteShell.framework`, and `CreativeEngines.framework` (one source file, `Bundle/Engines/CreativeEngines.swift`, that re-exports FlareCore, CoreRaster and CoreColor, and is the only target that links the creative-core package products). Each `<X>Model` becomes a static library that links `CreativeEngines`; each `<X>App` an application target with `@executable_path/../../../../Frameworks` on its run path. `Package.swift` keeps its Linux and test graph; no source path moves | Two build descriptions can drift: `BuildGraphTests` (Linux, `Tests/SuiteModelTests`) reads both files and fails when a target in one is missing from the other. Model sources import FlareCore through the re-export: BU-3 proves it builds |
| R2: second package | `Packages/Shared/Package.swift` with `.dynamic` products; SuiteUI sources move there | Renames every SuiteUI path mid-flight (six open blueprints plan edits there); C4, the design lint and the app-state rule move with it |

If BU-3 shows R1 cannot link the engines once (for example a module that
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
   bundle in the `Journeys` scheme. `BuildGraphTests` reads it on Linux by
   line scanning (target names sit at a fixed indent under `targets:`), so
   no YAML library is needed.
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
4. `scripts/size-report` (new in BU-0 for today's five bundles; BU-4 extends it to `AfterGlow.app`): reads the assembled bundle and writes
   `.build/size-report.json` (`SizeReport`, section 5): bytes per
   executable, per framework, per app bundle and for the whole bundle,
   uncompressed and in the tarball, and the count of SuiteUI symbols
   defined in each app executable (`nm -U`, demangled, module `SuiteUI`,
   generic specializations and inlined copies excluded; section 7.5).
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
launch with the file). The app receives it in `SuiteAppDelegate`'s
`application(_:open:)`, not in a view's `onOpenURL`: an app with no window
has no view, and a `WindowGroup` would open a new window per incoming URL.
BU-S's spike confirms this on macOS 26 before switching starts. Launch arguments are not used for this: they are
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

**Journey launch arguments.** The launcher forwards to an app it starts
cold every launch argument named for that app (`-Design*` to Design,
`-Flare*` to Flare) plus `-SuiteSupportDir` and `-SuitePerfProbe`, so a
journey can pass `-DesignSaveTo` through the launcher.

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
  and, for perf, `-SuitePerfProbe YES`. The launcher forwards
  `-SuiteSupportDir`, `-SuitePerfProbe` and every argument named for an app
  to that app when it launches it cold (`NSWorkspace.OpenConfiguration.arguments`;
  section 2.6). An embedded app is driven through
  `XCUIApplication(bundleIdentifier:)` once it runs. Today's `Journey` knows
  one app (it builds `.build/apps/<X>App.app` and shoots that app's
  windows), so HM-0 adds `UITests/Journey+Suite.swift`:
  `Journey(bundlePath:bundleID:auditKey:)` and `attach(_ app: SuiteApp)`,
  which shoots and audits the front process's windows under that app's own
  audit key. `tearDown` terminates every suite process.
- **Fixtures.** Journeys run on `.live` in every process. The launcher,
  given `-SuiteFixture <name>`, writes `SuiteFixtures.store(name, …)` into
  the tmp store with `FileStore` before its first frame, and copies the
  fixture documents from `UITests/Fixtures/suite/` into `<tmp>/Documents`;
  what one app then writes, the others read. `.fake` is for snapshots and
  Model tests only. The documents in `UITests/Fixtures/suite/` are written
  by each app line's fixture export test (adoption issue A-x-0, 8.4), so
  they are real files of each format; a missing one shows as Missing, which
  is why the journeys that open them wait on A-x-0.

| Fixture | Contents |
|---|---|
| `empty` | no recents, no assets |
| `weekOfWork` | 8 recents over 7 days, newest first: `Logo.design` (Design `cards`, one page renamed), `Cards.design` (Design `cards`), `Bounce.flare` (Flare `bounce`), `Intro.halo` (a Halo two-layer comp), `beach.ora` (Photo two-layer), `Title.flare` (Flare `empty` plus one rectangle), `Sunset.png` (Photo's 1600 × 1067 test image), `Logo animated.flare` (Flare `bounce` renamed); a thumbnail per file; and Library's three sample photos imported (as `roundTrip`), so SJ6 and SJ14 have a catalog |
| `missing` | `weekOfWork` with `Cards.design` deleted from disk |
| `roundTrip` | a Library catalog of 3 photos (Library's `LibrarySample` seed 2026) and an empty Photo |
| `assets` | 6 colours (two in Display P3), 2 vector assets (`Card`, `Badge`, SVG from Design's `cards`), 1 image (`Sunset`), 1 animation (`Bounce`) |
| `crowd` | 200 recents (`Doc 0.flare` … `Doc 199.flare`) for SP3 and SP4; SP5's 50-shape Design selection is Design's `cards` duplicated to 50 shapes, its 24 MP image is `UITests/Fixtures/suite/large.png` (6000 × 4000) |
| flags | `-SuiteUpdateFeed <file URL>` (SJ15: `feed-newer.json` signed with the test key, `feed-forged.json`); `-SuiteHideApp <app>` (SJ2); SJ18's samples ship in `Bundle/Samples/` (BU-5: one per app, copies of the fixtures) |

- **Waiting and timing.** As the Flare blueprint: state changes are awaited
  with `waitForExistence` or a value predicate (2 s); timing claims come
  only from probe marks. Cross-process timings use marks from two processes
  on one clock, the system uptime clock (`ProcessInfo.systemUptime`, the
  domain `NSEvent.timestamp` uses), so an input event's own timestamp and
  the target's frame mark compare directly. Each process's `FrameProbe`
  (#330, named marks #782) writes them; the test reads both `suite.perf`
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

Asserts: 8 recent cards newest first; every menu holds the items section
6.2 lists for it (system-added items such as Services are not counted); every enabled control changed the shot or a value, every
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
`runningForeground` and its window title; the home's after ⌃⌘0. Steps 3
and 4 need the live hand-off transport, so they run as
`testOpenRecentBringsAppForward` in `+Switch` (switching); the home feature
ships steps 1, 2, 5 and 6 on the fakes, where step 3 asserts the fake's
sent hand-off through `suite.controls`. *Empty:*
"No recent work yet. Start something new above, or open a file." with
Open… as the one prominent button. *Error:* the missing-file message in
place, never an alert. *Loading:* a card whose thumbnail has not loaded
shows its app's symbol on the `panel` fill (snapshot `afterglow-home-loading`).

**SJ2 `testNewDocumentByType`** (`+New`, switching: it needs the live hand-off transport) · `empty`
1. Click the "Vertical 9:16" preset chip under New Animation → Flare comes
   forward with a new untitled animation.
2. ⌃⌘0; New Design → Design's new untitled file.
3. ⌃⌘0; New Image → Photo's New Image sheet.
4. ⌃⌘0; New Composition → Halo's New Composition sheet.
5. ⌃⌘0; Import Photos… → Library comes forward with its Import Folder panel.

Asserts: each app frontmost with the named window or sheet; Flare's info
card reads 1080 × 1920 (once Flare's F11b #351, the New Animation sheet, lands; until then the
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
5. In Flare ⌘W (close the last window), then Window > Switch To > Show Flare Window (⌃⌘1; enabled because Flare has no window).

Asserts: after 3 and 4, Flare's frame readout 12, selection Ball, zoom pill
200%, same window; after 5 Flare is still running (it never quit) and
opens a window (the empty state, as a reopen). The strip lists Flare and
Design with a running dot. *Empty:* Design's own empty state at step 2.
*Error:*
switching to an app that crashed since: the strip drops it within
1 s and ⌃⌘<n> launches it cold (Model test `SwitchRunStateTests`; the
journey sends Design `SIGKILL` (`kill(pid, SIGKILL)`, the pid from Design's
probe) and asserts the strip; if the test runner may not signal another
process, this step runs locally only and says so). *Loading:*
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
1. CI registers the bundle first (`lsregister -f .build/apps/AfterGlow.app`;
   the old `<X>App.app` paths are symlinks into it, so no second copy holds
   the same bundle ids). The test runner opens `<tmp>/Documents/Cards.design`
   with `NSWorkspace.open(_:)` (Launch Services picks the app), then again
   with `open(_:withApplicationAt:configuration:)` at `AfterGlow.app` (the
   launcher's router).
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
   Photo File > New from Clipboard (Photo PV-2's "paste another app's image as a new image", #768).
5. In Flare, with an image on the pasteboard, open the Edit menu.
6. (Once Flare's SVG export #366 and Design's SVG import land) in Flare
   select Ball; ⌘C; ⌃⌘2; in Design ⌘V.

Asserts: Flare's layer list gains "Card" with the card's fill hex and a
path of the same bounds (±0.5 pt); after 3 the fill hex equals Design's
(Copy Color and Paste Color are Edit-menu commands each app adds for its
colour rows, A-x-3);
Photo's new image has the photo's pixel size; at 5 Paste is disabled with
"Flare can't paste images yet."; after 6 Design has a layer "Ball" of the
same bounds; Each paste is one undo step ("Undo Paste").
*Empty:* paste with an empty pasteboard is disabled "Nothing to paste."
*Error:* a damaged suite envelope falls back to the next representation
(SVG, then PNG) and says nothing; with none readable, the disabled reason.
*Loading:* pasting a 24 MP image shows progress after 100 ms (probe
`paste-progress`).

### 4.3 Tier-2 and tier-3 journeys

| # | Test (file, feature) | Fixture | Steps | Asserts; empty / error / loading |
|---|---|---|---|---|
| SJ10 | `testEditInPhotoAndBack` (`+RoundTrip`, photo-round-trip) | `roundTrip` | Library loupe on photo 2; Photo > Edit in Photo (⌘E); in Photo raise exposure via a Photo tool; ⌘S; ⌃⌘4 | Photo's title "IMG_0002 (Library edit)"; Library shows a stack of 2 with the edited copy first and the original unchanged byte for byte; the edit's thumbnail differs from the original's. Error: original missing → "The original of IMG_0002 is missing. Locate it in Library first."; Photo closed without saving → the session ends, nothing added; loading: progress in Library's status pill while Photo opens (probe) |
| SJ11 | `testOpenIn` (`+OpenIn`, recents-open-in) | `weekOfWork` | In Photo with `Sunset.png`, File > Open In ▸; pick Library | the submenu lists Library only (Photo excluded); Library imports the file and selects it. Empty: in Design with `Cards.design`, Open In is disabled "No other app opens Design Document files." (`openInRefusal`) |
| SJ12 | `testSettingsFromAnyApp` (`+Settings`, settings) | `empty` | In Flare ⌘, ; change General > Units to Centimeters; open Design; its rulers | the AfterGlow Settings window opens at the Flare pane; Design's ruler unit reads cm within 500 ms (QB-S8); ⌘, in the launcher opens General |
| SJ13 | `testSharedColoursAndAssets` (`+Assets`, shared-assets) | `assets` | Home > Assets; add a colour from Design's colour popover ("Add to Suite Colours"); in Flare the FILL popover's Suite Colours section; click it | the Assets page count +1; Flare shows the same 7 swatches; the fill equals the swatch exactly (sRGB and P3 kept). Empty: "No assets yet. Use Add to Assets in any app." |
| SJ14 | `testDragBetweenApps` (`+Drag`, clipboard-drag) | `weekOfWork` | the test runner drops `<tmp>/Documents/Intro.halo` on the home (a `public.file-url` drag it starts from a helper window); drag the `Sunset.png` card from the home onto Photo's empty canvas; drag a Library thumbnail onto Photo | Halo opens `Intro.halo`; Photo opens Sunset, then adds the photo as a layer; Photo's drop-target highlight mark precedes the drop (probe). If a cross-app XCUITest drag proves unreliable on the runner (BU-S checks), the Photo steps run locally only and `DropRoutingTests` (Linux) carries CI |
| SJ15 | `testCheckForUpdates` (`+Update`, updater) | `-SuiteUpdateFeed file://<tmp>/feed.json` with a newer version | AfterGlow > Check for Updates… | the offer sheet with version and notes; Later closes it; a bad signature fixture → "This update couldn't be verified, so it wasn't installed." Loading: progress within 100 ms |
| SJ16 | `testPlaceLinkedDesignAsset` (`+Links`, linked-assets) | `assets` | Assets page: select Card, Place In ▸ Flare; in Design open `Cards.design`, change the card's fill, Object > Update Asset (enabled because `assets(fromFileID:)` lists Card); back in Flare; then the same with Place In ▸ Halo (`testPlaceLinkedInHalo`) | Flare's layer shows the link badge; then "Update available"; Update → one undo step "Undo Update Linked Asset"; Missing source → "Linked asset is missing; using the last copy." (`SuiteError.linkMissing`) |
| SJ17 | `testOpenFlareInHalo` (`+FlareInHalo`, flare-in-halo) | `weekOfWork` | In Flare with `Bounce.flare`, File > Open In ▸ Halo | Halo makes a composition 1920 × 1080, 24 fps, 48 frames with one animation layer "Bounce"; Halo's frame 12 equals Flare's PNG export of frame 12 (QB-SV4) |
| SJ18 | `testFirstLaunchOnboarding` (`+Onboarding`, onboarding) | `empty`, no skip flag | launch; Continue ×2 choosing "Photos"; Open Sample | the home orders Library and Photo first; relaunch shows no onboarding; Settings > General > Show Welcome Again brings it back |
| SJ19 | `testEveryControlActsOrSaysWhy` (`+EveryControl`, home) | `weekOfWork` | the `suite.controls` sweep for home, Assets, Settings | as Flare's J29; never cited by the matrix |

### 4.4 Perf journeys (`+Perf`, each feature its own)

| # | Test | Measures | Budget (section 7.1) |
|---|---|---|---|
| SP1 | `testSwitchToRunningAppLatency` | 30 switches ⌃⌘1/⌃⌘2 between two running apps; marks: key event in the source, `didBecomeActive` and first frame of the key window in the target | QB-S1 |
| SP2 | `testColdOpenEachApp` | home tile → first frame of the app's window, each app 20 times, terminating it between runs | QB-S2 |
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
`Sendable`). The six files below are also committed as
`docs/blueprints/suite/contracts/{Values,Contracts,Fakes,Services,Packaging,HomeModel}.swift`
with `main.swift` (smoke checks of every fake against the behavior this
blueprint states) and `check.sh`, which compiles them with `swiftc
-swift-version 6 -warnings-as-errors` and runs them. On this session's
Linux toolchain (swift 6.3.3) it prints `contracts: PASS`. Tasks SC-1 to SC-4 move
them into `Sources/SuiteModel/` (one file per protocol and per fake; the
pure helpers that belong to a later feature's folder, such as `RecentsList`
in `Recents/`, `HomeLayout` in `Home/` and `UpdateFeed` in `Update/`, are
created there by SC-1 and owned by that feature from its wave) and their
checks into `SuiteModelTests`.

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
| 17 | `SizeBudgetChecking` (in `Packaging.swift`: not a runtime service, so not in `SuiteServices`) | 3 | `FakeSizeBudget` (reference) | same type in `Packaging/` | bundle |
| 18 | `SuiteDocumentHost` (each app acts on a hand-off) | 1 | `FakeDocumentHost` (records, refuses verbs it doesn't take) | each `<X>Model` (adoption A-x-1) | switching |

`RecentWork`, `AssetLibrary`, `PreferencesStoring` and `AppSwitching` each
have `changes() -> AsyncStream<Int>`: the live types yield after a
`org.creativesuite.suite.changed` notification for their file (or a run
state change), the fakes after their own writes. That is what the home's
running rows, QB-S8 and the link checks listen to.

`.live` is assembled per process: SuiteShell's slot files cover every
member it can reach; `SuiteServices.with(animations:updates:)` lets HaloApp
supply the animation reader (HaloModel links FlareCore) and AfterGlowApp the
updater (it owns the bundle), since SuiteShell sees neither.

Which journey each contract serves: UC-1 SJ3, SP1, SP2; UC-2 SJ1, SJ4; UC-3
SJ2; UC-4 SJ5, SJ11; UC-5 SJ1, SJ2, SJ5, SJ10; UC-6 SJ10; UC-7 SJ6, SJ14;
UC-8 SJ13; UC-9 SJ16; UC-10 SJ17; UC-11 SJ12, SP8; UC-12 SJ12; UC-13 SJ18;
UC-14 SJ15; UC-15 SJ4; UC-16 SJ0, SJ1, SP3, SP4; UC-17 the size gate
(section 7.5); UC-18 SJ1, SJ2, SJ5, SJ10, SJ11, SJ16, SJ17.

**Which services a launch gets.** Snapshots and Model tests: `.fake`.
Journeys: `.live` everywhere, the store seeded by `-SuiteFixture <name>`
(section 4.1), so processes share it. No arguments (a person's launch):
`.live`, built by SuiteShell from its slot
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
    /// Yields a counter each time any app's run state changes (launch, quit, crash).
    func changes() async -> AsyncStream<Int>
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
    /// Yields the new revision after any process writes `recents.json`.
    func changes() async -> AsyncStream<Int>
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
    /// nil when Open In has targets; else why the submenu is disabled.
    func openInRefusal(for type: SuiteTypeID, from app: SuiteApp) -> SuiteError?
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
    /// Assets added from this document, so its app can offer Update Asset.
    func assets(fromFileID fileID: String) async throws(SuiteError) -> [SuiteAsset]
    func changes() async -> AsyncStream<Int>
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
    func changes() async -> AsyncStream<Int>
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
    /// `.updatePostponed(app)` when an app cancelled its quit; nothing is replaced.
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

/// UC-18 Act on a hand-off (every app, tier 1). Each `<X>Model` conforms
/// (adoption issue A-x-1); `.suiteApp(_:host:)` in SuiteShell hands every
/// received hand-off to it. SuiteShell never sees an app Model, only this.
public protocol SuiteDocumentHost: Sendable {
    /// nil when the app can act on it now; else the reason it refuses.
    func refusal(for handOff: HandOff) async -> SuiteError?
    /// Open, new, edit, place, import or return: the app does it and says how it ended.
    func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState
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
    /// True while any member is a fake; drives a "Preview data" pill in the home.
    public var isPreview: Bool

    public init(switching: any AppSwitching, recents: any RecentWork, creating: any DocumentCreating,
                routing: any DocumentRouting, sending: any HandOffSending, receiving: any HandOffReceiving,
                roundTrips: any RoundTripEditing, pasteboard: any PasteboardCoding, assets: any AssetLibrary,
                linking: any AssetLinking, animations: any AnimationSourceReading, preferences: any PreferencesStoring,
                settings: any SettingsRouting, onboarding: any OnboardingFlowing, updates: any UpdateChecking,
                thumbnails: any ThumbnailPublishing, home: any HomeBuilding, isPreview: Bool) {
        self.switching = switching; self.recents = recents; self.creating = creating; self.routing = routing
        self.sending = sending; self.receiving = receiving; self.roundTrips = roundTrips; self.pasteboard = pasteboard
        self.assets = assets; self.linking = linking; self.animations = animations; self.preferences = preferences
        self.settings = settings; self.onboarding = onboarding; self.updates = updates; self.thumbnails = thumbnails
        self.home = home; self.isPreview = isPreview
    }

    /// Members a process supplies itself: Halo's animation reader (it links FlareCore)
    /// and the launcher's updater (it owns the bundle). SuiteShell can see neither.
    public func with(animations: (any AnimationSourceReading)? = nil, updates: (any UpdateChecking)? = nil) -> SuiteServices {
        var s = self
        if let animations { s.animations = animations }
        if let updates { s.updates = updates }
        return s
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
                             thumbnails: FakeThumbnails(), home: FakeHome(), isPreview: true)
    }
}
```

### 5.4 Shared values (`Values.swift`)

<details><summary>Values.swift (identity, type registry, document refs, errors, recents, hand-offs, round trip, colours and assets, pasteboard, preferences, onboarding, updates, home)</summary>

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
    public static let fileURL = SuiteTypeID(rawValue: "public.file-url")
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
    case noOtherReader(typeName: String)
    case originalMissing(name: String)
    case linkMissing
    case updatePostponed(SuiteApp)

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
        case .noOtherReader(let t): "No other app opens \(t) files."
        case .originalMissing(let n): "The original of \(n) is missing. Locate it in Library first."
        case .linkMissing: "Linked asset is missing; using the last copy."
        case .updatePostponed(let a): "Update postponed: \(a.displayName) has unsaved changes."
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
/// Widths are whole multiples of 4 pt, so every origin sits on the 4 pt grid.
public enum HomeLayout {
    public static let sidebar = 200.0, margin = 24.0, gap = 16.0, cardMin = 168.0, cardMax = 240.0
    public static let tileMax = 240.0, tileChipsMin = 160.0

    static func content(_ windowWidth: Double) -> Double { max(windowWidth - sidebar - 2 * margin, cardMin) }
    static func four(_ v: Double) -> Double { (v / 4).rounded(.down) * 4 }

    public static func columns(windowWidth: Double) -> Int {
        max(1, Int((content(windowWidth) + gap) / (cardMin + gap)))
    }

    public static func cardWidth(windowWidth: Double) -> Double {
        let n = Double(columns(windowWidth: windowWidth))
        return min(cardMax, four((content(windowWidth) - gap * (n - 1)) / n))
    }

    /// Five tiles in one row.
    public static func tileWidth(windowWidth: Double) -> Double {
        min(tileMax, four((content(windowWidth) - 4 * gap) / 5))
    }

    /// Below this width a tile shows its presets as a menu, not chips.
    public static func tileShowsChips(windowWidth: Double) -> Bool { tileWidth(windowWidth: windowWidth) >= tileChipsMin }
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

/// Holds the continuations of `changes()` streams for an actor fake.
struct ChangeFeed {
    private var continuations: [AsyncStream<Int>.Continuation] = []
    mutating func stream() -> AsyncStream<Int> {
        let (s, c) = AsyncStream<Int>.makeStream()
        continuations.append(c)
        return s
    }
    func send(_ revision: Int) { for c in continuations { c.yield(revision) } }
}

public actor FakeSwitching: AppSwitching {
    public private(set) var states: [SuiteApp: AppRunState]
    public private(set) var ticks: UInt64 = 0
    var feed = ChangeFeed()
    let unavailable: String?
    public init(running: [SuiteApp] = [], missing: Set<SuiteApp> = [], unavailable: String? = nil) {
        var s: [SuiteApp: AppRunState] = [:]
        for app in SuiteApp.allCases { s[app] = missing.contains(app) ? .missing : running.contains(app) ? .running(windows: 1) : .notRunning }
        s[.launcher] = .running(windows: 1)
        states = s
        self.unavailable = unavailable
    }
    public func runState(of app: SuiteApp) -> AppRunState { states[app] ?? .notRunning }
    public func changes() -> AsyncStream<Int> { feed.stream() }
    public func switchTo(_ app: SuiteApp, reason: SwitchReason) throws(SuiteError) -> SwitchReceipt {
        if let unavailable { throw .notAvailable(unavailable) }
        let before = states[app] ?? .notRunning
        if before == .missing { throw .appMissing(app) }
        ticks += 1
        if case .running = before {} else { states[app] = .running(windows: 1); feed.send(Int(ticks)) }
        if case .running = before { return SwitchReceipt(app: app, wasRunning: true, requestedAt: ticks) }
        return SwitchReceipt(app: app, wasRunning: false, requestedAt: ticks)
    }
    /// Test hook: the app quit or crashed.
    public func terminate(_ app: SuiteApp) { states[app] = .notRunning; ticks += 1; feed.send(Int(ticks)) }
}

public actor FakeRecents: RecentWork {
    public private(set) var stored: RecentsList {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
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
    public func changes() -> AsyncStream<Int> { feed.stream() }
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

    public func openInRefusal(for type: SuiteTypeID, from app: SuiteApp) -> SuiteError? {
        openInTargets(for: type, from: app).isEmpty ? .noOtherReader(typeName: registry.type(type)?.name ?? "these") : nil
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
    let missingOriginals: Set<String>   // fileIDs whose original is gone
    public init(missingOriginals: Set<String> = [], unavailable: String? = nil) {
        self.missingOriginals = missingOriginals; self.unavailable = unavailable
    }

    public func begin(_ source: RoundTripSource, id: String, at date: Date) throws(SuiteError) -> RoundTripSession {
        if let unavailable { throw .notAvailable(unavailable) }
        if missingOriginals.contains(source.original.fileID) {
            let name = source.original.displayName.split(separator: ".").first.map(String.init) ?? source.original.displayName
            throw .originalMissing(name: name)
        }
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
        .flare: [.assetEnvelope, .flareLayers, .svg, .plainText, .fileURL],
        .design: [.assetEnvelope, .designLayers, .svg, .png, .plainText, .fileURL],
        .photo: [.assetEnvelope, .png, .jpeg, .heic, .plainText, .fileURL],
        .library: [.png, .jpeg, .heic, .fileURL],
        .halo: [.assetEnvelope, .plainText, .fileURL],
        .launcher: [.fileURL, .assetEnvelope, .svg, .png],
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
        case .files(let refs): return refs.map { TypedData(type: .fileURL, data: Data(("file://" + $0.path).utf8)) }
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
            case .fileURL:
                let routing = FakeRouting()
                let refs = offered.filter { $0.type == .fileURL }.compactMap { r -> SuiteDocumentRef? in
                    let path = String(String(decoding: r.data, as: UTF8.self).dropFirst("file://".count))
                    let name = path.split(separator: "/").last.map(String.init) ?? path
                    guard let target = try? routing.route(fileName: name),
                          let type = routing.registry.type(forExtension: name.split(separator: ".").last.map(String.init) ?? "")
                    else { return nil }
                    return SuiteDocumentRef(path: path, fileID: path, app: target, type: type.id, displayName: name)
                }
                if refs.isEmpty { continue }
                return .files(refs)
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
    public private(set) var stored: AssetIndex {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
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
    public func assets(fromFileID fileID: String) throws(SuiteError) -> [SuiteAsset] {
        if let unavailable { throw .notAvailable(unavailable) }
        return stored.assets.filter { $0.source?.fileID == fileID }
    }
    public func changes() -> AsyncStream<Int> { feed.stream() }
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
    public private(set) var stored: SuitePreferences {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
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
    public func changes() -> AsyncStream<Int> { feed.stream() }
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
    let refusesQuit: SuiteApp?          // an app whose unsaved-changes prompt is cancelled
    public init(feed: Data = Data("[]".utf8), validSignatures: Set<String> = [], refusesQuit: SuiteApp? = nil,
                unavailable: String? = nil) {
        self.feed = feed; self.validSignatures = validSignatures; self.refusesQuit = refusesQuit; self.unavailable = unavailable
    }
    public func check(current: SuiteVersion) throws(SuiteError) -> UpdateOffer? {
        if let unavailable { throw .notAvailable(unavailable) }
        return try UpdateFeed.newest(in: feed, above: current)
    }
    public func download(_ offer: UpdateOffer) throws(SuiteError) -> String {
        guard validSignatures.contains(offer.signature) else { throw .updateNotVerified }
        return "/tmp/AfterGlow-\(offer.version.major).\(offer.version.minor).\(offer.version.patch).zip"
    }
    public func install(zipAt path: String) throws(SuiteError) {
        if let app = refusesQuit { throw .updatePostponed(app) }
        installed.append(path)
    }
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

/// A host that records what it was asked to do; refuses the verbs it doesn't take.
public actor FakeDocumentHost: SuiteDocumentHost {
    public let app: SuiteApp
    public let verbs: Set<HandOffVerb>
    public private(set) var accepted: [HandOff] = []
    public init(app: SuiteApp, verbs: Set<HandOffVerb>) { self.app = app; self.verbs = verbs }
    public func refusal(for handOff: HandOff) -> SuiteError? {
        verbs.contains(handOff.verb) ? nil : .notAvailable("\(app.displayName) can't do that yet.")
    }
    public func accept(_ handOff: HandOff) throws(SuiteError) -> HandOffState {
        if let r = refusal(for: handOff) { throw r }
        accepted.append(handOff)
        return handOff.verb == .edit ? .accepted : .returned
    }
}

/// The journeys' fixtures as store files (section 4.1). The launcher writes them
/// into `-SuiteSupportDir` with `FileStore`, then every process runs on `.live`,
/// so what one app writes the others read. Document files come from
/// `UITests/Fixtures/suite/` (each app line's fixture export, A-x-0).
public enum SuiteFixtures {
    public static let names = ["empty", "weekOfWork", "missing", "roundTrip", "assets", "crowd"]

    public struct Store: Equatable, Sendable {
        public var recents: RecentsList
        public var assets: AssetIndex
        public var preferences: SuitePreferences
    }

    public static let weekOfWorkFiles: [(String, SuiteApp, SuiteTypeID)] = [
        ("Logo.design", .design, .designDocument), ("Cards.design", .design, .designDocument),
        ("Bounce.flare", .flare, .flareAnimation), ("Intro.halo", .halo, .haloProject),
        ("beach.ora", .photo, .photoOpenRaster), ("Title.flare", .flare, .flareAnimation),
        ("Sunset.png", .photo, .png), ("Logo animated.flare", .flare, .flareAnimation),
    ]

    /// nil for an unknown name. `documents` is the folder holding the fixture documents.
    public static func store(_ name: String, documents: String, now: Date) -> Store? {
        func ref(_ f: (String, SuiteApp, SuiteTypeID)) -> SuiteDocumentRef {
            SuiteDocumentRef(path: documents + "/" + f.0, fileID: f.0, app: f.1, type: f.2, displayName: f.0)
        }
        let done = SuitePreferences(onboardingDoneVersion: 1)
        switch name {
        case "empty", "roundTrip":
            return Store(recents: RecentsList(), assets: AssetIndex(), preferences: done)
        case "weekOfWork", "missing":
            let items = weekOfWorkFiles.enumerated().map { i, f in
                RecentItem(ref: ref(f), lastUsed: now - Double(i) * 75_600, thumbnail: "thumbnails/\(f.0).png")
            }
            return Store(recents: RecentsList(revision: 1, items: items), assets: AssetIndex(), preferences: done)
        case "assets":
            let colors = [("Brand blue", SuiteColorSpace.sRGB, 0.094, 0.467, 0.949), ("Ink", .sRGB, 0.1, 0.1, 0.12),
                          ("Paper", .sRGB, 0.98, 0.97, 0.94), ("Coral", .sRGB, 1, 0.42, 0.36),
                          ("Vivid green", .displayP3, 0.2, 0.9, 0.3), ("Vivid red", .displayP3, 1, 0.1, 0.1)]
            var assets = colors.enumerated().map { i, c in
                SuiteAsset(id: "c\(i)", kind: .color, name: c.0, color: SuiteColorValue(space: c.1, red: c.2, green: c.3, blue: c.4),
                           modifiedAt: now - Double(i))
            }
            assets.append(SuiteAsset(id: "v0", kind: .vector, name: "Card", payload: "assets/v0/1.svg", modifiedAt: now - 10))
            assets.append(SuiteAsset(id: "v1", kind: .vector, name: "Badge", payload: "assets/v1/1.svg", modifiedAt: now - 11))
            assets.append(SuiteAsset(id: "i0", kind: .image, name: "Sunset", payload: "assets/i0/1.png", modifiedAt: now - 12))
            assets.append(SuiteAsset(id: "a0", kind: .animation, name: "Bounce", payload: "assets/a0/1.flare", modifiedAt: now - 13))
            return Store(recents: RecentsList(), assets: AssetIndex(revision: 1, assets: assets), preferences: done)
        case "crowd":
            let items = (0..<200).map { i in
                RecentItem(ref: SuiteDocumentRef(path: documents + "/Doc \(i).flare", fileID: "crowd\(i)", app: .flare,
                                                 type: .flareAnimation, displayName: "Doc \(i).flare"), lastUsed: now - Double(i))
            }
            return Store(recents: RecentsList(revision: 1, items: items), assets: AssetIndex(), preferences: done)
        default:
            return nil
        }
    }
}
```

</details>

### 5.6 Size report and budget (`Packaging.swift`, owned by the bundle feature)

<details><summary>Packaging.swift</summary>

```swift
// Packaging.swift: the size report and its budget (SuiteModel, planned
// `Sources/SuiteModel/Packaging/`, owned by the bundle feature). Not a
// runtime service, so not in SuiteServices: `scripts/size-report` writes a
// SizeReport and `SizeGateTests` evaluates it against the committed budget.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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

/// UC-17 Size budget (tier 3, gates packaging). Pure; `scripts/size-report` feeds it.
public protocol SizeBudgetChecking: Sendable {
    func evaluate(_ report: SizeReport, against budget: SizeBudget) -> [SizeFinding]
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

### 5.7 The view-model shape (`HomeModel.swift`)

Views in `Sources/AfterGlowApp/` stay dumb (the app-state rule): each screen
reads an `@Observable` model in SuiteModel whose state is
`public private(set)` and calls its methods. `HomeModel` is the worked
example; `AssetsModel`, `SettingsModel`, `OnboardingModel` and
`UpdateModel` follow it in their features.

```swift
// HomeModel.swift: the home window's view-model (SuiteModel, planned
// `Sources/SuiteModel/Home/HomeModel.swift`, owned by the home feature).
// The views in `Sources/AfterGlowApp/Home*.swift` read it and call its
// methods; they never assign its state (the app-state rule). The Assets
// page, Settings, onboarding and the update sheet get the same shape:
// `AssetsModel`, `SettingsModel`, `OnboardingModel`, `UpdateModel`, each in
// its feature's SuiteModel folder.
import Observation
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@MainActor @Observable
public final class HomeModel {
    public private(set) var state = HomeState(tiles: [], cards: [], running: [], emptyMessage: nil)
    public private(set) var query = ""
    public private(set) var filter: SuiteApp?
    public private(set) var selection: String?          // a fileID
    public private(set) var message: SuiteError?        // shown in place, never an alert
    let services: SuiteServices
    var recents = RecentsList()
    var running: [SuiteApp] = []
    var order = SuiteApp.apps
    var missingApps: Set<SuiteApp> = []
    var missingFiles: Set<String> = []

    public init(services: SuiteServices) { self.services = services }

    public func reload(now: Date) async {
        do { recents = try await services.recents.list() } catch { message = error }
        var r: [SuiteApp] = []
        var missing: Set<SuiteApp> = []
        for app in SuiteApp.apps {
            switch await services.switching.runState(of: app) {
            case .running: r.append(app)
            case .missing: missing.insert(app)
            default: break
            }
        }
        running = r
        missingApps = missing
        rebuild(now: now)
    }

    public func search(_ text: String, now: Date) { query = text; rebuild(now: now) }
    public func filter(_ app: SuiteApp?, now: Date) { filter = app; rebuild(now: now) }
    public func select(_ fileID: String?) { selection = fileID; message = nil }
    public func markMissing(_ fileID: String, now: Date) {
        missingFiles.insert(fileID)
        message = .fileMissing(name: recents.items.first { $0.ref.fileID == fileID }?.ref.displayName ?? fileID)
        rebuild(now: now)
    }

    /// Open the selected card in its app (UC-5).
    public func openSelection(now: Date) async {
        guard let id = selection, let item = recents.items.first(where: { $0.ref.fileID == id }) else { return }
        if missingFiles.contains(id) { message = .fileMissing(name: item.ref.displayName); return }
        let h = HandOff(id: "open-\(id)", from: .launcher, to: item.ref.app, verb: .open, documents: [item.ref], createdAt: now)
        do { _ = try await services.sending.send(h) } catch { message = error }
    }

    public func removeSelection(now: Date) async {
        guard let id = selection else { return }
        do { try await services.recents.remove(fileID: id); recents.remove(fileID: id); selection = nil } catch { message = error }
        rebuild(now: now)
    }

    func rebuild(now: Date) {
        state = services.home.home(recents: recents, running: running, query: query, filter: filter, order: order,
                                   missingApps: missingApps, missingFiles: missingFiles, now: now)
    }
}
```

### 5.8 Hand-off flows, step by step

**New document from the home (UC-3, UC-5).** The home asks
`creating.handOff(for: preset, …)`, `sending.send` writes
`handoffs/<id>.aghandoff` and opens it with the app; the app's
`SuiteAppDelegate` receives it (`application(_:open:)`), `receiving.receive`
decodes and marks it accepted, the app's `SuiteDocumentHost.accept` runs its
own New with the preset's parameters, then `settle(id:as:)` with what
`accept` returned.

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
`.missing` keeps the last copy and says `SuiteError.linkMissing`.

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
| Settings | `Settings` scene, `TabView` with General and one tab per app, width `SuiteSize.settingsWidth` (**new** token, 560 pt) | Each tab is a `Form` | `Picker` (units; autosave 10 s, 30 s, 1 min, 5 min), `Toggle` (check for updates), `Button` (Check Now, Show Welcome Again); per-app tabs: the app's default New preset (`Picker`) and "At launch: reopen last documents / start empty" (`Picker(.radioGroup)`) |
| Onboarding | `Window` sized by `SuiteSize.onboardingWindow` (**new** token, 720 × 520), opened once | Three pages | system `VStack` with `SuiteFont`; page 1: the five app symbols and names; page 2: `ChoiceChips` (Animation, Design, Photos, Motion, Everything); page 3: three sample `Button`s; Continue (prominent), Skip |
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
- **In each app, added by `SuiteCommands`**: Window > Switch To ▸ (the same six; the current app's item reads "Show Flare Window", enabled when the app has no window, else disabled "You're in Flare."); File > Open In ▸ (the readers of the front document, else disabled with `openInRefusal`'s text); <App> > Settings… ⌘, (opens AfterGlow Settings at that app's tab). Each app's own adoption issues add: Library Photo > Edit in Photo (⌘E); Design Object > Add to Assets and Object > Update Asset (enabled when `assets(fromFileID:)` lists one for the front document); Flare and Halo Object > Update Linked Asset; every app with a colour row Edit > Copy Color and Edit > Paste Color; Photo File > New from Clipboard (PV-2). Each app's menu journey (Flare's J1 counts items) is updated by its A-x-1.

Control-Command with a digit is not one of the standard shortcuts design.md
reserves; SW-3's `SuiteCommandsTests` checks that no app's menus already
bind ⌃⌘0–⌃⌘5, and each shortcut is bound once.

### 6.3 What SuiteUI needs to add (filed by the home and shared-assets features as `needs-ui`)

| Component | For | Spec |
|---|---|---|
| `AppTile` | home New row | A `Button` whose label is the app symbol (32 pt), title in `SuiteFont.body` semibold, and an optional `ChoiceChips` under it; flat `panel` fill, radius `SuiteRadius.card`; disabled at 40% with `.help(reason)`; a `ProgressView` ring replaces the symbol while launching. Goldens in four appearances (QB-V5) |
| `ThumbnailBadges` app symbol + missing | recents grid | Extends the existing `ThumbnailBadges`: a leading app symbol badge and a trailing `stateWarning` triangle with "Missing". Library's S-L2 (`ThumbnailGrid` hooks) is the same file: one issue, filed against Library's |
| `SidebarRow` trailing accessory | running dot | A 6 pt dot in `textSecondary` (running) next to the title; the dot has an accessibility value "Running" |
| `SwatchChip` | Assets page, colour popovers | 24 pt rounded swatch (radius `SuiteRadius.row`) with the hex under it in `SuiteFont.caption` tabular; a "P3" caption badge for Display P3 colours; selected = `stateSelected` outline |
| `SuiteSize.settingsWidth`, `SuiteSize.onboardingWindow` | Settings and onboarding windows | The design lint bans literal sizes in apps; two tokens in `Tokens.swift` |
| `LayerList` accessory | link mark on layer rows | The planned `LayerList` (#765) gains a trailing accessory slot; the suite puts the `link` symbol there, or the `stateWarning` triangle when an update is available |

None of these is in #765's plan; each is a `needs-ui` issue filed by the
feature that first needs it (home: `AppTile`, `ThumbnailBadges`, `SidebarRow`
accessory; settings and onboarding: the two size tokens; shared-assets:
`SwatchChip`, which draws a `SuiteColorValue` in its own space, since the
design lint bans `Color(.sRGB …)` in app code; linked-assets: `LayerList`
accessory). The waits column of 8.3 lists them. Until it merges, the feature uses a plain SwiftUI placeholder
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
mark from the process that drew the result. Both use the system uptime
clock (`ProcessInfo.systemUptime`, the domain of `NSEvent.timestamp`), so an
input event's own timestamp and the target's frame mark compare directly; frames late are counted against the target process's
display refreshes, as the rubric counts them.

| id | Interaction | Device target | CI gate | Test |
|---|---|---|---|---|
| QB-S1 | Switch to a running app (⌃⌘<n>, home row, Switch To menu): key event → first frame of the target's key window drawn frontmost | p95 ≤ 6 refreshes (100 ms at 60 Hz) | report-only, then set from CI | SP1, 30 switches, at least 30 samples or the test fails as invalid |
| QB-S2 | First open of an app per session (cold launch from the home): click → first frame of its window | ≤ 700 ms median, ≤ 1 s p95 | report-only, then set from CI | SP2, each app 20 times, terminating it between runs |
| QB-S3 | AfterGlow cold launch → home first frame; first frame → recents shown (200 recents) | ≤ 500 ms; ≤ 100 ms | report-only | SP3 |
| QB-S4 | Type in recents search → filtered grid drawn | p95 ≤ 2 frames late | placeholder 3 | SP4, 20 keystrokes |
| QB-S5 | Paste across apps → pasted item drawn (50 shapes from Design into Flare; a 24 MP image into Photo) | ≤ 100 ms; ≤ 300 ms, with progress shown by 100 ms (QB-L9) | report-only | SP5 |
| QB-S6 | Routed open (Finder or Open In) → document window's first frame; target running / cold | ≤ 300 ms / ≤ 1 s | report-only | SP6 |
| QB-S7 | Edit in Photo → Photo shows the image (24 MP, Photo running); Photo Save → Library's thumbnail updated | ≤ 1 s; ≤ 1 s | report-only | SP7 |
| QB-S8 | A setting changed → applied in every running app | ≤ 500 ms | report-only | SP8 |
| QB-S9 | Drag a card or file onto another app: the drop target highlights (the drag image itself is drawn by the system, which no app probe sees) | highlight ≤ 1 frame after the drag enters, by the target's probe | report-only | SJ14 with the probe |
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
| QB-SM6 | `FileStore` under the lock: two separate processes (the test binary re-launched twice with `Process`) each note 500 recents into one temp store | no entry lost (1,000 present), each write ≤ 5 ms median | ≤ 50 ms |

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

Card and tile widths are rounded down to a multiple of 4 pt, so every
origin sits on the 4 pt grid. A tile under 160 pt shows its presets as a
menu instead of chips (`HomeLayout.tileShowsChips`).

| Window width | Content | Grid columns | Card width | Tile width | Tile presets |
|---|---|---|---|---|---|
| 880 (minimum) | 632 | 3 | 200 | 112 | menu |
| 1000 (launch) | 752 | 4 | 176 | 136 | menu |
| 1280 | 1032 | 5 | 192 | 192 | chips (at most 3) |
| 1728 | 1480 | 8 | 168 | 240 | chips (at most 3) |

Checked, at each of the four widths:

1. **Linux**, `HomeLayoutTests`: the table above, exactly; for every width
   from 880 to 2560 in 1 pt steps, columns ≥ 1, card width within 168–240
   and a multiple of 4, and the row fits the content (main.swift runs this
   sweep today).
2. **macOS CI**, `AfterGlowHomeLayoutTests` (AppSnapshotTests): the home on
   the `weekOfWork` fixture rendered at the four widths; frames read through
   anchor preferences. The tile row, the RECENT header and the grid share
   one left edge (±0.5 pt); no card or tile crosses the content's right
   edge; no two cards overlap; card origins sit on the 4 pt grid; the
   sidebar is 200 pt. The same check for Settings (fixed 560 pt wide: every
   `Form` row's leading labels align, ±0.5 pt) and onboarding (720 × 520:
   Continue and Skip inside the window with 24 pt margins).
3. **macOS CI**, journey `testHomeAtEveryWidth` (`+Layout`, home): resizes
   the window to 880 and 1000, the widths that fit the 1024 × 768 runner
   (app-audit.md, #263), and shoots each; the audit's `offscreen` and
   `overlap` stay at 0. 1280 and 1728 are covered by the snapshot test in 2,
   which has no display limit, and locally by `scripts/ui-test` on a larger
   display.

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

`scripts/size-report` (BU-0, extended to `AfterGlow.app` by BU-4) measures, on every macOS CI run on `dev`:
bytes of each app executable, each framework, each embedded app bundle, the
launcher, the whole `AfterGlow.app` and the tarball; and the SuiteUI symbols
defined in each app executable (`nm -U`, demangled, module `SuiteUI`, with
generic specializations and inlined copies excluded: those legitimately
land in the client). `SizeBudget.evaluate` decides.

| Entry | Budget (provisional) | Gate |
|---|---|---|
| Each app executable (`Contents/Helpers/<X>.app/Contents/MacOS/<X>`) | its own code and Model only; at most 60% of today's size for that app (today 2.9 to 5.8 MB) | report-only for the first ten runs, then the measured maximum × 1.10, never above the provisional number |
| `SuiteUI.framework` | ≤ 4 MB | as above |
| `CreativeEngines.framework` | ≤ 6 MB | as above |
| `SuiteModel.framework` + `SuiteShell.framework` | ≤ 2 MB together | as above |
| Launcher executable | ≤ 2 MB | as above |
| Whole `AfterGlow.app` (uncompressed) | ≤ the sum of today's five executables + 10% (BU-0 records the sum) | as above |
| `app-builds.tar.gz` | ≤ 15 MB | as above |
| SuiteUI symbols defined in any app executable (as counted above) | 0 | report-only for one run after BU-4 (to check the counting rule against a real build), then hard |

Detailed size work (dead-code stripping, asset compression, per-framework
trimming) is a later phase; this gate only stops growth and proves the
split worked.

### 7.6 Reliability

| Check | Measured by |
|---|---|
| No work lost when switching: SJ3's state after two switches equals the state before | SJ3 asserts the frame, selection and zoom values |
| A crash in one app leaves the others running with their documents | journey `testCrashIsolation` (`+Switch`): `SIGKILL` Flare's process (local only if the runner may not signal it); Design's window, document and dirty dot unchanged; the home drops Flare from the running rows within 1 s |
| Two processes writing the store at once lose nothing | QB-SM6 (Linux, two real processes under the lock file) |
| An expired or newer-format hand-off never acts | Linux `HandOffCodecTests` (main.swift's checks, moved) |
| Quit from the updater runs each app's unsaved-changes flow; a Cancel stops the update | journey `testUpdateWaitsForUnsavedWork` (`+Update`): a dirty Design document, Install → Design's save prompt → Cancel → the update stops with "Update postponed: Design has unsaved changes." |

---

## 8. Coverage and waves

### 8.1 Coverage: every related open issue

From all 169 open issues (read 2026-10-14). An issue maps to the suite
feature that consumes or closes it, or to "not v1" or "app line" (its own
line keeps it; the suite only depends on it). No open issue is closed by a
suite feature: none exists for the suite's own work, so each feature files
its tasks as new issues on `line:suite` when its packet is written.

| Issue | What | Suite feature | How |
|---|---|---|---|
| #754 | Flare never-lose-work (feature-lead) | app line; recovery policy | Its recovery file is the suite rule (1.4); other apps adopt on their lines |
| #393, #392 | Flare recovery offer; open errors | app line | Same policy; no suite code |
| #205 | Flare save to `.flare` | recents-open-in (depends) | Flare's saves feed the shared recents (adoption A-FL-2) |
| #209 | Halo save and open | recents-open-in (depends) | Halo's `HaloRecentFile` list becomes the shared list (A-HA-2) |
| #15 | Flare: open a sample or `.flare` file, Undo and Redo in the Edit menu | switching (depends) | `SuiteCommands` adds Switch To beside these menus (A-FL-1) |
| #398, #399 | Flare IN-4 files; IN-9 no-argument live launch | switching (depends) | The launcher starts Flare with no arguments; until #399 Flare opens on its fakes |
| #346, #347 | Flare onto `EditorShell`; `FlareIntent`, `suite.controls` | switching (depends) | `.suiteApp(.flare)` sits on the scene #346 builds; `suite.controls` is the sweep format SJ0 reuses |
| #384 | Flare F18 pasteboard | clipboard-drag (depends) | Flare's private type plus the suite representations (A-FL-3) |
| #415 | Design copy and paste, also between files | clipboard-drag (depends) | Design's `org.creativesuite.design.layers` stays; the suite envelope and SVG are added (A-DE-3) |
| #414 | Design duplicate, Option-drag | app line | none |
| #275, closed #133 | Design undo routing; menus with no window | switching | `SuiteCommands` must work with no window (switching acceptance); #275 stays Design's |
| #274 | Shared open and save panels (p3) | not v1 | SuiteUI and Photo Q6 hold it; recents-open-in records through `SuiteDocumentsBridge`, not panels |
| #212 | Library catalog persists | photo-round-trip (depends) | The returned copy must survive relaunch |
| #210 | Library import a folder | photo-round-trip, recents-open-in (depends) | Import is how a returned copy and an Open In ▸ Library land |
| #424 | Library export JPEG | app line | none (round trip writes through Photo) |
| #427 | Library camera raw | not v1 | — |
| #418 | Design export PNG, SVG, PDF | linked-assets, clipboard-drag (depends) | Design's SVG writer is the vector representation and the asset payload |
| #429 | Halo render to movie or PNG sequence | app line | none |
| #374, #354, #355, #366, #367 | Flare export | flare-in-halo (depends, for QB-SV4's reference) | Flare's PNG export is the golden reference |
| #20, #21 | Design variables; wide-gamut colour | shared-assets (beside) | Suite colours keep their space (QB-SV2); Design variables can link to a suite colour later (not v1) |
| #380, #387, #363, #349 | Flare swatches and instances | shared-assets (beside) | Flare's FILL popover gains a SUITE COLOURS section (A-FL-5); document swatches stay |
| #14 | Flare symbols panel | not v1 for the suite | — |
| #7 | Command palette | not v1 | SuiteUI agrees |
| #342, #339, #340, #341 | SuiteUI timeline slot, top bar, save status, status bar, tabs | app line (SuiteUI) | none |
| #273 | Selection handles into SuiteUI | not suite | — |
| #73, #108, #111, #577, #589 | SuiteUI sidebar context menus, rename, disclosure, refusal, VoiceOver | home (depends) | The home's sidebar uses `SidebarRow`; these fixes benefit it, none blocks it |
| #330 | FrameProbe (p3) | every suite perf row (depends) | p1 by dependency for switching (QB-S1) per priorities.md's rule |
| #331, #332, #333 | Goldens, snapshot host, journey helpers | home, switching (depend) | QB-SV7 goldens; #333's per-file journey template for `AfterGlowJourneyTests+*.swift` |
| #287–#291 | Each app's missing identifiers | app lines | none |
| #283, #284, #285, #622, #591 | SuiteUI contrast, hit targets, scrub steps | not suite | — |
| #62, #63 | Timeline keyframe access | not suite | — |
| #724 | Library loupe zoom shortcuts | not suite | The suite reserves only ⌃⌘0–⌃⌘5 (6.2) |
| #186, #185 | Density passes | not suite | — |
| #351 | Flare F11b: New Animation sheet | switching (depends) | SJ2's preset lands in this sheet's values |
| #208 | Halo undo and redo | linked-assets (depends) | Update Linked Asset in Halo is one undo step |
| #780 | `InlineNotice` (SuiteUI, from Library's S-L4) | home (uses) | The missing-file message in place |
| #782 | FrameProbe named marks | every suite perf row (depends) | `recents-ready`, `tile-progress`, `switch-cold` and the rest are named marks |
| #12, #33, #423 | Flare stage drawing; Library thumbnails; Library develop to pixels | recents-open-in, photo-round-trip (depend) | Thumbnails (QB-SV1) need each app to draw; SJ10 asserts Library's thumbnail changes |
| #773, #777 | Halo foundation contracts | flare-in-halo, linked-assets (depend) | Halo's `SuiteDocumentHost` conformance sits on its services |
| #763 | dev is red | blocker | Blocks every merge, as priorities.md rule 4 treats creative-core #211 |

### 8.2 Features

Each feature is one feature-lead session (`docs/factory/lead.md`). Tasks
are listed so the packets can be cut from them; each is one PR under 400
lines and 15 files. "Supervisor merges" marks tasks that touch a protected
path (`Package.swift`, `scripts/`, `.github/`), which the fast lane refuses.

**Adoption issues.** Work inside an app's targets is never a suite task
(CLAUDE.md: a line never edits another line's targets; lead.md: such work
becomes an issue). Each `A-x-n` below is filed by the suite feature as a
`needs-suite` issue on that app's line, naming its exact files (8.4), and is
built by that line. Within one app the issues of one wave are sequenced
(A-x-2, then A-x-3, then A-x-4), so two never edit the same app file at
once. A suite feature's journeys that need an app's half wait on that issue;
its own Model and SuiteShell tasks don't.

**F0 `targets`** (wave 0) · tier 1 by dependency · waits on nothing (but #763 is a blocker for every merge)

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| BU-0 | Measure today: `scripts/size-report` and a `macos` step that uploads `size-report` for the five current bundles (**supervisor merges**) | `scripts/size-report`, `.github/workflows/ci.yml` | the artifact on the next dev run; the numbers recorded in the PR body (QB section 7.5 baselines) |
| BU-S | Spike, run locally on a Mac (`scripts/ui-test`), no protected path: time shape B (cold launch, activation, memory of today's bundles) against shape A's equivalent (section 2.5); confirm `application(_:open:)` receives a file with no window open; confirm a cross-app XCUITest drag works on the runner | `docs/blueprints/suite/spike.md` | the numbers; decides Q12 |
| BU-1 | New targets with placeholders (**supervisor merges**): `SuiteModel`, `SuiteModelTests`, `SuiteShell`, `AfterGlowApp` (its `@main` with the home `Window`, `Settings`, onboarding window and update sheet, each pointing at a placeholder view in its own file, and one `Commands` stub per launcher menu feature); the C4 containers from `c4-planned.json`. Every placeholder sits on a path a component owns, so the C4 check passes | `Package.swift`, `docs/c4/model.json`, `Sources/SuiteModel/Values/SuiteIdentity.swift`, `Sources/SuiteShell/SuiteCommands.swift` (stub; SW-3 owns it from wave 2), `Sources/AfterGlowApp/AfterGlowApp.swift`, `HomeWindow.swift`, `AssetsPage.swift`, `SettingsView.swift`, `OnboardingWindow.swift`, `UpdateSheet.swift`, `LauncherCommands+Home.swift`, `LauncherCommands+Settings.swift`, `LauncherCommands+Assets.swift`, `LauncherCommands+Update.swift` (all under `Sources/AfterGlowApp/`), `Tests/SuiteModelTests/SuiteModelTests.swift` | `scripts/ci` PASS on Linux; the macOS job builds the four targets |

**F1 `bundle`** (wave 1) · tier 1 · waits on F0

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| BU-2 | `BundleLayout`, `SizeReport`, `SizeBudget`, `SizeGateTests` | `Sources/SuiteModel/Packaging/`, `Tests/SuiteModelTests/Packaging/` | Linux tests (main.swift's size checks, moved) |
| BU-3 | Release graph in `project.yml` (route R1: four frameworks, five apps, the launcher) and the `AfterGlowJourneyTests` bundle; `CreativeEngines.swift`; `BuildGraphTests` (Package.swift vs project.yml) | `project.yml`, `Bundle/Engines/CreativeEngines.swift`, `Tests/SuiteModelTests/BuildGraphTests.swift` | Linux `BuildGraphTests`; macOS dev run builds the graph; `otool -L` of each app lists the four frameworks |
| BU-4 | `scripts/bundle-apps` assembles `AfterGlow.app` (helpers, frameworks, inside-out signing, symlinks for the old `<X>App.app` paths) (**supervisor merges**) | `scripts/bundle-apps` | `codesign --verify --deep --strict` passes; every existing journey still green; SuiteUI symbols per app 0 in `size-report` |
| BU-5 | Info.plists and document types: `Bundle/Info/{AfterGlow,Flare,Design,Photo,Library,Halo}.plist` (types of 2.6), placeholder icons | `Bundle/Info/`, `Bundle/Icons/` | `plutil -lint`; `PlistShapeTests` (Linux, reads the XML) |
| BU-6 | Turn the size gate on in CI after ten runs; record BU-0 vs after (**supervisor merges**) | `.github/workflows/ci.yml`, `Tests/SuiteModelTests/Fixtures/size-budget.json` | an over-budget fixture report fails `SizeGateTests` |

Engine: none on route R1. If BU-3 cannot link the engines once, **needs a
new core issue**: "creative-core: declare `CreativeEngines` as a `.dynamic`
library product over FlareCore, CoreRaster and CoreColor; acceptance: an
executable depending on it links `libCreativeEngines` dynamically
(`otool -L`)."

**F2 `suite-contracts`** (wave 1) · tier 1 · waits on F0

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| SC-1 | Values and the type registry, plus the pure helpers in their later folders (`Recents/RecentsList.swift`, `Home/HomeLayout.swift`, `Update/UpdateFeed.swift`, `HandOff/HandOffCodec.swift`; each owned by its feature from that feature's wave) | `Sources/SuiteModel/Values/` (except `SuiteIdentity.swift`'s placeholder, which it fills), those four files, `Tests/SuiteModelTests/ValuesTests.swift` | recents, version, colour, hand-off codec checks from main.swift |
| SC-2 | The 18 contracts of `Contracts.swift`, one file each | `Sources/SuiteModel/Contracts/` | compiles; `ContractShapeTests` |
| SC-3 | Fakes and `SuiteFixtures` (all five fixtures of 4.1, so later features never edit them) | `Sources/SuiteModel/Fakes/`, `Tests/SuiteModelTests/FakesTests.swift` | each fake's behavior test |
| SC-4 | `SuiteServices` and `FileStore` (revisioned atomic JSON under a lock file, merge) | `Sources/SuiteModel/SuiteServices.swift`, `Sources/SuiteModel/Store/`, `Tests/SuiteModelTests/StoreTests.swift`, `Tests/SuiteModelTests/Budget+Store.swift` | QB-SM6 (two processes), QB-SV8 |
| SC-5 | `SuiteServices.live` and one slot file per member, each the fake with "Not connected yet (<feature>)." | `Sources/SuiteShell/SuiteServices+Live.swift`, `Sources/SuiteShell/Live/` (14 slot files: every member but `animations` and `updates`, which HaloApp and AfterGlowApp supply through `with(animations:updates:)`; one `HandOffSlot` for sending and receiving) | macOS build; the "Preview data" pill logic tested on Linux |

Engine: none.

**F3 `home`** (wave 2) · tier 1 · waits on F2

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| HM-0 | `Journey+Suite.swift`: `Journey(bundlePath:bundleID:auditKey:)`, `attach(_:)`, per-process audit keys (4.1) | `UITests/Journey+Suite.swift` | the first AfterGlow journey runs |
| HM-1 | `HomeBuilder` (live `HomeBuilding`), `HomeLayout`, `HomeModel`, locale ages | `Sources/SuiteModel/Home/`, `Tests/SuiteModelTests/Home*.swift`, `Tests/SuiteModelTests/Budget+Home.swift`, `Sources/SuiteShell/Live/HomeSlot.swift`, `Sources/SuiteShell/Live/CreatingSlot.swift` | QB-SM2; `HomeLayoutTests` |
| HM-2 | Home window: sidebar, New row, recents grid, search, filter, inspector, empty state; the launcher's File and View menus | `Sources/AfterGlowApp/Home*.swift` (includes `HomeWindow.swift`), `Sources/AfterGlowApp/LauncherCommands+Home.swift` | snapshots `afterglow-home-*` (QB-SV7) |
| HM-3 | Journeys SJ0, SJ1 (steps 1, 2, 5, 6), `testHomeAtEveryWidth`, SJ19, SP3, SP4; the `afterglow` audit key at 0 | `UITests/AfterGlowJourneyTests.swift`, `UITests/AfterGlowJourneyTests+Home.swift`, `+Layout.swift`, `+EveryControl.swift`, `+PerfHome.swift`, `UITests/SuiteBudgets+Home.swift`, `UITests/audit-baseline.json`, `Tests/AppSnapshotTests/AfterGlowHome*.swift` | the journeys; layout spec 7.3; QB-S3, QB-S4 |
| HM-4 | `needs-ui` issues for `AppTile`, `ThumbnailBadges`, `SidebarRow` accessory; the "AfterGlow" section of `docs/design.md` (6.4) | `docs/design.md` | review |

Engine: none.

**F4 `switching`** (wave 2) · tier 1 · waits on F2

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| SW-1 | Switch requests, run states, Switch To menu model | `Sources/SuiteModel/Switching/`, `Tests/SuiteModelTests/Switch*.swift` | `SwitchRunStateTests` |
| SW-2 | Hand-off lifecycle in the store (expiry, settle) | `Sources/SuiteModel/HandOff/`, `Tests/SuiteModelTests/HandOff*.swift`, `Tests/SuiteModelTests/Budget+HandOff.swift` | `HandOffCodecTests`, QB-SM4 |
| SW-3 | `AppLauncher`, `HandOffTransport`, `StoreWatcher`, `SuiteCommands`, `.suiteApp(_:host:)`, `SuiteAppDelegate`, the launcher's `LauncherRouter` (argument forwarding of 2.6); stubs of `SettingsRoute.swift` and `OpenInMenu.swift` | `Sources/SuiteShell/AppLauncher.swift`, `HandOffTransport.swift`, `StoreWatcher.swift`, `SuiteCommands.swift`, `SuiteAppModifier.swift`, `SuiteAppDelegate.swift`, `SettingsRoute.swift` and `OpenInMenu.swift` (stubs; settings and recents-open-in own them from wave 3), `Sources/SuiteShell/Live/SwitchingSlot.swift`, `Live/HandOffSlot.swift`, `Sources/AfterGlowApp/LauncherRouter.swift` | macOS build; `SuiteCommandsTests` (no ⌃⌘ digit clash, each bound once) |
| SW-4 | Journeys SJ2, SJ3, `testOpenRecentBringsAppForward`, `testCrashIsolation`, SP1, SP2; every QB-S and QB-SM row into `docs/review-rubric.md` at once, report-only (later gates are one-line constant changes in each feature's `SuiteBudgets+<Area>.swift`) | `UITests/AfterGlowJourneyTests+Switch.swift`, `+New.swift`, `+PerfSwitch.swift`, `UITests/SuiteBudgets+Switch.swift`, `docs/review-rubric.md` | the journeys; QB-S1, QB-S2 report-only |
| A-x-0 ×5 | `needs-suite` on each line: a fixture export test that writes the app's `weekOfWork` documents into `UITests/Fixtures/suite/` and fails when they drift | `Tests/<X>ModelTests/SuiteFixtureExportTests.swift`, `UITests/Fixtures/suite/<its files>` | the files exist and decode |
| A-x-1 ×5 | `needs-suite` on each line: `<X>Model` conforms to `SuiteDocumentHost` (open, new from preset, and the verbs it takes); `<X>App` adds `.suiteApp(.x, host:)`, `@NSApplicationDelegateAdaptor(SuiteAppDelegate.self)` (Photo subclasses it for PV-1) and `SuiteCommands()`; its menu journey's item counts updated | `Sources/<X>Model/<X>DocumentHost.swift`, `Tests/<X>ModelTests/<X>DocumentHostTests.swift`, `Sources/<X>App/<X>App.swift`, its menu journey file | host tests on Linux; `testSwitchToMenu` |

Engine: none.

**F5 `settings`** (wave 3) · tier 2 · waits on F4 (the hand-off route)

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| ST-1 | `SuitePreferences` store and per-app keys | `Sources/SuiteModel/Preferences/`, `Tests/SuiteModelTests/Preferences*.swift`, `Sources/SuiteShell/Live/PreferencesSlot.swift` | stale-revision and clamp tests |
| ST-2 | Settings scene: General and five app tabs; `SettingsModel`; the launcher's Settings menu | `Sources/AfterGlowApp/Settings*.swift` (includes `SettingsView.swift`), `Sources/AfterGlowApp/LauncherCommands+Settings.swift`, `Tests/AppSnapshotTests/AfterGlowSettingsSnapshots.swift` | goldens; layout 7.3 |
| ST-3 | Route ⌘, from any app; apply changes on notification | `Sources/SuiteShell/SettingsRoute.swift`, `Sources/SuiteShell/Live/SettingsSlot.swift` | SJ12 |
| ST-4 | Journeys SJ12, SP8 | `UITests/AfterGlowJourneyTests+Settings.swift`, `+PerfSettings.swift`, `UITests/SuiteBudgets+Settings.swift` | QB-S8 |
| A-x-4 ×5 | `needs-suite`: each app reads units and (if it autosaves) the interval | `Sources/<X>Model/<X>SuitePreferences.swift` | each app's Model test |

**F6 `recents-open-in`** (wave 3) · tier 1 · waits on F4; apps' saves (#205, #209, Photo PV-1)

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| RO-1 | Recents rules (when to record, missing files), routing as live types | `Sources/SuiteModel/Recents/`, `Sources/SuiteModel/Routing/`, `Tests/SuiteModelTests/Recents*.swift`, `Routing*.swift`, `TypeRegistryPlistTests.swift`, `Budget+Recents.swift` | QB-SM1; registry equals `Bundle/Info` plists |
| RO-2 | `SuiteDocumentsBridge`, `ThumbnailWriter`, `OpenInMenu`; the recents, routing and thumbnails slots | `Sources/SuiteShell/SuiteDocumentsBridge.swift`, `ThumbnailWriter.swift`, `OpenInMenu.swift`, `Live/RecentsSlot.swift`, `Live/RoutingSlot.swift`, `Live/ThumbnailsSlot.swift` | macOS build |
| RO-3 | Journeys SJ4, SJ5, SJ11, SP6 | `UITests/AfterGlowJourneyTests+Recents.swift`, `+Routing.swift`, `+OpenIn.swift`, `+PerfRouting.swift`, `UITests/SuiteBudgets+Routing.swift` | the journeys; QB-S6 |
| A-x-2 ×5 | `needs-suite`: each app records opens and saves, shows the shared list in File > Open Recent (Flare's `recent`, Halo's `HaloRecentFile`, Photo's system list give way), publishes a thumbnail; Library accepts an `.open` of images as an import | `Sources/<X>App/<X>SuiteDocuments.swift`, its File menu file, `Tests/AppSnapshotTests/<X>ThumbnailFidelityTests.swift` | QB-SV1 per app |

Engine: none.

**F7 `clipboard-drag`** (wave 3) · tier 1 · waits on F2; #415, #384, Photo PV-2; Design's SVG writer (#418)

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| CD-1 | `PasteboardCoding` live (moved from the fake), the per-app accept table, file URLs | `Sources/SuiteModel/Pasteboard/`, `Tests/SuiteModelTests/Pasteboard*.swift`, `DropRoutingTests.swift`, `Budget+Pasteboard.swift` | QB-SM5, QB-SV2 |
| CD-2 | `PasteboardBridge`, `DragBridge`, the pasteboard slot | `Sources/SuiteShell/PasteboardBridge.swift`, `DragBridge.swift`, `Live/PasteboardSlot.swift` | macOS unit test round trip through `NSPasteboard(name:)` |
| CD-3 | Journeys SJ6, SJ14, SP5; `CrossAppVectorGoldenTests` | `UITests/AfterGlowJourneyTests+Paste.swift`, `+Drag.swift`, `+PerfPaste.swift`, `UITests/SuiteBudgets+Paste.swift`, `Tests/AppSnapshotTests/CrossAppVectorGoldenTests.swift` | QB-S5, QB-S9, QB-SV3 |
| A-x-3 | `needs-suite`: Design writes the envelope and SVG (and reads SVG for Flare → Design); Flare reads SVG into shapes (writes SVG after #366); Photo reads PNG and image envelopes; Library copies a photo as PNG and accepts drops; every app with a colour row adds Edit > Copy Color and Paste Color | `Sources/<X>Model/<X>SuitePasteboard.swift`, its Edit menu file | each app's paste test |

Engine: **needs a new core issue**: "FlareCore: build shapes from SVG path
data and basic shapes (`path`, `rect`, `circle`, `ellipse`; fill, stroke,
opacity; `M L H V C S Q T Z`, absolute and relative), each cubic kept as a
cubic; acceptance: Design's `cards` fixture as SVG imports with equal bounds
(±0.5 pt) and equal fills."

**F8 `photo-round-trip`** (wave 4) · tier 2 · waits on F4, F6; Library #210, #212 and its v1 (Library blueprint calls the round trip "later"); Photo PV-1 (`.ora` save)

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| RT-1 | Round-trip sessions in the store | `Sources/SuiteModel/RoundTrip/`, `Tests/SuiteModelTests/RoundTrip*.swift`, `Sources/SuiteShell/Live/RoundTripSlot.swift` | state machine tests |
| RT-2 | Journeys SJ10, SP7; `RoundTripFidelityTests` | `UITests/AfterGlowJourneyTests+RoundTrip.swift`, `+PerfRoundTrip.swift`, `UITests/SuiteBudgets+RoundTrip.swift`, `Tests/AppSnapshotTests/RoundTripFidelityTests.swift` | QB-S7, QB-SV5 |
| A-LI-6 | Library: Photo > Edit in Photo (⌘E); receive `.returnEdit`; stack the copy | Library's own files | Library's journey step |
| A-PH-6 | Photo: round-trip document mode (title, Save writes `.ora` + flattened copy, sends `.returnEdit`) | Photo's own files | Photo's journey step |

Engine: none.

**F9 `shared-assets`** (wave 4) · tier 2 · waits on F3, F5

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| SA-1 | Asset index live over the store, payload files, revisions, `AssetsModel` | `Sources/SuiteModel/Assets/`, `Tests/SuiteModelTests/Assets*.swift`, `Budget+Assets.swift`, `Sources/SuiteShell/Live/AssetsSlot.swift` | QB-SM3 |
| SA-2 | Assets page; Window > Assets | `Sources/AfterGlowApp/Assets*.swift` (includes `AssetsPage.swift`), `Sources/AfterGlowApp/LauncherCommands+Assets.swift`, `Tests/AppSnapshotTests/AfterGlowAssetsSnapshots.swift` | goldens |
| SA-3 | Journey SJ13; `needs-ui` `SwatchChip` | `UITests/AfterGlowJourneyTests+Assets.swift` | QB-SV2 |
| A-x-5 | `needs-suite`: Design: Add to Assets, Update Asset, SUITE COLOURS; Flare and Photo: SUITE COLOURS in their colour popovers | `Sources/<X>App/<X>SuiteColors.swift`, its colour popover file | each app's journey step |

Engine: none for v1 (the index lives in SuiteModel). creative-core's
`CoreAsset` module (the suite asset model, #148–#154, a stub today) can
replace it later; that is a later decision, not a dependency.

**F10 `onboarding`** (wave 4) · tier 3 · waits on F3, F5

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| OB-1 | Onboarding flow live, `OnboardingModel`; three pages; samples | `Sources/SuiteModel/Onboarding/`, `Sources/AfterGlowApp/Onboarding*.swift` (includes `OnboardingWindow.swift`), `Sources/SuiteShell/Live/OnboardingSlot.swift`, `Tests/SuiteModelTests/Onboarding*.swift`, `Tests/AppSnapshotTests/AfterGlowOnboardingSnapshots.swift` | goldens per page |
| OB-2 | Journey SJ18 | `UITests/AfterGlowJourneyTests+Onboarding.swift` | SJ18 |

**F11 `updater`** (wave 4) · tier 2 · waits on F5; the captain's choice of feed host and signing key (Q2)

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| UP-1 | Feed, version compare, install plan | `Sources/SuiteModel/Update/`, `Tests/SuiteModelTests/Update*.swift` | feed and signature tests |
| UP-2 | Update sheet, `UpdateModel`, the live `UpdateChecking` (download, CryptoKit verify, quit the apps, replace, relaunch) supplied through `with(updates:)`; AfterGlow > Check for Updates… | `Sources/AfterGlowApp/Update*.swift` (includes `UpdateSheet.swift` and `UpdateService.swift`), `Sources/AfterGlowApp/LauncherCommands+Update.swift`, `Tests/AppSnapshotTests/AfterGlowUpdateSnapshots.swift` | `testUpdateWaitsForUnsavedWork` |
| UP-3 | Journey SJ15 | `UITests/AfterGlowJourneyTests+Update.swift` | SJ15 |

**F12 `linked-assets`** (wave 5) · tier 3 · waits on F9; #418

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| LA-1 | `AssetLinking` live; link checks on activation and notification | `Sources/SuiteModel/Links/`, `Tests/SuiteModelTests/Links*.swift`, `Sources/SuiteShell/Live/LinkingSlot.swift` | status tests |
| LA-2 | Journey SJ16; `LinkedAssetGoldenTests`; `needs-ui` `LayerList` accessory | `UITests/AfterGlowJourneyTests+Links.swift`, `Tests/AppSnapshotTests/LinkedAssetGoldenTests.swift` | QB-SV6 |
| A-FL-7, A-HA-7 | Flare and Halo: store the link on a layer item; Object > Update Linked Asset (one undo step) | their own files | their journey steps |

Engine: **needs a new core issue**: "FlareCore: a layer item that references
an external asset (asset id, kind, revision, cached SVG or PNG payload),
survives encode and decode unchanged, draws its cached payload, and a
command that replaces the payload and revision as one undo step." Halo
keeps its document in HaloModel (no core document engine yet, #767), so
Halo's half is app-line work.

**F13 `flare-in-halo`** (wave 5) · tier 3 · waits on F6; Halo's image layers and "Flare scene as a layer" (H10, Later in #767)

| Task | Behavior | Owned files | Proof |
|---|---|---|---|
| FH-1 | `AnimationSummary` rules; Open In ▸ Halo for `.flare` | `Sources/SuiteModel/Animation/`, `Tests/SuiteModelTests/Animation*.swift` | summary tests on a fixture |
| FH-2 | Journey SJ17; `FlareInHaloGoldenTests` | `UITests/AfterGlowJourneyTests+FlareInHalo.swift`, `Tests/AppSnapshotTests/FlareInHaloGoldenTests.swift` | QB-SV4 |
| A-HA-8 | `needs-suite` on Halo: an animation layer that samples a FlareCore scene; the live `AnimationSourceReading`, supplied by HaloApp through `with(animations:)` | Halo's own files (named in the issue) | Halo's tests |

Engine: waits on the CoreRaster affine composite that #767 names as "needs
a new core issue, before image layers", and **needs a new core issue**:
"FlareCore: render one scene at frame N to an RGBA `PixelBuffer` at a given
size (the rasterizer Flare's PNG export uses, moved into the engine);
acceptance: equals Flare's PNG export of that frame."

### 8.3 Waves

| Wave | Features | Waits on | C4 owner | Merges |
|---|---|---|---|---|
| 0 | targets (BU-S, BU-0, BU-1) | #763 green | targets | BU-0, BU-1 supervisor; BU-S is a local spike (docs only) |
| 1 | bundle, suite-contracts | wave 0 | bundle | bundle BU-4, BU-6 supervisor; the rest lane |
| 2 | home, switching | wave 1 (suite-contracts); SuiteUI #331–#333 for goldens and the journey template; `AppTile`, `ThumbnailBadges`, `SidebarRow` accessory (`needs-ui`, placeholders until then); A-x-0 and A-x-1 for the cross-app journeys | home | lane |
| 3 | settings, recents-open-in, clipboard-drag | wave 2; the two size tokens (`needs-ui`); app saves #205, #209, PV-1; #415, #384, #418; the SVG core issue; A-x-2, A-x-3, A-x-4 | recents-open-in | lane |
| 4 | photo-round-trip, shared-assets, onboarding, updater | wave 3; Library v1, Photo PV-1; `SwatchChip` (`needs-ui`); Q2 for the updater; A-LI-6, A-PH-6, A-x-5 | shared-assets | lane |
| 5 | linked-assets, flare-in-halo | wave 4; the two core issues; Halo H10 | linked-assets | lane |

**No shared files within a wave.** Every owned path above is listed once.
The files every wave could want are owned once and early: `Package.swift`
and `docs/c4/model.json` (BU-1), every placeholder view file the later
screens fill in (BU-1 creates them; their feature owns them after),
`project.yml` (BU-3), `SuiteServices+Live.swift` (SC-5; afterwards each
feature edits only its own slot file under `Sources/SuiteShell/Live/`),
`AfterGlowApp.swift` (BU-1; each launcher menu is a `LauncherCommands+<Area>.swift`
stub BU-1 creates and one feature owns), perf and budget files (one
`+Perf<Area>.swift`, `SuiteBudgets+<Area>.swift` and `Budget+<Area>.swift`
per feature),
`SuiteFixtures` (SC-3, all five fixtures up front), `UITests/audit-baseline.json`
(HM-3), `docs/design.md` (HM-4), `docs/review-rubric.md` (SW-4). Journey
files are one per feature (`AfterGlowJourneyTests+<Area>.swift`).
Snapshot files are one per feature. SW-3 creates `SettingsRoute.swift`
and `OpenInMenu.swift` as disabled stubs ("Not connected yet (settings)."
and "… (recents-open-in).") so `SuiteCommands` builds in wave 2; settings
and recents-open-in own them from wave 3. The `Sources/SuiteModel/<Area>/`
folders are disjoint by construction. Within wave 4, onboarding and
updater both depend on preferences (F5, wave 3) but own nothing of it.

**Supervisor merges** (protected paths): BU-0 (`scripts/size-report`,
`.github/workflows/ci.yml`), BU-1 (`Package.swift`), BU-4
(`scripts/bundle-apps`), BU-6 (`.github/workflows/ci.yml`). Everything else
takes the fast lane.

### 8.4 What this needs from the app blueprints

| From | Needs | Where they stand |
|---|---|---|
| SuiteUI (#765) | `AppTile`, `ThumbnailBadges` app and missing badges, `SidebarRow` trailing accessory, `SwatchChip`, `LayerList` accessory (6.3); #333's per-file journey template; #330 FrameProbe with cross-process marks (`mach_continuous_time`) | none planned; filed as `needs-ui` by the features that need them |
| Flare (dev) | A-FL-1 `.suiteApp(.flare)` after #346; A-FL-2 the shared recents replaces `FlareWorkspace.recent` as the source of Open Recent (the Model keeps its API); A-FL-3 read SVG and the envelope on paste (#384); A-FL-5 SUITE COLOURS in FILL; A-FL-7 linked layers | #346, #384, #205 open; no conflict with the mac-platform packet (it owns `FlareFiles.swift`, A-FL-2 lands after it) |
| Design (#766) | A-DE-1; A-DE-2 recents and thumbnail on save; A-DE-3 envelope and SVG on copy (beside `org.creativesuite.design.layers`); A-DE-5 Add to Assets and SUITE COLOURS; the SVG writer of F6 `export` (#418) | Design's F2 `copy-group` and F6 `export` are the hosts; autosave out of v1 (its Q4) conflicts with the suite policy (Q6 below) |
| Photo (#768) | A-PH-1; A-PH-2 the shared recents instead of the system list; A-PH-3 paste envelope images (PV-2); A-PH-6 round-trip document mode; Q7's exported type is answered by BU-5 | PV-1 documents and PV-2 edit are the hosts |
| Library (#769) | A-LI-1; A-LI-2 accept `.open` of images as import; A-LI-3 copy a photo as PNG; A-LI-6 Edit in Photo and stacking the returned copy | Library calls the round trip "later" (section 1.4); the suite schedules it in wave 4, after Library v1 |
| Halo (#767) | A-HA-1; A-HA-2 `HaloRecentFile` list replaced by the shared list; the UTType id `org.creativesuite.halo.project` in `HaloDocumentType.swift`; A-HA-7 linked layers; A-HA-8 the Flare animation layer (H10) | H10 is Later in Halo; flare-in-halo waits for it |

### 8.5 Engine work, all of it

| Feature | creative-core work | Status |
|---|---|---|
| bundle | none on R1; fallback: a `.dynamic` `CreativeEngines` product | needs a new core issue only if BU-3's spike fails |
| clipboard-drag | SVG path and basic-shape import into FlareCore shapes | needs a new core issue |
| linked-assets | external-asset layer item with a replace command | needs a new core issue |
| flare-in-halo | render a scene at frame N to a `PixelBuffer`; CoreRaster affine composite (#767's) | needs a new core issue (the first); the second is Halo's |
| shared-assets | none in v1; CoreAsset (#148–#154) later | existing core issues, p3, no dependency |
| all others | none | — |

---

## 9. Decisions for the captain

Made here, with reasons (reverse any by saying so):

| # | Decision | Why |
|---|---|---|
| D1 | Embedded app bundles, one process each (2.5, shape B) | The only shape that keeps a real Dock icon per app; crash isolation; today's apps barely change |
| D2 | Shared frameworks through the `project.yml` release graph (route R1), not a second package | No source path moves while six blueprints are editing SuiteUI |
| D3 | One store folder by plain path; app group later | Ad-hoc signing has no team id for an app group |
| D4 | Hand-offs are files opened with the target app | Works for running and cold apps alike; launch arguments don't reach a running app |
| D5 | The suite never imports an engine; apps convert | Keeps SuiteModel tiny and Linux-fast; a shared store never loads five engines |
| D6 | Every document app follows Flare's recovery-file policy | Losing work is worse than any missing feature (flare.md decision 4) |
| D7 | `⌃⌘0`–`⌃⌘5` for Switch To | Free in every app's menus today (SW-3's test guards it) |

Open questions:

1. **Q1 Names and ids.** The id prefix (`org.creativesuite` today), the
   bundle id of AfterGlow, and the inner app names in Finder (`Flare.app`
   or `AfterGlow Flare.app`).
2. **Q2 Updater.** Where the feed and zips live (GitHub Releases of this
   repo?), who holds the Ed25519 signing key, and whether to write our own
   (planned: about 400 lines with CryptoKit) or adopt an MIT-licensed
   open-source updater framework (needs an approving issue; CLAUDE.md "No
   new dependencies").
3. **Q3 Signing and distribution.** v1 stays ad-hoc signed and not
   sandboxed. A Developer ID with notarization (hardened runtime) brings a
   team id, and with it an app group container for the store. When?
4. **Q4 App icons.** Six Dock icons need art; until then BU-5 ships plain
   placeholders (a coloured rounded square with the app's initial, drawn by
   a script). Who draws them?
5. **Q5 Prewarm.** Should AfterGlow launch the last-used app hidden at its
   own launch, so the first switch is an activation too? Costs memory for
   an app the person may not open. Default in this blueprint: no.
6. **Q6 Recovery in Design and Halo v1.** D6 makes recovery the suite rule;
   Design's blueprint leaves it out of v1 (its Q4) and Halo calls it
   "Later". Pull it into their v1, or let the suite rule apply from their
   v1.1?
7. **Q7 Where a returned edit is written.** Next to the original
   (`<name> edit <n>.png` and `.ora`; Library's folder stays the truth) or
   inside the suite store (the person's folders stay untouched, but the
   catalog then points into Application Support)?
8. **Q8 Library round trip timing.** Library's blueprint calls the round
   trip "later"; this blueprint schedules it in wave 4, after Library v1.
   Agree?
9. **Q9 A new line.** This work needs `line:suite` (and a `needs-suite`
   label for app-line adoption tasks). Create them?
10. **Q10 Finder visibility.** Embedded apps may not show in Launchpad or
    Spotlight on their own; AfterGlow does. Acceptable for v1?
12. **Q12 Approve shape B now, or after BU-S?** BU-S (wave 0) measures
    cold launch, activation and memory of shape B against shape A on a Mac.
    This blueprint recommends B on the brief's Dock-icon requirement alone;
    the captain can make approval wait for those numbers.
11. **Q11 Standalone builds.** Keep publishing the five standalone
    `<X>App.app` bundles in `app-builds` for review until every journey
    launches through `AfterGlow.app`, then drop them?

---

## 10. Critic rounds

One critic agent per round tried to refute the blueprint: journeys with no
component, contracts a journey can't be built from, budgets that can't be
measured, overlapping owned files, missing open issues, product names.

### Round 1 (30 findings: 3 blocking, 23 major, 4 minor)

| # | Severity | Finding | Fix |
|---|---|---|---|
| 1 | blocking | Journeys ran on per-process in-memory fakes, so nothing one app wrote reached another | Journeys run `.live` everywhere; `-SuiteFixture` seeds the live store (`SuiteFixtures.store`, in the contracts); `.fake` is for snapshots and Model tests (4.1, 5.1) |
| 2 | blocking | No contract let an app act on a received hand-off; SuiteShell can't see app Models | `SuiteDocumentHost` (UC-18) with `FakeDocumentHost`; `.suiteApp(_:host:)`; adoption A-x-1 (5, 8.2) |
| 3 | blocking | BU-1's placeholder files sat on no C4-owned path | Placeholders moved to owned paths (`Values/SuiteIdentity.swift`, `SuiteCommands.swift` stub) (8.2) |
| 4 | major | Animation and update slots in SuiteShell couldn't reach HaloModel or AfterGlowApp | `SuiteServices.with(animations:updates:)`; slots removed (5.1, 8.2) |
| 5 | major | No launcher view-models; state would live in views | `HomeModel` in the contracts (compiles); `AssetsModel`, `SettingsModel`, `OnboardingModel`, `UpdateModel` named with owners (2.3, 5.7) |
| 6 | major | `AfterGlowApp.swift` had no owner after BU-1 | One `LauncherCommands+<Area>.swift` stub per feature, created by BU-1 (2.3, 8.2) |
| 7 | major | `Journey` can drive only one app | HM-0 `Journey+Suite.swift`: bundle path, attach by bundle id, per-process audit keys (4.1) |
| 8 | major | SJ11's empty case impossible (PNG has two readers) | Uses a Design document; `openInRefusal` and `SuiteError.noOtherReader` |
| 9 | major | Three journey sentences missing from `SuiteError` | `.originalMissing`, `.linkMissing`, `.updatePostponed`; fakes produce them; main.swift checks the text |
| 10 | major | File drops had no typed path | `public.file-url` in the registry and coding; SJ14 drops a file on the home |
| 11 | major | Fixtures lacked the files journeys open | Every file named per fixture; `crowd`, flags and samples added; documents from each app's fixture export (A-x-0) |
| 12 | major | Save-path flags couldn't reach cold-launched apps | The launcher forwards arguments named for the app (2.6) |
| 13 | major | SJ3 step 5 used a disabled menu item | "Show Flare Window" enabled when the app has no window (6.2) |
| 14 | major | ⌃⌘0 bound twice; system items broke SJ0's counts; apps' own menu journeys would break | Duplicate dropped; SJ0 counts only listed items; A-x-1 updates each app's menu journey; SW-3 owns the clash test |
| 15 | major | Layout table off the 4 pt grid; big widths offscreen on the runner; no tile function | Widths rounded to 4 pt; `tileWidth`, `tileShowsChips`; journeys at 880 and 1000 only; the sweep runs in main.swift |
| 16 | major | Symbol gate unreachable as defined; size-report owner unclear | Specializations excluded, one report-only run first; BU-0 writes the script, BU-4 extends it |
| 17 | major | Only one measurement for the packaging comparison | BU-S local spike measuring both shapes; Q12 lets approval wait for it |
| 18 | major | QB-S9 and the clock not measurable as written; 5 samples | QB-S9 measures the drop-target highlight; one clock (system uptime); n = 20 |
| 19 | major | Store race not safe across processes; tested in one | Lock file around read-merge-write; QB-SM6 runs two processes |
| 20 | major | App-target work written as suite tasks | `needs-suite` issues on each line, exact files, sequenced per app (8.2) |
| 21 | major | Shared budget/perf files; SP3/SP4 and some goldens unowned | Per-feature `+Perf<Area>`, `SuiteBudgets+<Area>`, `Budget+<Area>`; SP3/SP4 in HM-3; onboarding and update snapshot files owned |
| 22 | major | Design lint blocks swatches and window sizes | `SwatchChip` and two size tokens as `needs-ui`, in the waits (6.3, 8.3) |
| 23 | major | Flare in Halo and recovery both "v1" and "later" | Flare in Halo marked conditional; recovery is a rule adopted per app's schedule; autosave setting per app with a reason |
| 24 | major | Flare → Design vector and Halo linking had no tasks or tests | SJ6 step 6 (after #366); `testPlaceLinkedInHalo` |
| 25 | major | Journeys used undefined controls | Update Asset, Copy/Paste Color, New from Clipboard defined with owners (6.2); `assets(fromFileID:)` |
| 26 | major | Contracts couldn't report changes | `changes() -> AsyncStream<Int>` on four contracts; fakes stream; checked in main.swift |
| 27 | minor | Missing issues #351, #208, #780, #782, #12, #33, #423, #773, #777; #15 described wrongly | Added to 8.1; #15 fixed |
| 28 | minor | "Finder", "Spotlight", "Launchpad", "Quick Look" | Kept: they are the operating system's own features that every Mac app integrates with, not another company's creative product; no other product name found |
| 29 | minor | Counts and placements inconsistent (SC-2, contents, rule 4, helper folders, YAML parsing, restore vs start empty) | Fixed; `BuildGraphTests` scans lines; "start empty" applies only when the person picks it |
| 30 | minor | `onOpenURL` with no window; `terminate()` isn't a crash; SJ5 bypassed routing | `SuiteAppDelegate.application(_:open:)`; `SIGKILL`; SJ5 opens through Launch Services after `lsregister` |
