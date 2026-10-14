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
