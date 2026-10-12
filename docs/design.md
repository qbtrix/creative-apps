# Design rules

How every app in the suite looks and behaves. These are Apple's Human Interface
Guidelines for macOS 26 (the Liquid Glass design) in our own words, plus the
suite's own taste. When an API name or size matters, check the current HIG
(https://developer.apple.com/design/human-interface-guidelines/); it changes
every June.

## The suite's taste

- **Only the outer edge is glass.** The window chrome (toolbar, sidebar,
  inspector) is system Liquid Glass, and a few floating controls over the
  canvas (a tool palette, a transport bar) may be glass. Everything inside,
  the canvas, lists, cards, panels of settings, stays flat.
- **Quiet chrome, loud content.** The artwork is the most colorful thing on
  screen. Chrome is monochrome; color marks state (the selected tool, the one
  primary action).
- **Five apps, one family.** Same window shell, same spacing, same type, same
  tool palette. SuiteUI holds all of it; an app that needs something different
  asks for it there (`needs-ui`).

## Component order

Every view is built from, in this order:

1. **Apple's own SwiftUI and system components and design resources.** Native
   controls (`Button`, `Toggle`, `Slider`, `Stepper`, `Picker`, `ColorPicker`,
   `List`, `Table`, `OutlineGroup`, `Form`, `.inspector`,
   `NavigationSplitView`, toolbar items, `Menu`, `.searchable`), SF Symbols,
   system fonts and text styles, semantic system colors, system materials and
   glass.
2. **Then SuiteUI** components and tokens.
3. **Never a hand-rolled look-alike** of either.

Apple's design resources are the source of truth: SF Symbols for icons, the
macOS 26 Human Interface Guidelines for behavior and layout. This file only
restates them for the suite.

| Need | Use |
|---|---|
| Window with sidebar, content, inspector | `SuiteWindow` (a `NavigationSplitView` with `.inspector`) |
| Selection properties | `.inspector`, through `SuiteWindow`'s inspector slot |
| List of items, rows with columns, a tree | `List`, `Table`, `OutlineGroup` (sidebar rows: `SidebarItem`) |
| Settings or a group of options | `Form` (app settings in a `Settings` scene) |
| On/off | `Toggle` |
| A value in a range | `Slider`; exact numbers: `TextField` plus `Stepper` |
| One of a few choices | `Picker` (segmented, menu or radio style) |
| A color | `ColorPicker` |
| Commands | `Menu`, menu bar commands, toolbar items (`ToolbarAction`) |
| Search and filter | `.searchable` |
| Timeline scrubber | `Slider`, then SuiteUI's timeline once it exists |
| Tool palette over a canvas | `ToolbarGroup` |
| Floating readout or transport bar | `GlassPanel` |
| Card in the content layer | `SurfaceCard` |
| Empty pane | `EmptyStateView` (`ContentUnavailableView`) |
| Icon | SF Symbols by name (`systemImage:`) |
| Color, type, spacing, radius, size | `SuiteColor`, `SuiteFont`, `SuiteSpacing`, `SuiteRadius`, `SuiteSize` |

Gate: the design lint in `scripts/ci` fails on raw colors, custom fonts,
literal radii, paddings and frame sizes, hand-made blur or materials, and a
`struct` in an app named like a system control (`...Button`, `...Slider`,
`...Toggle`, `...Picker`, `...Stepper`, `...Sidebar`). Raw values live only in
SuiteUI's `Tokens.swift`; glass only in its `Glass.swift`.

## Layers: content vs. control

For every screen, name what is content and what is control before you build.

- **Content** (the document, canvas, artboard, photo grid, timeline tracks,
  cards, the app background): no glass. Use flat fills and, when you need
  structure, the standard materials (blur, vibrancy) through a SuiteUI
  component; apps never apply a material themselves.
- **Control** (toolbars, sidebars, inspectors, floating palettes, popovers,
  sheets, menus): system components, which bring their own glass.
- **No glass on glass.** Never put a glass view inside another glass view or
  over system glass. Group related custom glass controls into one glass shape
  (`ToolbarGroup` puts its whole group in one capsule), or into one
  `GlassEffectContainer` when they must stay separate shapes.
- **Use custom glass sparingly.** Only the few most important floating
  controls. Regular glass for anything with text; the clear variant only over
  photos or video, with a dark dim behind it if the media is bright.
- **Let content run under the chrome.** Don't give toolbars or sidebars an
  opaque or tinted background; content scrolls beneath them.
- **Use the system APIs**: `.glassEffect`, `GlassEffectContainer`,
  `.buttonStyle(.glass)` / `.glassProminent`, the standard materials. Never a
  hand-made blur.

## Window structure

- One `WindowGroup` (or `DocumentGroup` once files open and save) per app,
  showing `SuiteWindow`: a `NavigationSplitView` with the sidebar on the
  leading edge, the content in the middle and an inspector on the trailing
  edge.
- **Title** names the open document, not the app. Show the app name only when
  nothing is open.
- **Sidebar**: top-level places or the document's structure (scenes, pages,
  layers, collections, compositions). At most two levels; SF Symbol per row;
  row height follows the system setting. Nothing critical at its bottom.
- **Inspector**: properties of the current selection only. Simple controls
  (fields, sliders, steppers, pop-ups, color wells), no deep navigation. The
  user can hide it from the toolbar and with Option-Command-I. With nothing
  selected it says so ("No Selection").
- Windows resize freely; set sensible minimums. Nothing critical along the
  bottom edge of a window, which is often off-screen.
- Settings go in a `Settings` scene (Command-comma), with few options and good
  defaults. Task options belong in the inspector, not in Settings.

## Canvas apps (Flare, Design, Photo, Halo)

| Region | Layer | Treatment |
|---|---|---|
| Canvas surround and artboard | content | Flat. Neutral surround so artwork color reads true; the artboard centered and scaled to fit (`CanvasSurface`). |
| Tool palette | control | One compact glass group of SF Symbol buttons on the canvas edge (`ToolbarGroup`). The active tool uses the filled symbol and the accent color. Each tool has a tooltip and a single-key shortcut when the canvas has focus. |
| Inspector | control | Trailing pane, selection properties only. |
| Timeline | control frame, content tracks | The bar and transport controls are controls; keyframes and tracks are content with no glass. |
| Toolbar | control | Document title, the few most-used commands, the inspector toggle. One prominent action at most (Export). |

- No modal dialog for an adjustment that needs a live preview; use the
  inspector or a panel.
- Precision input: arrow keys nudge, Shift-arrow nudges more, Shift constrains,
  Option-drag duplicates, Space-drag pans.
- Every canvas edit is undoable with a named action ("Undo Move Layer").
  Scrubbing and playback are not undo steps.
- Full screen keeps the essential tools reachable; hiding chrome for focus is
  fine if hovering brings it back.

## Commands

- **Every command is in the menu bar.** People learn a Mac app by its menus,
  and they can hide the toolbar. Toolbar buttons and context menus are extra
  routes, never the only one.
- Standard menus in the standard order: App, File, Edit, View, app menus
  (Object, Animate, Image, ...), Window, Help. Disable unavailable items rather
  than hiding them. Toggle items say what they will do ("Hide Inspector").
- Keep the standard shortcuts on their standard commands (New, Open, Save,
  Undo, Redo, Copy, Paste, Select All, Find, Settings, Close, Quit). Add custom
  shortcuts only for the most frequent app commands.
- Export lives at File > Export, opening a sheet on the document window.

## Color, type, spacing

- **Semantic colors only** (`SuiteColor`, which wraps the system's label,
  separator, window and control colors). They adapt to Light, Dark and Increase
  Contrast. Never hard-code a hex value for a system role. Document content
  (an artboard, a swatch) is the exception.
- Never carry meaning with color alone; pair it with a symbol, a shape or a
  label. Text contrast at least 4.5:1 (3:1 for large or bold text).
- **System text styles** (`SuiteFont`): macOS body is 13 pt; don't go under
  10 pt. Build hierarchy with weight and color, not many sizes. No light or
  thin weights at small sizes. Monospaced digits for timecode and counters.
- **Spacing on the 4-point grid** (`SuiteSpacing`). Corners nest concentric:
  an inner shape uses the next smaller radius (`SuiteRadius`). Fixed sizes
  (window minimums, column widths, palette buttons) come from `SuiteSize`.
- Follow the system's Light/Dark setting; no in-app appearance switch. A
  fixed dark canvas surround is allowed for a media app if chosen on purpose,
  but standard controls still follow the system.

## Symbols and controls

- SF Symbols for every standard action, with the standard symbol (plus for
  add, trash for delete, square-and-arrow-up for share). Outline in toolbars
  and lists, filled for the selected state.
- Every icon-only control has a tooltip (`.help`) and an accessibility label.
- Hit targets at least 28x28 points (20x20 minimum).
- Buttons say what they do with a verb ("Export", "New Animation"). Title case
  for menu items and buttons. An ellipsis when more input follows ("Export…").

## Empty states and messages

- An empty pane says what goes there and how to get started, and offers the
  button that does it as the one prominent action (`EmptyStateView`).
- Errors appear near the problem, say how to fix it, and don't blame anyone.
  Alerts only for destructive or critical cases; never at launch.

## Motion and accessibility

- Every animation has a job (feedback, orientation, status), is short, and
  never blocks input. Under Reduce Motion, fade instead of slide.
- Check each screen with Increase Contrast and Reduce Transparency on; glass
  changes under both.
- Everything works from the keyboard (Full Keyboard Access, a sensible focus
  order, Escape and Command-period cancel).

## Review checklist

Walk this against the snapshots (Light and Dark) before you open a UI PR, fix
what fails, and walk it again.

```
[ ] Content vs control named; no glass on content; no glass on glass
[ ] Content runs under the chrome; no custom bar backgrounds
[ ] System components and SuiteUI used where one exists
[ ] At most one prominent action per view; never a destructive one
[ ] SuiteColor / SuiteFont / SuiteSpacing only; Light and Dark both right
[ ] Every icon-only control has a tooltip and an accessibility label
[ ] Every new command is (or has an issue to be) in the menu bar
[ ] Edits are undoable with named actions
[ ] Empty states say what to do next
```
