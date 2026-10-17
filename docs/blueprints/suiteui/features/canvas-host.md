# Feature packet: canvas-host

**Feature:** an AppKit canvas surface every app draws its document on: an
`NSView` wrapped for SwiftUI with a `CALayer` tile path (CPU) and a
`CAMetalLayer` path (GPU), which takes pointer, scroll, pinch and key input,
hit-tests marks and draws a live drag on an overlay layer without a SwiftUI
body per sample; plus the suite's **View > Rendering** submenu (Automatic,
GPU (Metal), CPU, a checkmark on the current one) as SuiteUI's
`RenderingCommands`, and the one suite-wide preference every app process reads
live and keeps across relaunch. For the beta, Automatic draws on CPU. The
Settings > Rendering pane is not in the beta (captain, 2026-10-17; see Not in
this packet).
**Line:** `line:suiteui` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/canvas-host`

**Covers:** the dual-renderer design
(`paw-workspace/docs/design/drafts/2026-10-17-dual-renderer.md`, sections 2
and 3); Halo's per-sample viewer drag (#1458, the SuiteUI half); the
`LiveStroke` (Photo) and `HaloLiveEdit` (Halo) patterns, which this host
subsumes so no third app copies them (lead.md rule 16).

**Depends on:** canvas-marks (feature `depends`: it owns `CanvasViewport.swift`,
`CanvasSurface.swift`, `Ruler.swift` and `ZoomMath.swift` in wave 2, and
editor-in-window owns `CanvasViewport.swift` on the shell-parity track, so no
task here edits it: CH-9 adds `CanvasViewport+Host.swift`, an extension). No creative-core issue: the host draws
`CGImage` tiles and a `CAMetalLayer` it never fills itself; the engine side is
creative-core `render-backend` and `metal-backend`, adopted by each app's
Model later through a bump PR. Every token it reads is on `dev`
(`SuiteColor.canvasSurround`, `SuiteColor.artboard`, `SuiteSize.canvasInset`).

**Clean-room.** Behaviour only; no task reads or copies another product's code.

Blueprint sections: 2.2 (components), 4.4 (perf journeys), 5 (contracts),
7.1 (input-to-screen budgets), 7.5 (feel).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CH-a | Hosts and tests can code against `CanvasHosting` (content tiles, the input delegate, the hit map), the `RenderingPreference` type and its stubbed store, with fakes and the two gallery pages declared as placeholders. | CH-1, CH-2 | SJ0 | canvas-marks (feature `depends`) |
| CH-b | The gallery's `canvas-host` page shows a document on the AppKit host, drags draw on the overlay and reach the fake delegate with 0 window bodies per sample, and the `settings-rendering` page's Rendering menu (Automatic, GPU (Metal), CPU, a checkmark on the current one, the status line under them) switches the fake preference and shows the status note. | CH-3, CH-4, CH-5 | SJ27, SJ28, SP11 | CH-a (CH-3, CH-4) |
| CH-c | The hit map, the tile set (premultiplied sRGB tiles, dirty-tile replace) and the live preference store (one suite-wide key, kept across relaunch, observed across the suite's processes) behave as the fakes promised. | CH-6, CH-7, CH-8 | SJ27 | CH-a (CH-6, CH-7, CH-8) |
| CH-d | The pages run on the live store and tiles, `CanvasViewport` hosts its content on the host, the Metal layer path exists behind the preference, the menu's choice survives a relaunch, and the journeys pass on live. | CH-9, CH-10, CH-11 | SJ27, SJ28, SP11 | CH-b (CH-9, CH-10); CH-c (CH-9) |

CH-b is the UI slice (rule 18): it waits only on CH-a and runs beside CH-c.

## Journey steps

1. Open the gallery's `canvas-host` page (CH-3, SJ0): a 4096 x 2160 fake
   document with 20 tiles-worth of content sits on the host, centred.
2. Press and drag 120 samples across it (CH-3, CH-5, SJ27): a live line
   follows the pointer on the overlay layer; the page's log shows one
   `endDrag` and the window body count stays at 1 (the mouse-up commit).
3. Hover a mark: the hit map names it in the status line (CH-6, SJ27).
4. Open the `settings-rendering` page and its Rendering menu (CH-4, SJ28):
   Automatic, GPU (Metal) and CPU, the checkmark on Automatic, and a disabled
   status line under them ("Drawing on CPU"). Pick GPU (Metal), then CPU: the
   checkmark moves each time, the status line reads the backend name and the
   host's layer path switches live.
5. Pick Automatic on a fake that reports device loss (SJ28): the status line
   reads "Drawing on CPU: Metal stopped", no dialog.
6. SP11 `canvas-drag` (CH-5): sample-to-present p95 on the host, reported.
7. On live (CH-7, CH-9, SJ28): pick CPU, quit and relaunch the gallery: the
   checkmark is still on CPU, and a second suite process reads CPU too.

## Screens and states

`suiteui-canvas-host` (document on the host, light and dark),
`suiteui-canvas-host-drag` (overlay mid-drag), `suiteui-rendering-menu`
(the menu open, GPU (Metal) checked), `suiteui-rendering-menu-fallback` (the
status line with the note).

## Contract slice

```swift
// Sources/SuiteUI/Contracts/CanvasHosting.swift (CH-1)
public struct CanvasTile: Equatable, Sendable { public let rect: PixelRect; public let image: CGImage? }
public protocol CanvasContentProviding: Sendable {
    var documentSize: CGSize { get }
    func tiles(dirtyOnly: Bool) -> [CanvasTile]          // premultiplied sRGB
}
@MainActor public protocol CanvasInputDelegate: AnyObject {
    func drag(from: CGPoint, to: CGPoint, pressure: Double, modifiers: EventModifiers)
    func endDrag()
    func hover(_ point: CGPoint?)
    func key(_ press: KeyPress) -> KeyPress.Result
}
public struct CanvasHitMap: Equatable, Sendable { /* CH-6 fills: marks as rects and paths */ }
public enum RenderingChoice: String, CaseIterable, Codable, Sendable { case automatic, gpu, cpu }
public struct RenderingStatus: Equatable, Sendable { public var active: String; public var note: String? }
public protocol RenderingPreferenceReading: Sendable {
    var choice: RenderingChoice { get }
    var status: RenderingStatus { get }
    func set(_ choice: RenderingChoice)
    func observe(_ onChange: @Sendable @MainActor (RenderingChoice) -> Void) -> AnyCancellable
}
public struct FakeCanvasContent: CanvasContentProviding { … }   // 20 coloured tiles, 4096 x 2160
public final class FakeRenderingPreference: RenderingPreferenceReading { … }  // in memory, `loseDevice()`
```

`RenderingPreference` (CH-2) is the live type; its store methods return the
fake's values until CH-7 fills them (`NotBuilt` never shows here: a stubbed
`set` just records). Control ids: `suite.canvas` (the host, as today),
`suite.canvas.overlay`, `suite.settings.rendering.automatic|gpu|cpu` (the
three menu items, ids kept from the pane design), `suite.settings.rendering.status`
(the status line), `suite.menu.rendering` (the submenu).

## Pseudocode

- **Host input.** `CanvasHostView` keeps `live: [CGPoint]` and an overlay
  `CAShapeLayer`; each `mouseDragged` appends, redraws only the overlay, and
  calls `delegate.drag`; `mouseUp` calls `endDrag` and clears. No `@State`.
- **Tile path.** `CanvasTileSet.apply(tiles)` replaces only the layers whose
  `rect` is in the update (Photo's `TileCanvas` rule); a size change restarts.
- **Metal path.** `CanvasHostView+Metal` swaps the content layer for a
  `CAMetalLayer` with `colorspace` set and hands `nextDrawable()` to a
  `MetalPresenting` value (the core dispatcher's display op later; the fake
  clears to `SuiteColor.artboard`). `RenderingChoice.cpu` or a nil device
  keeps the tile path.
- **Preference.** One key `suite.rendering` in `UserDefaults(suiteName:)`
  for the suite's shared domain; `observe` uses KVO on the suite, falling
  back to `DistributedNotificationCenter` when a cross-process write does
  not fire KVO (CH-7 verifies on the Mac; `Unverified API:` line).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CH-1 | – | `CanvasHosting` contracts, `FakeCanvasContent`, `FakeRenderingPreference`, their fake tests | `Sources/SuiteUI/Contracts/CanvasHosting.swift`, `Tests/SuiteUITests/CanvasHostFakeTests.swift` | – | ~260, 2 |
| CH-2 | – | `RenderingPreference` type with stubbed store; control ids; the two gallery pages as placeholders calling `CanvasHostPage` and `RenderingPanePage` stubs; checks first: SJ27, SJ28 and SP11 skipped, the render budget disabled | `Sources/SuiteUI/RenderingPreference.swift`, `Tests/SuiteUITests/RenderingPreferenceTests.swift`, `Tests/mutations/SuiteUI.RenderingPreference.json`, `Sources/SuiteUI/Gallery/GalleryCanvasHost.swift`, `Sources/SuiteUI/Gallery/GalleryRenderingPane.swift`, `UITests/SuiteJourneyTests+CanvasHost.swift`, `Tests/AppSnapshotTests/RenderBudgetCanvasHostTests.swift` | CH-1 | ~320, 7 |
| CH-3 | #1458 (SuiteUI half) | `CanvasHostView` (NSView: tile layers, overlay layer, mouse, scroll, magnify, key, tracking area) and `CanvasHost` (representable); the `canvas-host` page on the fakes with its log | `Sources/SuiteUI/CanvasHostView.swift`, `Sources/SuiteUI/CanvasHost.swift`, `Sources/SuiteUI/Gallery/GalleryCanvasHost.swift`, `Tests/SuiteUITests/CanvasHostTests.swift`, `Tests/AppSnapshotTests/SuiteCanvasHostSnapshots.swift` | CH-2 | ~380, 5 |
| CH-4 | – | `RenderingMenu` (an inline `Picker` over the three choices, so the current one carries the checkmark, with a disabled status line under it) and `RenderingCommands` (a `Commands` value: `CommandGroup(after: .toolbar)` puts `Menu("Rendering") { RenderingMenu }` in the View menu); both on the fake preference; the `settings-rendering` page shows the same `RenderingMenu` as a pull-down | `Sources/SuiteUI/RenderingCommands.swift`, `Sources/SuiteUI/Gallery/GalleryRenderingPane.swift`, `Tests/SuiteUITests/RenderingCommandsTests.swift`, `Tests/AppSnapshotTests/SuiteRenderingMenuSnapshots.swift` | CH-2 | ~260, 4 |
| CH-5 | – | Enables SJ27, SJ28, SP11 and the render budget on the fakes; `canvas-drag` series; baselines | `UITests/SuiteJourneyTests+CanvasHost.swift`, `Tests/AppSnapshotTests/RenderBudgetCanvasHostTests.swift`, `Tests/AppSnapshotTests/Golden/canvas-host/` | CH-3, CH-4 | ~200, 3 + PNGs |
| CH-6 | – | `CanvasHitMap`: rects and paths with a hit slop, nearest mark, order (top first) | `Sources/SuiteUI/CanvasHitMap.swift`, `Tests/SuiteUITests/CanvasHitMapTests.swift`, `Tests/mutations/SuiteUI.CanvasHitMap.json` | CH-1 | ~220, 3 |
| CH-7 | – | The live store: shared suite defaults, `observe` across processes, device-loss note; fills CH-2's stubs, same signatures | `Sources/SuiteUI/RenderingPreference.swift`, `Tests/SuiteUITests/RenderingPreferenceLiveTests.swift`, `Tests/mutations/SuiteUI.RenderingPreference.json` | CH-2 | ~200, 3 |
| CH-8 | – | `CanvasTileSet`: tiles to premultiplied sRGB `CGImage`, dirty-only replace, restart on size change, `handedBytes` | `Sources/SuiteUI/CanvasTileSet.swift`, `Tests/SuiteUITests/CanvasTileSetTests.swift`, `Tests/mutations/SuiteUI.CanvasTileSet.json` | CH-1 | ~240, 3 |
| CH-9 | – | Integrate: pages on the live store, hit map and tile set; `CanvasViewport+Host.swift`: a `CanvasViewport` whose content is a `CanvasHost`, same ids | `Sources/SuiteUI/CanvasViewport+Host.swift`, `Sources/SuiteUI/Gallery/GalleryCanvasHost.swift`, `Sources/SuiteUI/Gallery/GalleryRenderingPane.swift`, `Tests/SuiteUITests/CanvasHostIntegrationTests.swift`, `Tests/AppSnapshotTests/SuiteCanvasHostSnapshots.swift` | CH-5, CH-6, CH-7, CH-8 | ~300, 5 |
| CH-10 | – | The `CAMetalLayer` path behind the preference with `MetalPresenting` and its clearing fake; nil device keeps tiles | `Sources/SuiteUI/CanvasHostView+Metal.swift`, `Tests/SuiteUITests/CanvasHostMetalTests.swift`, `Tests/mutations/SuiteUI.CanvasHostView+Metal.json` | CH-3 | ~220, 3 |
| CH-11 | – | Blueprint prose (2.2, 5, 7.1), status `built`, follow-ups filed; `feature-done` | `docs/blueprints/suiteui.md`, `docs/blueprints/suiteui/features/canvas-host.wave.json` | CH-9, CH-10 | ~120, 2 |

## Build waves

- Wave 1: CH-1. Independent in this wave: CH-1 alone.
- Wave 2: CH-2, CH-6, CH-8. Independent in this wave: all three.
- Wave 3: CH-3, CH-4, CH-7. Independent in this wave: all three.
- Wave 4: CH-5, CH-10. Independent in this wave: both.
- Wave 5: CH-9. Independent in this wave: CH-9 alone.
- Wave 6: CH-11 (`feature-done`, final). Independent in this wave: CH-11 alone.

Longest chain: CH-1 → CH-2 → CH-3 → CH-5 → CH-9 → CH-11 (6).
Chain of 6: CH-2 declares the pages and stubs CH-3 fills; CH-5 enables the
journeys on CH-3's and CH-4's screens; CH-9 swaps fakes for live on both;
CH-11 carries `feature-done`, whose run must show every journey green.

## Acceptance test per task

Checks land in the first code task of each slice (CH-1, CH-2, CH-6, CH-7,
CH-8) or with the code. A test ahead of its code is
`@Test(.disabled("waits on CH-n"))`, a journey `throw XCTSkip("waits on CH-n")`.

| id | test | fails when | mutations (plan: label → filter) |
|---|---|---|---|
| CH-1 | `CanvasHostFakeTests`: `FakeCanvasContent` gives 20 tiles covering 4096 x 2160 with no overlap; `FakeRenderingPreference.set` then `choice` round-trips, `loseDevice()` makes `status.note` non-nil under `.automatic` only | a fake stops proving the live gap | none: fakes only |
| CH-2 | `RenderingPreferenceTests`: `RenderingChoice` decodes "automatic", "gpu", "cpu" and rejects "metal"; the stubbed store returns the fake's values; SJ0 sees both pages | a stub returns a real value early, or a page is missing | `SuiteUI.RenderingPreference`: unknown raw value decodes as `.cpu` → `RenderingPreferenceTests`; `set` ignores a repeat choice → `RenderingPreferenceTests` |
| CH-3 | `CanvasHostTests`: 120 synthetic drags call `delegate.drag` 120 times and `endDrag` once, `bodyRuns` grows by at most 1; the overlay path has 120 points; `hitTest` returns the host for the artboard and nil outside; the element is `suite.canvas` | a sample reaches the window, or input is lost | `SuiteUI.CanvasHostView`: `endDrag` skipped when no move → `CanvasHostTests`; overlay keeps points after mouse-up → `CanvasHostTests` |
| CH-4 | `RenderingCommandsTests`: three items titled Automatic, GPU (Metal) and CPU in that order with their ids; exactly one is checked and it matches `choice`; picking an item calls `set` once with its case; the status line is the fake's `active` and shows the note only when set; snapshots of the page's open menu in four appearances | the checkmark is on the wrong item, an item is dead, or the note is always shown | `SuiteUI.RenderingCommands`: note shown with nil → `RenderingCommandsTests`; item sets the wrong case → `RenderingCommandsTests` |
| CH-5 | SJ27 and SJ28 pass on the fakes; `RenderBudgetCanvasHostTests.dragRunsNoBodies` passes; SP11 reports | a journey is skipped or the body count exceeds 1 | none: enables tests |
| CH-6 | `CanvasHitMapTests`: a point on a 1 pt path hits with 4 pt slop and misses at 5; overlapping marks return the topmost; an empty map returns nil | slop is off by one, or order flips | `SuiteUI.CanvasHitMap`: `<=` for `<` on the slop edge → `CanvasHitMapTests`; bottom mark wins → `CanvasHitMapTests` |
| CH-7 | `RenderingPreferenceLiveTests`: a write to the suite domain is read back by a second instance and by a new instance after the first is gone (relaunch); `observe` fires once per change and not on a repeat; device loss under `.automatic` sets the note and `.gpu` keeps "GPU" with the note | a change is lost or fires twice | `SuiteUI.RenderingPreference`: observer fires on a repeat → `RenderingPreferenceLiveTests`; device loss ignored under `.automatic` → `RenderingPreferenceLiveTests` |
| CH-8 | `CanvasTileSetTests`: an update of 3 dirty tiles replaces 3 layers; a size change restarts; `handedBytes` equals the tiles' byte count; images are premultiplied sRGB | a clean tile is redrawn or a stale tile survives a resize | `SuiteUI.CanvasTileSet`: restart skipped on resize → `CanvasTileSetTests`; `handedBytes` counts clean tiles → `CanvasTileSetTests` |
| CH-9 | `CanvasHostIntegrationTests`: the pages read the live store and hit map; every existing `CanvasViewport` test and snapshot passes unchanged; Photo's and Design's journeys stay green on the same run | a viewport behaviour changes or a fake survives | none: integrate (existing tests guard it) |
| CH-10 | `CanvasHostMetalTests`: `.gpu` with a device installs a `CAMetalLayer` with a non-nil `colorspace`; `.cpu` or nil device keeps the tile layers; switching back and forth keeps the overlay | the colour space is default, or the overlay is lost | `SuiteUI.CanvasHostView+Metal`: nil device still installs the layer → `CanvasHostMetalTests`; `colorspace` left nil → `CanvasHostMetalTests` |
| CH-11 | `scripts/waves check` passes; the blueprint names the host and View > Rendering | data out of step | none |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: canvas drag on the host | 120-sample drag ≤ 1 window body; sample-to-present p95 ≤ 8 ms (CPU tiles), reported | `RenderBudgetCanvasHostTests.dragRunsNoBodies`, SP11 `canvas-drag` |
| render: rendering switch | one switch ≤ 2 window bodies (the menu's host and the status bar); the host repaints once | `RenderBudgetCanvasHostTests.switchRepaintsOnce` |
| QB-S20 hit sizes | hit slop 4 pt on paths; menu items are system menu items | `CanvasHitMapTests` |
| No dead controls | every menu item acts, none disabled but the status line | SJ0, `RenderingCommandsTests` |
| Keyboard and VoiceOver parity | the menu works from the keyboard (menu bar navigation) and VoiceOver reads the checked item; the host keeps `suite.canvas` with the artboard's value | SJ28, `CanvasHostTests` |
| Reduce Motion | the overlay's fade on mouse-up is 0 s | `CanvasHostTests` |

## Done check

Per slice (contract rule 6): journeys green on a scoped run containing its
last PR, every app built, no open `finding`, mutations scored on the Mac
(timeline's Q10 applies to SuiteUI). CH-a: SJ0. CH-b: SJ27, SJ28, SP11 and
the render budget (feel gate, `Mac-Finish:`). CH-c: `CanvasHitMapTests`,
`RenderingPreferenceLiveTests`, `CanvasTileSetTests` on the Mac. CH-d: SJ27
and SJ28 on live (step 7's relaunch included), Photo and Design journeys
unchanged on the same run. Then `Belt-Contact-Sheet:` with
`suiteui-canvas-host-*` and `suiteui-rendering-menu-*`.

**Follow-ups filed** (stage 4, one issue each): `line:suite` "View > Rendering
in every suite process: `SuiteCommands` includes `RenderingCommands`, and the
launcher and every app's scene install `SuiteCommands`" (labels `beta` and
`p1`: without it the menu exists only on the gallery page); `line:photo` "`TileCanvas` on `CanvasHost`, `LiveStroke` as its
delegate"; `line:halo` "viewer on `CanvasHost`, `HaloLiveEdit` as its
delegate" (closes #1458); `line:design` "canvas marks on the overlay layer";
`line:flare` "stage on `CanvasHost`" (after `live-stage`); `line:library`
"loupe image on `CanvasHost`"; creative-core `render-backend` bump: "the
dispatcher's display op as `MetalPresenting`".

## Not in this packet

The engine (`RenderBackend`, Metal ops): creative-core. App canvases moving
onto the host: their lines. Per-document rendering overrides. The Settings >
Rendering pane (choice chips, status, a GPU "Test now" that renders the parity
set) and hosting it in the launcher's `SettingsView` (suite.md row 158): after
the beta, with the suite `settings` feature, on the same `RenderingPreference`.

## Open

- **Cross-process observe.** KVO on a shared `UserDefaults` suite may not
  fire for another process's write; CH-7 verifies on the Mac and falls back
  to `DistributedNotificationCenter`. `Unverified API:` in its PR body.
