# Feature packet: editor-in-window

**Feature:** `SuiteWindow` can hold a canvas editor. It gets a sidebar slot
for an app's own list, a window subtitle for the save state, an inspector
width for an editor's 280 pt panel and a `-SuiteWindowSize` launch argument.
A new `EditorDetail` lays out the detail column: the canvas, Flare's
floating tool box over it, and the status line under it. A new
`SidebarActionRow` holds a list's icon commands. The journeys get
`expectEditorWindow()`, a geometry check and one journey that shows the
four tool apps side by side. Every `SuiteWindow` also gets the app switcher
the captain asked for, centered in its toolbar (`AppSwitcher`). Its items
stay disabled with their reason until the switching feature wires them. Nothing is removed here; `editor-shell-removal`
does that once Design and Photo have moved.
**Line:** `line:suiteui` · **Wave:** 1 (`../../suite/features/shell-parity-waves.md`) · **Lead branch:** `lead/editor-in-window`
**Blueprint:** `docs/blueprints/suiteui.md` section 6 (Captain decision
2026-10-15), `docs/blueprints/suite.md` section 6, `docs/design.md`
(Editor shell, Window structure, Layers: content vs. control).

**Covers:** the three captain decisions of 2026-10-15 (one shell, one tool
box, the app switcher), recorded in section 6 of the suite, SuiteUI, Design
and Photo blueprints. The SuiteUI half has no issue of its
own; every PR says "Part of the editor-in-window feature".

**Depends on:** none. #778 (suite-harness) is closed: the goldens, the
gallery, `.suiteControl` and `.suiteProbes()` this feature uses are on
`dev`. No creative-core issue.

**Base.** This packet builds on `SuiteWindow.swift` as it was before #962,
which is how it reads once #962's revert lands (3033a12 has it): the
`.inspector` sits on the detail column's content, inside the
`NavigationSplitView`. #962 moved it outside the split view and broke four
apps' journeys, so it is being reverted. Nothing here builds on #962's
layout, and no task moves the inspector.

**#933 (the split view laid out wider than a 900 to 1000 pt window) is a
dependency of the geometric test, not a design to build on.** Its fix will
change the column minimums instead of moving the inspector. Until that fix
merges, `SuiteWindow` can still run past the window's edges, and
`expectShellGeometry()` would be red for reasons outside this feature. So:

- EW-4 (the geometry rules and the journey helper) builds and merges
  without it. Its Linux tests don't touch a window.
- EW-5's geometric steps (3 and 5, and the toolbar-fit assertion) depend on
  #933's fix. If #933 is still open when EW-5 is ready, EW-5 merges with
  those steps behind `XCTSkip("waits on #933")`, and **EW-5b** removes the
  skip once the fix merges. EW-5b is a one-file follow-up that owns
  `UITests/SuiteJourneyTests+EditorWindow.swift` after EW-5.
  editor-in-window's `feature-done` waits for EW-5b, so the feature never
  closes with the geometric test skipped.
- Every width in this packet comes from the tokens, never a literal. The
  window minimum is whatever #933's new column minimums give, with the
  editor's 304 pt inspector (`editorPanelWidth + 2 · m`) in place of the
  ideal: 944 pt with today's tokens.

**"1024 × 768" in this packet means the runner's display, not a window
size.** The macOS runner's screen is 1024 × 768, and its menu bar takes the
top 31 pt. `-SuiteWindowSize 1024x768` asks for that size, and
`SuiteWindowSizer` constrains it to the screen's visible frame, so the
window comes out at about 1024 × 737. Every geometric test asserts the
window inside the visible frame and every frame inside the window. None
asserts an exact 768.

**Unblocks:** Design shell-parity and Photo shell-parity (wave 2), then
editor-shell-removal (wave 3).

**Stage 1 check: is #933 fixed?** Before #962, every `SuiteWindow` app
reported `outlineRow ''` and `cell ''` offscreen (sidebar rows at x −8 with
the window at x 12) and a `more toolbar items` overflow button. That is
#933. The lead checks #933's state and records it in RECORD.md, then reads
the audit JSON and `*-launch.png` from the first green macOS run after #933's
fix merges. If the sidebar rows are still offscreen there, the lead comments
on #933 and on the feature issue. This feature doesn't fix #933: its fix
lands in its own PR and owns `SuiteWindow.swift` and the tokens for that
change. EW-1, which also edits `SuiteWindow.swift`, rebases on it whichever
merges second. Design and Photo can't absorb a new `offscreen` key (they
have none in the baseline), so wave 2 waits for this feature's
`feature-done`, which waits for #933 through EW-5b.

**Building blind.** All of `Sources/SuiteUI/` compiles only in the macOS job
on `dev`. The pure parts (`EditorDetailLayout`, `SuiteWindowSize.parse`) get
plain tests in `Tests/SuiteUITests`. `ShellGeometry` is Foundation-only in
`Tests/AppAuditTests`, so Linux runs its tests. Check every SwiftUI and
AppKit API with the `apple-docs` MCP and say so in the PR. Copy a SuiteUI
file that builds. The only new tokens are the switcher's (EW-7):
`switcherIcon` (22), `switcherSpacing` (80, the ideal distance between item
centers), `switcherSpacingMinimum` (40, what it shrinks to before any
toolbar item would overflow) and `switcherCapsule` (90 × 48). Every other
size comes from existing tokens (`ruler`, `toolButton`, `anchorHit`,
`editorPanelWidth`, the spacing scale).

## Journey steps

All of them in `UITests/SuiteJourneyTests+EditorWindow.swift` (EW-5), on
the new gallery page `editor-window` inside Library
(`-SuiteGallery editor-window -SuiteWindowSize 1024x768`):

1. [EW-5, EW-J1] The window opens with a title, the subtitle "Edited", a sidebar holding
   an app-style list (two sections, Pages and Layers, with a
   `SidebarActionRow` under Pages), a toolbar holding New and Open as
   document actions beside the title, then Save, Undo (disabled, tooltip
   "Nothing to undo."), Redo, Zoom Out, Fit and Zoom In plus the inspector
   toggle, the detail holding a `CanvasViewport` with
   rulers and a 1600 × 1000 artboard, the floating palette at its leading edge,
   and the status line, and an inspector 304 pt wide.
   `expectEditorWindow()` passes; shot `launch`.
2. [EW-5, EW-J2] `clickEachTool()`: every enabled tool in the palette is clicked and shot.
3. [EW-5 (EW-5b if skipped), EW-J3] `expectShellGeometry()` passes at 1024 × 768 (see Quality tests).
4. [EW-5, EW-J4] Option-Command-I hides the inspector: the detail grows and the palette
   stays put; shot `inspector-hidden`. Show it again.
5. [EW-5, EW-J5] The same page under `-AppleInterfaceStyle Dark`: shots `launch-dark`,
   then `expectShellGeometry()` again.
6. [EW-5, EW-J6] The switcher (`suite.switcher`) is centered in the toolbar with six
   items: `suite.switcher.home`, `.flare`, `.design`, `.photo`, `.library`
   and `.halo`. Library's is the current item (the gallery runs inside
   Library) and carries the selected trait. Each item's help is the app's
   name and shortcut ("Design (⌃⌘2)"), followed by its reason while it can't
   act ("Not connected yet (switching)."). Every item is disabled, and Tab
   with Full Keyboard Access visits each one once. Shots
   `switcher` and `switcher-dark` crop the row (`shot(_:element:)`).

And in `UITests/SuiteJourneyTests+Parity.swift` (EW-6):

7. [EW-6, EW-J7] `testAppsSideBySide` launches Flare, Design, Photo and Halo one after
   another at `-SuiteWindowSize 1024x768`. Flare opens New Sample
   Animation, Design and Photo use ⌘N (no test file is needed), and Halo
   launches with `-HaloSample`. The name sorts before
   `testEveryControlMeetsHitSize`, so this is never the class's last test,
   and its four `Journey`s never attach audit counts under the wrong app.
   Until wave 2, Design and Photo ignore the flag and keep their own size,
   so the test asserts the window size only for apps that are on
   `SuiteWindow`. It shoots each whole window as
   `parity-<app>-window` and each `suite.tools` palette as
   `parity-<app>-palette` (Halo has no tool palette today, so it gets a
   window shot only), and each app's switcher as `parity-<app>-switcher`
   (Design and Photo have one only after their wave-2 move). These shots skip the audit, because the other apps'
   counts belong to their own keys. The contact sheet lists the shots
   together under `suiteui`.

## Screens and states

| Screen | Normal | Empty | Narrow (window minimum) | Dark | Snapshot PNGs |
|---|---|---|---|---|---|
| `editor-window` gallery page | step 1 | the canvas slot shows an `EmptyStateView` and no palette (an editor shows its palette only over an open document, as Flare does) | the window at its minimum: the sidebar ideal (200) + the content minimum (440) + the 304 pt inspector = 944; nothing is clipped | the chrome is system glass in Dark; the canvas surround, rulers and status line follow the Dark tokens | `suiteui-editor-detail-light.png`, `-dark.png` (EW-2); `suiteui-window-slot-light.png`, `-dark.png` (EW-1); journey shots `suiteui-launch`, `suiteui-launch-dark`, `suiteui-inspector-hidden` |
| `SuiteWindow` with sections (Flare, Halo, Library) | unchanged by EW-1: the `suiteui-window-*` and `SuiteWindowLaunchSnapshots` goldens do not move. EW-8 adds the switcher to their toolbars; that is the only change in their journey shots. | – | unchanged | unchanged | their existing `*-launch` journey shots |
| App switcher (`AppSwitcher`) | one centered row of monochrome line icons, about 80 pt between centers, no labels, no bar or background behind it. The current item sits in a 90 × 48 capsule of system glass (dark translucent, with the glass's hairline rim and top highlight) and its icon is `textPrimary`, even while it is disabled (the current app's own item never switches anywhere); the others are `textSecondary`, and the system's disabled dimming applies to them only. | – (always six items) | the spacing steps down from 80 toward 40 so that no toolbar item overflows at 1024 pt | the capsule is the system's dark glass in both appearances; the icons follow the appearance's text colors | `suiteui-app-switcher-light.png`, `-dark.png` (EW-7); journey crops `suiteui-switcher`, `suiteui-switcher-dark` |

## Contract slice

```swift
// Sources/SuiteUI/SuiteWindow.swift (EW-1)
public struct SuiteWindow<Sidebar: View, Content: View, Inspector: View>: View
extension SuiteWindow where Sidebar == SuiteSidebarList {
    // today's three inits, unchanged in their parameters, plus `subtitle: String? = nil`
    // and `documentActions: [ToolbarAction] = []` (placed `.navigation`, beside the title over the
    // detail column, so file commands never compete with `actions` for the trailing room)
}
extension SuiteWindow {
    /// An app's own sidebar list: Design's pages and layer tree, Photo's layers.
    public init(
        title: String, subtitle: String? = nil, documentActions: [ToolbarAction] = [],
        actions: [ToolbarAction] = [], inspectorWidth: CGFloat? = nil,
        @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content,
        @ViewBuilder inspector: () -> Inspector)
}
// Sources/SuiteUI/SuiteSidebarList.swift (EW-1): today's List of SidebarSections, moved out of SuiteWindow
public struct SuiteSidebarList: View
// Sources/SuiteUI/SuiteWindowSizer.swift (EW-1)
public enum SuiteWindowSize { public static func parse(_ arguments: [String]) -> CGSize? }  // "-SuiteWindowSize 1024x768"

// Sources/SuiteUI/EditorDetail.swift (EW-2)
public struct EditorDetail<Canvas: View, Palette: View, Status: View>: View {
    public init(@ViewBuilder canvas: () -> Canvas, @ViewBuilder palette: () -> Palette,
                @ViewBuilder status: () -> Status)
}
public struct EditorDetailLayout: Equatable, Sendable {
    /// `viewport` is what CanvasViewport reports through `onSize`: the area inside the rulers.
    public init(viewport: CGSize, toolCount: Int)
    public static func paletteSize(toolCount: Int) -> CGSize   // (toolButton + 2·xs) × (n · toolButton + 2·xs)
    public var paletteFrame: CGRect          // in viewport coordinates: x = l, centered vertically
    public var clearance: CGFloat            // l + palette width + anchorHit / 2 + xs (the rulers are already outside `viewport`)
    public func fitScale(artboard: CGSize) -> Double   // hosts call this instead of ViewerZoom.fitScale
}
// CanvasViewport.swift (EW-2): its own ⌘0 reads `\.canvasFitScale`, an environment closure EditorDetail
// sets from EditorDetailLayout, so the menu's Fit and the canvas's ⌘0 give the same zoom.
extension EnvironmentValues { @Entry public var canvasFitScale: (@Sendable (CGSize, CGSize) -> Double)? = nil
}

// Sources/SuiteUI/SidebarActionRow.swift (EW-3)
public struct SidebarActionRow: View { public init(_ actions: [ToolbarAction]) }

// Sources/SuiteUI/AppSwitcher.swift (EW-7)
public struct AppSwitcherItem: Identifiable, Sendable {
    public let id: String                   // "home", "flare", … ; the identifier is "suite.switcher.<id>"
    public let title: String                // "Design": the accessibility label
    public let systemImage: String          // a monochrome line glyph
    public let shortcut: String             // "⌃⌘2", shown in the tooltip
    public let unavailableHelp: String?     // non-nil: disabled, and the tooltip says why
    public var help: String                 // "Design (⌃⌘2)", then the reason on a new line when unavailable
}
public struct AppSwitcher: View {
    public init(items: [AppSwitcherItem], current: AppSwitcherItem.ID?, onSelect: @escaping @MainActor (AppSwitcherItem.ID) -> Void)
}
public struct AppSwitcherState: Sendable { public var items: [AppSwitcherItem]; public var current: AppSwitcherItem.ID?; public var onSelect: … }
extension AppSwitcherState {
    /// Home plus the five apps, every item disabled "Not connected yet (switching)."; the current item
    /// is the one whose app runs this process (the executable "DesignApp" → "design"; anything else → none).
    public static func placeholder(processName: String) -> AppSwitcherState
}
extension EnvironmentValues { @Entry public var suiteSwitcher: AppSwitcherState? = nil }   // nil: SuiteWindow shows the placeholder

// Tests/AppAuditTests/ShellGeometry.swift (EW-4): Foundation only, on AppAudit.Rect (AuditPixels.swift)
enum ShellGeometry {
    static func violations(window: Rect, regions: [String: Rect], minimums: [String: (width: Double, height: Double)],
                           apart: [(String, String)], clear: [(String, String)]) -> [String]
}
```

Accessibility identifiers. These stay: `suite.sidebar`, `suite.inspector`,
`suite.tools` and `suite.canvas`. These are new: `suite.viewport` (the
canvas region `EditorDetail` lays out, rulers included) and `suite.status`
(the status line), and `suite.switcher` with `suite.switcher.<id>` for each
item (EW-7). The sidebar slot is wrapped in a container with
`.accessibilityElement(children: .contain)` that carries `suite.sidebar`,
the way the inspector already carries `suite.inspector`, so an app's own
list keeps its own identifier inside it (`design.layers`, `photo.layers`).

## Pseudocode

```
SuiteWindow.body (as before #962; column minimums as #933's fix sets them):
  NavigationSplitView {
      sidebar                                   // SuiteSidebarList(sections…) or the app's view
        .accessibilityElement(children: .contain).accessibilityIdentifier("suite.sidebar")
        .navigationSplitViewColumnWidth(sidebarWidth)
  } detail: {
      content.frame(min contentMinimum, ideal contentIdealWidth, max ∞).tint(accent)
        .inspector(isPresented:) { inspector … .inspectorColumnWidth(min: w.min, ideal: w.ideal, max: w.max) }
            where w = inspectorWidth.map { (min: $0, ideal: $0, max: max($0, inspectorWidth.max)) } ?? SuiteSize.inspectorWidth
  }
  .navigationTitle(title)
  .navigationSubtitle(subtitle ?? "")           // the save state; empty shows none
  .toolbar {
      ToolbarItem(placement: .principal) {        // EW-8; check .principal and .sharedBackgroundVisibility(.hidden)
          AppSwitcher(state ?? .placeholder(processName))  //   with apple-docs: no toolbar glass may sit behind the row
      }
      ToolbarItemGroup(placement: .navigation) { documentActions … }   // EW-1: New, Open, Save, Export
      actions …; inspector toggle                 // as today: Undo, Redo, zoom
  }
  .background(SuiteWindowSizer(size: SuiteWindowSize.parse(arguments)))  // nothing added without the flag
  .frame(minWidth: sidebar ideal + contentMinimum.width + w.ideal, …)    // the window minimum follows the inspector

EditorDetail.body:
  VStack(spacing: 0) {
      canvas
        .frame(maxWidth: ∞, maxHeight: ∞)
        .overlay(alignment: .leading) {
            palette.padding(.leading, ruler + l).padding(.top, ruler)   // never over the rulers
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("suite.viewport")
      Divider()
      status.accessibilityElement(children: .contain).accessibilityIdentifier("suite.status")
  }
  .background(SuiteColor.canvasSurround)       // content: flat, no glass; the palette brings the one capsule

AppSwitcher.body (EW-7):
  ViewThatFits(in: .horizontal) { row(spacing: s) for s in [80, 64, 48, 40] }   // switcherSpacing … switcherSpacingMinimum
  row(spacing): HStack(spacing: 0) { ForEach(items) { item in
      Button { onSelect(item.id) } label: { Image(systemName: item.systemImage).font(size switcherIcon)
          .foregroundStyle(item.id == current ? textPrimary : textSecondary) }
        .frame(width: spacing, height: switcherCapsule.height)
        .background { if item.id == current { Capsule().frame(switcherCapsule).suiteGlass(in: Capsule()) } }  // the one glass shape
        .disabled(item.unavailableHelp != nil).help(item.help)
        .accessibilityLabel(item.title).accessibilityAddTraits(item.id == current ? .isSelected : [])
        .suiteControl(id: "suite.switcher.\(item.id)", enabled: item.unavailableHelp == nil, reason: item.unavailableHelp)
  } }.accessibilityElement(children: .contain).accessibilityIdentifier("suite.switcher")

EditorDetailLayout.fitScale(artboard):
  horizontal room = viewport.width  − 2 · clearance   // the artboard is centred, so both sides keep the clearance
  vertical room   = viewport.height − 2 · xxl
  return max(min(horizontal / artboard.width, vertical / artboard.height), smallest zoom stop)   // 0.05
```

## Tasks

Every task is one PR to `dev`, at most 400 changed lines and 15 files, with
the lines `Belt-Lead:`, `Feature: editor-in-window`, `Fast-Check: pass` and
`Head:`, and the label `fast-lane`. The last of EW-6 and EW-5b to merge
carries `feature-done`, so the feature never closes with the geometric test
skipped.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| EW-1 | – | `SuiteWindow` gets its sidebar slot, subtitle and inspector width, and handles `-SuiteWindowSize`. Today's sections list moves out unchanged into `SuiteSidebarList`. | `Sources/SuiteUI/SuiteWindow.swift`, `Sources/SuiteUI/SuiteSidebarList.swift` (new), `Sources/SuiteUI/SuiteWindowSizer.swift` (new), `Tests/SuiteUITests/SuiteWindowSizeTests.swift` (new), `Tests/AppSnapshotTests/SuiteWindowSlotSnapshots.swift` (new) | – | ~340 lines, 5 files |
| EW-2 | – | `EditorDetail` and `EditorDetailLayout`: the canvas, the floating palette clear of the rulers, the status line, `suite.viewport` and `suite.status`, and the fit that keeps a fitted artboard clear of the palette. `CanvasViewport`'s own ⌘0 uses the same fit. | `Sources/SuiteUI/EditorDetail.swift` (new), `Sources/SuiteUI/CanvasViewport.swift` (its ⌘0 only), `Tests/SuiteUITests/EditorDetailLayoutTests.swift` (new), `Tests/AppSnapshotTests/SuiteEditorDetailSnapshots.swift` (new) | – | ~320, 4 |
| EW-3 | – | `SidebarActionRow`: icon-only `ToolbarAction`s in a row. A disabled one is dimmed and says why, and each carries its `identifier` and `.suiteControl`. It is what replaces the `EditorBarItem(…, showsTitle: false)` rows in Design's and Photo's lists. | `Sources/SuiteUI/SidebarActionRow.swift` (new), `Tests/AppSnapshotTests/SuiteSidebarActionRowSnapshots.swift` (new) | – | ~140, 2 |
| EW-4 | – | The journeys' shared steps (geometry against the display's visible frame, see above): `expectEditorWindow()`, `shot(_:element:audit:)` (one element's picture, and skipping the audit for shots of other apps), and `expectShellGeometry()` built on the Linux-tested `ShellGeometry` | `UITests/Journey.swift`, `UITests/Journey+Geometry.swift` (new), `Tests/AppAuditTests/ShellGeometry.swift` (new), `Tests/AppAuditTests/ShellGeometryTests.swift` (new) | – | ~320, 4 |
| EW-7 | – | `AppSwitcher`, `AppSwitcherItem`, `AppSwitcherState` with its placeholder, the `suiteSwitcher` environment value and the four switcher tokens | `Sources/SuiteUI/AppSwitcher.swift` (new), `Sources/SuiteUI/Tokens.swift`, `Tests/SuiteUITests/AppSwitcherTests.swift` (new), `Tests/AppSnapshotTests/SuiteAppSwitcherSnapshots.swift` (new) | – | ~300, 4 |
| EW-8 | – | `SuiteWindow` shows the switcher in a centered toolbar slot: the environment's state, or the placeholder | `Sources/SuiteUI/SuiteWindow.swift` | EW-1, EW-7 | ~40, 1 |
| EW-5 | – | The `editor-window` gallery page and its journey (steps 1 to 6) | `Sources/SuiteUI/Gallery/GalleryEditorWindow.swift` (new), `Sources/SuiteUI/SuiteGallery.swift` (one line: the new area in `areas`), `UITests/SuiteJourneyTests+EditorWindow.swift` (new) | EW-2, EW-3, EW-4, EW-8; its geometric steps on #933 (skipped until then) | ~330, 3 |
| EW-5b | – | Only if EW-5 merged with the #933 skip: the skip goes and the geometric steps run | `UITests/SuiteJourneyTests+EditorWindow.swift` | EW-5, #933's fix merged | ~10, 1 |
| EW-6 | – | The parity journey (step 7): Flare, Design, Photo and Halo side by side, with their palettes and switchers | `UITests/SuiteJourneyTests+Parity.swift` (new) | EW-4, EW-8 | ~140, 1 |

## Build waves

- Wave 1: EW-1, EW-2, EW-3, EW-4, EW-7. Independent in this wave: all five.
- Wave 2: EW-8. Independent in this wave: EW-8 alone.
- Wave 3: EW-5, EW-6. Independent in this wave: both.
- Wave 4: EW-5b (only if EW-5 merged with the #933 skip). Independent in
  this wave: EW-5b alone.

Longest chain: EW-1 → EW-8 → EW-5 → EW-5b (4).
Chain of 4: EW-8 edits `SuiteWindow.swift` after EW-1 (kept apart because
EW-1 is already about 340 lines), EW-5's page needs the switcher EW-8 puts
in the window, and EW-5b is not build work but the wait on #933: a
ten-line removal of a skip that can't be folded into EW-5 without holding
wave 3 on someone else's fix. Without EW-5b the chain is 3.

**Note on EW-8 and the three apps already on `SuiteWindow`.** The switcher
lands in Flare's, Halo's and Library's toolbars too, with no edit in their
lines: SuiteUI draws the placeholder from the process name. Their journeys
see six new disabled buttons, and each one says why, so the `disabled-dim`
and `identifier` checks have nothing new to count. The EW-8 PR body names
the dev run that shows their audit counts unchanged. If a count rises
(for example Flare's toolbar overflowing at its 1000 pt default width), the
fix belongs in SuiteUI (the switcher's spacing steps), never in a raised
baseline.

**Note on `SuiteWindowSizer`.** Halo already has `HaloWindowSizer`
(`-HaloWindowSize`, `Sources/HaloApp/HaloWindowSizer.swift`), and
photo-seams S-12 adds `-PhotoWindowWidth`. The SuiteUI sizer is written
fresh around `NSWindow.setFrame(_:display:)`, constrained to the screen's
`visibleFrame`, and doesn't copy Halo's file, which would trip the jscpd
gate on `Sources/`. Once EW-1 merges, the lead files a `line:halo` issue to
retire Halo's own flag in favor of `-SuiteWindowSize`. Photo shell-parity
retires `-PhotoWindowWidth` (PS-4).

**Note on EW-1.** Making `SuiteWindow` generic over its sidebar changes its
type. Nothing on `dev` names `SuiteWindow<…>` explicitly (checked
2026-10-15), and the three existing inits keep their parameters in a
constrained extension, so Flare, Halo and Library build unchanged. The
gallery's `window` page uses the internal `galleryPage:` init, which moves
into the same extension. The window launch and minimum goldens must not
move: they prove that.

**Note on EW-6.** Before the app features land, Design and Photo still show
`EditorShell` in these shots. That is on purpose: the sheet then shows the
before and after across the waves.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| EW-1 | `SuiteWindowSizeTests` (macOS unit): `["-SuiteWindowSize", "1024x768"]` gives 1024 × 768; `"1024"`, `"x768"`, `"0x0"` and a missing value give nil; the flag in the middle of other arguments is found. `SuiteWindowSlotSnapshots` records `suiteui-window-slot-light.png` and `-dark.png` (a custom two-section list, the subtitle, a 304 pt inspector) for review; `snapshot()` only writes PNGs, so the PNGs prove nothing by themselves. What can fail: Flare's, Halo's and Library's journeys on the dev run (their `suite.sidebar` and `suite.inspector` lookups and #963's frames-inside-the-window check), and EW-5, which finds the custom list's own identifier inside `suite.sidebar`. | the parse accepts a bad value, the custom list loses `suite.sidebar`, or an existing SuiteWindow journey goes red |
| EW-2 | `EditorDetailLayoutTests` (macOS unit) across the detail sizes the 1024 × 768 window gives with and without the inspector, the window minimum, and artboards 1600 × 1000, 1000 × 1600, 1 × 1 and 20000 × 20000. The palette frame starts at least `ruler + l` from the leading edge and `ruler` below the top. Wherever the unclamped fit is at or above the smallest zoom stop (0.05), the centered artboard at `fitScale`, grown by `anchorHit / 2` on every side, stays at least `xs` clear of the palette frame. For 20000 × 20000, where it isn't, the test asserts only the clamp (exactly 0.05). The scale is never 0, NaN or infinite. With `\.canvasFitScale` set, `CanvasViewport`'s ⌘0 asks for the host's zoom; without it, ⌘0 is unchanged. `SuiteEditorDetailSnapshots` records light and dark for review. | the palette sits on a ruler, a fitted page's handles reach under the palette, or a degenerate size divides by zero |
| EW-3 | `SuiteSidebarActionRowSnapshots`. The disabled action's symbol ink is fainter than the enabled one's, measured by the file's own copy of `SuiteEditorBarDimmingTests`' private ink helper (ER-1 deletes that file). Every button's accessibility label is its title (the journeys click "Delete Page", "New Layer", "Rename Layer…" and "Delete Layer" by title), and its identifier is its `ToolbarAction.identifier`. | a disabled action looks enabled, loses its reason, or can't be found by its title |
| EW-4 | `ShellGeometryTests` (Linux). A fitting layout gives no violations. A region 1 pt outside the window, two regions overlapping by 2 pt, a region under its minimum, and a palette over a ruler or over a grown artboard each give exactly one violation that names both regions. Overlap of 1 pt or less (hairlines) is allowed. | any rule passes a broken layout or fails a fitting one |
| EW-7 | `AppSwitcherTests` (macOS unit): the placeholder has six items in the order Home, Flare, Design, Photo, Library, Halo with shortcuts ⌃⌘0 to ⌃⌘5, and every one is disabled with "Not connected yet (switching)."; `placeholder(processName: "DesignApp")` makes `design` current; `"LibraryApp"` makes `library` current; `"xctest"` makes none current; `help` reads "Design (⌃⌘2)" and, when unavailable, adds the reason; the six identifiers are unique. `SuiteAppSwitcherSnapshots` records light and dark goldens of the row with Design current, and a pixel check that the capsule is drawn only behind the current item. | an item is missing, enabled with nothing behind it, silent about why, or the capsule draws behind more than one item |
| EW-8 | Flare's, Halo's and Library's journeys stay green on the dev macOS run, their audit counts unchanged, and each launch shot shows the row centered in the toolbar | the slot pushes a toolbar item into the overflow, or an app's audit count rises |
| EW-5b | The same journey on the first dev run after #933's fix, with no skip: steps 3 and 5 and the toolbar-fit assertion pass | `SuiteWindow` still runs past the window, or a toolbar item overflows |
| EW-5 | The `editor-window` journey, steps 1 to 6, green on the dev macOS run (steps 3 and 5 may report `XCTSkip("waits on #933")` while #933 is open, and nothing else may skip). Two document actions and six trailing actions plus the switcher are all hittable at the display size. One toolbar button is found by its identifier (`suite.gallery.bar.undo`), since Photo's journeys rely on `photo.bar.undo` that way. The page's palette is built from identified `ToolbarAction`s, so the `suiteui` identifier count stays 0, and the `suiteui` audit stays at 0 for every key. | a slot is missing, a frame breaks a rule, or the page adds an audit count |
| EW-6 | The parity journey shoots 4 windows, 3 palettes and the switchers on the dev macOS run. The window of every app on `SuiteWindow` lies inside the display's visible frame. The `suiteui` audit tally is unchanged. | an app fails to launch, a `SuiteWindow` app ignores the size, or a palette shot is missing |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Geometric: every frame inside a 1024 × 768 window with the inspector shown, no overlap, minimum sizes | `suite.sidebar`, `suite.viewport`, `suite.status`, `suite.inspector` and the toolbar inside the window; no two of the four columns overlapping by more than 1 pt; the viewport at least `contentMinimum`, the inspector at its given width, every tool button at least `toolButton`; every toolbar item hittable (none pushed into the overflow menu) | EW-4 `ShellGeometry` + EW-5 step 3; depends on #933's fix (EW-5b) |
| The palette never covers a ruler or the selection handles | the palette frame clear of the top and leading `ruler` bands; at fit, clear of the artboard grown by `anchorHit / 2` | EW-2 unit, EW-5 step 3 |
| Light and dark | goldens in both appearances for each new view | EW-1, EW-2, EW-3 snapshots; EW-5 step 5 |
| No regression for the three apps already on `SuiteWindow` | the Flare, Halo and Library goldens and journeys unchanged | EW-1; the dev macOS run |
| Audit at or under baseline | `suiteui` stays 0 on every key; no other app's count moves | EW-5, EW-6 |
| No dead controls | the disabled toolbar action and the disabled row action each say why | EW-3, EW-5 |
| The switcher | centered in the toolbar (its midpoint within 1 pt of the window's); no item overflows at 1024 pt; every item 22 to 24 pt in glyph, one key-view stop, its tooltip naming the app and shortcut | EW-5 step 6, `ShellGeometry` |
| Contact sheet | the parity shots side by side under `suiteui`; the switcher in light and dark | EW-5, EW-6 |

## Done check

- **Journeys green.** The dev macOS run triggered by the `feature-done` PR
  (EW-6 or EW-5b, whichever merges last) is green, with no skipped step. That covers the two new SuiteUI journeys and every existing
  journey, so Flare, Halo and Library are untouched.
- **Audit zero new.** No count goes over `UITests/audit-baseline.json` for
  any app, and `suiteui` stays at 0.
- **Contact sheet.** Comment `Belt-Contact-Sheet: <run link>` on the
  feature issue, with the `editor-window` shots (light and dark), the
  `switcher` and `switcher-dark` crops, and the `parity-*` shots side by
  side.
