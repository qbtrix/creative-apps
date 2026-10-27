# Feature packet: layer-styles

**Feature:** one layer style for the whole suite. A layer carries a
`LayerStyle`: drop shadow, inner shadow, outer glow, inner glow, stroke
(inside, outside, centre; solid or gradient), colour overlay, gradient overlay
and bevel and emboss, each with an on/off switch, its parameters, its own
blend mode and opacity, plus the layer's fill opacity. Styles are
non-destructive and live: the layer's pixels never change, the style is drawn
over and under them on every render. Every action is a catalog command
(`style.*`), so menus, the Layers panel, the `afterglow` CLI and MCP run one
path, and every edit is one kernel undo step (a drag folds into one). SuiteUI
gets one `LayerStylePanel`; the model, rules, presets, commands, the SVG
writer and the one mapping to creative-core's pixels live in SuiteImaging.
SuiteKernel also gets the clipping rule (which layer a clipped layer clips to),
the kernel half of Photo's clipping groups.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`; ahead of its wave-4 adopters, which wait on LS-a) · **Lead branch:** `lead/layer-styles`
**Beta:** captain, 2026-10-21 ("layer styles in beta, shared"). Labels `beta`
and `p1` when filed.

**Covers:** feature map S2 (effects stack and layer styles, the shared half),
S8's clipping rule; real job RJ-X51 (new). The adopts are packets on their own
lines: `photo/layer-styles`, `design/layer-styles` (RJ-D14),
`halo/layer-styles`, and `photo/psd-effects` (findings #3496, #3497).

**Depends on:** suite-imaging's **IM-a** (the SuiteImaging target; IM-1 also
links DesignModel and HaloModel, widened in this PR) and **IM-m** (the route,
for LS-9); gradient-fill's **GF-a** (`Fill`, `FillColor`,
`GradientRules`, `GradientEditor`) and **GF-m** (`GradientSVG`, for LS-7);
command-catalog (built: `CommandSpec`, `History`'s drag fold); brush-keys
**BK-u**, the last owner of `SuiteGallery.swift` before this packet.
**creative-core:** `layer-style-engine` (core packet in this sprint): **LE-a**
(the core types, through a `scripts/bump-core` PR) before LS-1, **LE-cpu**
before LS-8, **LE-metal** before LS-9. Each reaches the apps only through a
bump PR the supervisor merges. Where they stand on 2026-10-21: the dev pin
(2258b62) has none of them. LE-a's types (`LayerStyleStack`, `Codable`
`StrokePosition`; creative-core #780) ride bump PR #3825 (to 7966e5a, open),
which is all LS-1 needs; LS-1 starts once it merges. LE-cpu (`styled`,
creative-core #789 and #791) needs a later bump at or past bddb0961. LE-metal's
last task, LE-9b (Metal claims `style`), is creative-core #797, open.

**Hand-offs** (files other work owns; cross-line, so not in `waits`):
- **Layers panel actions.** A local crew is building the shared Layers-panel
  action bar and row context menu from the command catalog (branch
  `feat/layers-panel-actions`), with an `fx` button reserved for styles. The
  panel opens through one command, `style.panel` ("Layer Style…"), from three
  places: that `fx` button, the row context menu, and each app's Layer menu.
  The row menu also lists `style.copy`, `style.paste` and `style.clear`.
  LS-1 puts all four ids in the catalog with their availability, so the bar
  and the menu bind them by id. If that work has merged when LS-u starts,
  LS-3 adds the four bindings in its action-bar file and the lead adds that
  file to LS-3's owned list in the same PR; if not, that crew binds the ids,
  which are already in the catalog.
- **`suite-imaging.md` IM-1** links SuiteImaging into DesignModel and
  HaloModel too (one line each, in IM-1's `Package.swift` and `project.yml`
  edit). Design and Halo adopt this packet's model and need that link.

**Rule 20.** One style model. SuiteKernel stays Foundation and FlareCore only
(`KernelShapeTests`), and the model needs creative-core's `BlendMode` and
`StrokePosition`, so it lives in `Sources/SuiteImaging/Style/` beside the tone
module, for the same reason tone-controls moved there. It reuses the kernel's
`Fill` for gradient fills (no second gradient type) and `CommandSpec` for its
commands. Apps hold a `LayerStyle` on their layers and adapt to the
`LayerStyleTarget` protocol in a `<X>Style+Kernel.swift` file. The canonical concept line
(`Layer style: LayerStyle LayerEffect StyleEffect DropShadow InnerShadow
OuterGlow InnerGlow Bevel Emboss ColorOverlay GradientOverlay EffectStack`) and the
UI line (`LayerStylePanel StylePanel EffectsPanel`) land before this packet
in their own PR, so `scripts/check-dup-logic` and `check-dup-views` fail an
app file named for either. The clipping rule is a layer-tree concept (rule 20
lists the layer tree), so it goes in `Sources/SuiteKernel/Layers/`.

**Render path.** No app-local renderer. `StyleProgram` is the one mapping
from a `LayerStyle` to creative-core's `LayerStyleStack`. The CPU path
(export, thumbnails, headless, the CLI) calls `PixelBuffer.styled`. The live
path sends the core `.style` op through SuiteImaging's route, so a style
slider step is one GPU pass over a resident layer. `StyleProgramTests.cpuEqualsGpu`
holds the two within the core's parity tolerance. A style only reads the
layer's alpha and colour, so moving a slider never touches the layer's
pixels.

**C4:** new component parts `suite-imaging/imaging-style.json`
(`Sources/SuiteImaging/Style/`, LS-1) and
`suite-kernel/kernel-clip.json` (LS-10). `LayerStylePanel.swift` and
`LayerStyleRows.swift` are new files in `Sources/SuiteUI/`, covered by
`suiteui-sources`.

**Clean-room.** Alpha-based shadows, glows and strokes, height from a
distance field with Lambert and Blinn-Phong lighting, and the SVG filter
primitives (`feDropShadow`, `feMorphology`, `feDiffuseLighting`,
`feSpecularLighting`, `feBlend`; W3C Filter Effects Level 1) are published
techniques and specs. Defaults and presets are our own values. No task reads
another product's code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets); suite.md 1.5
(commands), 2 (shared tiers).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| LS-a | SuiteImaging's `Style/` module declares the model, rules, presets, intents, the `style.*` command specs with ids and availability, the SVG writer and the program as stubs, the gallery has a `layer-style` page, and every check is written, disabled. | LS-1, LS-2 | SJ0, MJ-LS | suite-imaging:IM-a; gradient-fill:GF-a; brush-keys:BK-u (LS-2); core LE-a through bump #3825 (cross-line) |
| LS-u | On the gallery page the panel lists the eight styles with their switches, shows the selected style's rows (colour, blend, opacity, angle, distance, size, position, gradient, bevel), applies a preset, and is reachable from the Layers panel's `fx` button and row menu where that work has landed, within the render budget. | LS-3, LS-4 | LJ1 | LS-a |
| LS-m | The rules clamp and default every parameter and keep one effect per kind, every `style.*` command records one undo step (a drag one), copy and paste round-trip as JSON, the SVG writer emits a filter for each style it can express and a warning for the rest, and `StyleProgram` maps a style to the core stack and back. | LS-5, LS-6, LS-7, LS-8 | MJ-LS | LS-a; gradient-fill:GF-m (LS-7); core LE-cpu through a bump (LS-8, cross-line) |
| LS-gpu | The live route draws a styled layer on the GPU in one pass per step and matches the CPU within the core's parity tolerance, within 16 ms p95 for a 2,000 × 2,000 layer. | LS-9, LS-9b | MJ-LS-gpu | LS-m; suite-imaging:IM-m; core LE-metal through a bump (cross-line) |
| LS-clip | SuiteKernel finds a clipped layer's base (the nearest unclipped layer below it among its siblings), refuses a clip with no base, and `layer.clip` and `layer.unclip` record one step each. | LS-10, LS-11 | KJ-clip | LS-a |
| LS-z | The gallery runs its intents through `StyleCommands` on a live target with a `History`, the panel draws its preview through the route, and the feature is built. | LS-12, LS-13 | LJ1, MJ-LS | LS-u, LS-m, LS-gpu, LS-clip |

LS-u waits only on LS-a (rule 18); LS-m and LS-clip never wait on LS-u.
MJ-LS is `SuiteImagingTests` on Linux (`LayerStyleRulesTests`,
`StyleCommandsTests`, `LayerStyleSVGTests`, `StyleProgramTests`); MJ-LS-gpu is
`StyleRouteTests` on the macOS job; KJ-clip is `ClipRulesTests` and
`ClipCommandsTests` in `SuiteKernelTests` on Linux.

## Journey steps

1. Open the gallery index, click `layer-style` (LS-2, SJ0): the panel shows a
   rounded square on a light canvas with no style; the eight rows are off.
2. Turn on Drop Shadow (LS-3, `SuiteLayerStyleJourneyTests.testLayerStylePanelEditsAStyle`):
   the preview gains a shadow down and to the right; the log shows one
   `style.add {kind: dropShadow}`.
3. Drag Distance from 8 to 24: the log shows `style.set` samples under one
   drag token; the shadow moves out.
4. Choose Multiply in the blend menu and type 50 in Opacity; then pick the
   preset "Lifted": the drop shadow and an outer glow change at once in one
   `style.preset`.
5. Select Stroke, set it Outside, 4 px, then switch its fill to Gradient: the
   shared `GradientEditor` shows under the row.
6. Turn on Bevel & Emboss, scrub Angle and Altitude: the highlight moves round
   the edge. Every control works by keyboard (Tab through rows, Space toggles
   a style) and VoiceOver reads "Drop Shadow, on".
7. Where the Layers-panel actions have landed, the gallery's layers list shows
   the `fx` button; clicking it opens the panel (one `style.panel`), and the
   row's menu shows Layer Style…, Copy Layer Style, Paste Layer Style and
   Clear Layer Style (LS-3).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X51 | adds, closes with S2 | C | `Tests/RealJobs/photo/style-drop-shadow/style-drop-shadow.jobs.json` (written by photo/layer-styles PY-5, disabled until then): `style.add` drop shadow on the cut-out layer, 120 `style.set {distance}` under one drag token, `style.copy` then `style.paste` onto a second layer, `edit.undo` once, `file.export` PNG | `input/cutout.ora` (a 200 × 200 white disc on transparency over a grey layer) |

Trap: the 120 distance samples land as 120 undo steps; the shadow is cut off
at the layer's bounds (no padding); the angle is read as radians or with y
up. Assertion: after one undo the second layer has no style and the first's
distance is the last sample; in the PNG the shadow's darkest pixel sits at the
disc's edge plus (distance·cos θ, distance·sin θ) with y down, within 1 px,
and no row or column of the shadow ends at the layer's old edge. Mutations:
`SuiteImaging.StyleCommands.json` (drag token not passed → `.dragIsOneStep`),
`SuiteImaging.StyleProgram.json` (angle not converted to radians →
`.angleIsDegreesYDown`; reach ignored → `.shadowIsPadded`). The job adds to
S2 because the shared packet makes it pass; its check lives in Photo's
folder because a headless Photo is the CLI app that exports pixels on Linux
(RJ-X45's pattern).

## Screens and states

`suiteui-layer-style` (no style, light and dark), `-drop-shadow` (Drop Shadow
selected), `-stroke-gradient` (Stroke with the gradient editor), `-bevel`
(Bevel & Emboss), `-preset-menu` (presets open), `-help` (a refused command's
reason under the list, "Select a layer to style.").

## Contract slice

```swift
// Sources/SuiteImaging/Style/LayerStyle.swift (LS-1 types, LS-5 clamps). Linux-safe.
import CoreRaster; import SuiteKernel
/// The eight styles; the panel lists them in this order. Paint order is `StyleRules.paintOrder`.
public enum StyleKind: String, Codable, CaseIterable, Sendable {
    case dropShadow, innerShadow, outerGlow, innerGlow, stroke, colorOverlay, gradientOverlay, bevel
}
public struct StyleShadow: Hashable, Codable, Sendable { public var color: FillColor; public var angle, distance, spread, size: Double }
public struct StyleGlow: Hashable, Codable, Sendable { public var color: FillColor; public var spread, size: Double }
public struct StyleStroke: Hashable, Codable, Sendable { public var fill: Fill; public var size: Double; public var position: StrokePosition }
public struct StyleOverlay: Hashable, Codable, Sendable { public var fill: Fill }          // solid for colour, linear or radial for gradient
public enum BevelShape: String, Codable, CaseIterable, Sendable { case innerBevel, outerBevel, emboss, pillowEmboss }
public enum BevelTechnique: String, Codable, CaseIterable, Sendable { case smooth, chiselHard, chiselSoft }
public struct StyleBevel: Hashable, Codable, Sendable {
    public var shape: BevelShape, technique: BevelTechnique
    public var depth: Double, up: Bool, size: Double, soften: Double, angle: Double, altitude: Double
    public var highlight: FillColor, highlightBlend: BlendMode, highlightOpacity: Double
    public var shadow: FillColor, shadowBlend: BlendMode, shadowOpacity: Double
}
public enum StyleParameters: Hashable, Codable, Sendable {
    case shadow(StyleShadow), glow(StyleGlow), stroke(StyleStroke), overlay(StyleOverlay), bevel(StyleBevel)
}
public struct StyleEffect: Hashable, Codable, Sendable {
    public var kind: StyleKind; public var isEnabled: Bool
    public var blendMode: BlendMode; public var opacity: Double         // 0...1
    public var parameters: StyleParameters                              // its case matches `kind` (`StyleRules.check`)
}
/// A layer's style: at most one effect per kind, plus the fill opacity (the layer's own pixels; effects keep theirs).
public struct LayerStyle: Hashable, Codable, Sendable {
    public var effects: [StyleEffect]; public var fillOpacity: Double
    public static let none: LayerStyle
    public var isVisible: Bool { get }                                  // an enabled effect, or fill opacity under 1
    public func effect(_ kind: StyleKind) -> StyleEffect?
}
// Sources/SuiteImaging/Style/LayerStyleRules.swift (LS-1 stubs returning the input, LS-5 bodies)
public enum StyleRules {
    public static let noLayerHelp = "Select a layer to style."
    public static let paintOrder: [StyleKind]                           // under: dropShadow, outerGlow; over: gradientOverlay,
                                                                        // colorOverlay, innerGlow, innerShadow, bevel, stroke
    public static func defaults(_ kind: StyleKind) -> StyleEffect
    public static func clamped(_ style: LayerStyle) -> LayerStyle      // ranges in Pseudocode; non-finite values refused
    public static func check(_ style: LayerStyle) -> String?           // why a decoded style is malformed, nil when fine
    public static func adding(_ kind: StyleKind, to style: LayerStyle) -> LayerStyle
    public static func setting(_ patch: JSONValue, on kind: StyleKind, in style: LayerStyle) throws -> LayerStyle
    public static func reach(_ style: LayerStyle) -> Int               // px a renderer pads on each side
    public static let presets: [StylePreset]                           // Soft Shadow, Lifted, Outline, Neon, Embossed
    public static func json(_ style: LayerStyle) -> JSONValue          // what style.copy returns and style.paste takes
    public static func style(json: JSONValue) throws -> LayerStyle
}
public struct StylePreset: Hashable, Sendable { public var name: String; public var style: LayerStyle }
// Sources/SuiteImaging/Style/StyleCommands.swift (LS-1 specs with ids, schemas and availability, runs throwing
// `StyleRules.notBuilt`; LS-6 bodies)
public protocol LayerStyleTarget: Sendable {
    var styleSelection: LayerStyle? { get }       // the primary selected layer's style; nil when nothing stylable is selected
    var styleHelp: String? { get }                // why the edit commands can't run now
    var stylePanel: StyleKind? { get }            // the panel is open at this kind; nil when closed
    mutating func showStylePanel(_ kind: StyleKind?)
    /// Sets every selected stylable layer's style: one undo step named `name`; steps under one `drag` token fold.
    mutating func setStyle(_ style: LayerStyle, name: String, drag: String?) throws
}
public enum StyleIntent: Hashable, Sendable {
    case toggle(StyleKind, Bool), set(StyleKind, JSONValue, drag: String?), preset(String)
    case fillOpacity(Double, drag: String?), show(StyleKind?)
    public var command: (id: String, params: JSONValue) { get }
}
public enum StyleCommands { public static func specs<T: LayerStyleTarget>(_ target: T.Type) -> [CommandSpec<T>] }
// Sources/SuiteImaging/Style/LayerStyleSVG.swift (LS-1 stub returning ("", []), LS-7 body)
public enum LayerStyleSVG {
    /// A `<filter>` for `style` on a shape whose box is `box`, and the styles it wrote approximately or not at all.
    public static func filter(_ style: LayerStyle, id: String, box: Rect) -> (svg: String, warnings: [String])
}
// Sources/SuiteImaging/Style/StyleProgram.swift (LS-1 stubs, LS-8 bodies)
public enum StyleProgram {
    public static func stack(_ style: LayerStyle, scale: Double) -> LayerStyleStack      // core's value; px × scale
    public static func style(_ stack: LayerStyleStack) -> (LayerStyle, dropped: [String]) // PSD import's way in
    public static func render(_ style: LayerStyle, layer: PixelBuffer, scale: Double) throws -> (PixelBuffer, origin: (x: Int, y: Int))
}
// Sources/SuiteImaging/Route/StyleRoute.swift (LS-1 stub, LS-9 body). macOS, #if canImport(Metal).
public final class StyleRoute {
    public init(dispatcher: RenderDispatcher)
    /// The styled layer, padded by `StyleRules.reach`, as a resident surface: one `.style` op on the GPU.
    public func draw(_ style: LayerStyle, layer: RenderSurface, scale: Double) throws -> RenderSurface
}
// Sources/SuiteUI/LayerStylePanel.swift (LS-2 placeholder, LS-3 view)
public struct LayerStylePanel: View {
    public init(style: LayerStyle?, selected: StyleKind, help: String?, onIntent: @escaping (StyleIntent) -> Void)
}
/// The one place a style's JSON goes on and comes off the pasteboard (its own type), so no app writes its own.
public enum LayerStylePasteboard { public static func write(_ style: JSONValue); public static func read() -> JSONValue? }
// Sources/SuiteKernel/Layers/ClipRules.swift (LS-10). Linux-safe.
public enum ClipRules {
    public static let noBaseHelp = "There is no layer below to clip to."
    /// The id `id` clips to among `siblings` (back to front): the nearest layer below it that isn't clipped.
    public static func base<P>(of id: String, in siblings: [LayerNode<P>], isClipped: (P) -> Bool) -> String?
    public static func clipped<P>(onto baseID: String, in siblings: [LayerNode<P>], isClipped: (P) -> Bool) -> [String]
}
// Sources/SuiteKernel/Layers/ClipCommands.swift (LS-11)
public protocol ClipTarget: Sendable {
    var clipSelection: (id: String, isClipped: Bool, hasBase: Bool)? { get }
    mutating func setClipped(_ clipped: Bool, name: String) throws   // the selected layers; one undo step
}
public enum ClipCommands { public static func specs<T: ClipTarget>(_ target: T.Type) -> [CommandSpec<T>] }
```

Commands (ids go in each adopter's `Tests/command-ids/<app>.txt`):

| id | kind | title (undo step) | params | unavailable when |
|---|---|---|---|---|
| `style.read` | query | – | – → the style JSON | `styleHelp` |
| `style.panel` | view | Layer Style… | `{kind?}` (default: the first enabled, else dropShadow) | `styleHelp` |
| `style.add` | edit | Add Layer Style | `{kind}` | `styleHelp`; the kind already on |
| `style.remove` | edit | Remove Layer Style | `{kind}` | `styleHelp`; the kind absent |
| `style.enable` | edit | Turn Layer Style On or Off | `{kind, enabled}` | `styleHelp`; the kind absent |
| `style.set` | edit | Change Layer Style | `{kind, blend?, opacity?, <parameters>?, drag?}` (a patch) | `styleHelp`; the kind absent |
| `style.fill-opacity` | edit | Fill Opacity | `{opacity, drag?}` | `styleHelp` |
| `style.preset` | edit | Apply Style Preset | `{name}` | `styleHelp`; unknown name |
| `style.copy` | query | Copy Layer Style | – → the style JSON | `styleHelp`; no style ("This layer has no style to copy.") |
| `style.paste` | edit | Paste Layer Style | `{style}` | `styleHelp`; malformed style (`check`) |
| `style.clear` | edit | Clear Layer Style | – | `styleHelp`; no style |
| `layer.clip` | edit | Create Clipping Mask | – | nothing selected; `noBaseHelp` |
| `layer.unclip` | edit | Release Clipping Mask | – | the selection isn't clipped |

`style.copy` is a query and `style.paste` takes the JSON, so the CLI copies
and pastes with no clipboard state. In an app, the menu and the row menu put
the copy's JSON on the pasteboard through SuiteUI's `LayerStylePasteboard` and
read it back for paste; Paste is disabled when the pasteboard holds no style.

## Pseudocode

- **Ranges (clamped).** Opacity and fill opacity 0...1; angle wraps to
  [0, 360), 0 points right, 90 down; distance 0...1,000 px; spread 0...1;
  size 0...250 px; stroke size 1...250 px; bevel depth 0.01...10 (1 is 100%),
  size 0...250 px, soften 0...16 px, altitude 0...90. A non-finite value is
  refused (the command throws `malformed` with the field), never clamped.
- **Defaults** (`defaults`): drop shadow black, Multiply, 35%, 135°, 8 px,
  size 12; inner shadow black, Multiply, 50%, 135°, 4 px, size 6; outer glow
  white, Screen, 60%, size 12; inner glow white, Screen, 50%, size 8; stroke
  black 2 px outside, Normal, 100%; colour overlay red, Normal, 100%;
  gradient overlay black to white at 90°; bevel inner, smooth, depth 1, up,
  size 6, soften 0, 120°, altitude 30, highlight white Screen 75%, shadow
  black Multiply 75%.
- **One per kind.** `adding` replaces an existing effect of that kind with
  its defaults turned on; decoding keeps the first of a kind and `check`
  names the rest, so a pasted or imported style never holds two shadows.
- **Paint order.** Under the layer, bottom up: drop shadow, outer glow, then
  the layer's pixels times fill opacity; over it, clipped to its alpha:
  gradient overlay, colour overlay, inner glow, inner shadow, bevel; then the
  stroke (an outside stroke goes under the layer, inside and centre over it,
  as core's `stroked` already does). Each effect composites with its own
  blend mode and opacity.
- **reach.** max over enabled effects of: shadow `distance + size·(1 + spread)`;
  outer glow `size·(1 + spread)`; outside stroke `size`, centre `size/2`;
  outer bevel and emboss `size`; rounded up, so a caller pads before it
  styles and nothing is clipped at the layer's edge.
- **Commands.** Each spec reads `styleSelection`, applies one rule and calls
  `setStyle` once with its title; `drag` passes through, so the target's
  `History` folds a scrub into one step (gradient-fill's pattern).
  `style.panel` calls `showStylePanel` and records no step.
- **SVG.** One `<filter>` per styled shape, filter region grown by `reach`:
  drop shadow `feGaussianBlur` on `SourceAlpha` (σ = size/3), `feOffset`,
  `feFlood` + `feComposite in`, under via `feMerge`; inner shadow on the
  inverted alpha, clipped with `feComposite in SourceAlpha`; glows the same
  without the offset; strokes with `feMorphology` (dilate for outside, erode
  for inside; square corners, so the warning "stroke corners are square in
  SVG"); colour overlay `feFlood` in `SourceAlpha`; gradient overlay as an
  `feImage` of a rect filled by `GradientSVG.definition`; bevel with
  `feDiffuseLighting` and `feSpecularLighting` under an `feDistantLight`
  (azimuth = angle, elevation = altitude) on the blurred alpha; blend modes
  as `feBlend mode`. A mode SVG lacks (linear dodge, linear burn) writes as
  the nearest (`screen`, `multiply`) with a warning naming it. A disabled
  effect writes nothing.
- **Program.** `stack` converts sRGB straight `FillColor` to core's linear
  premultiplied `RGBA`, degrees to core's convention, px by `scale`, and a
  `Fill` to core's `RasterGradient` through `GradientRules` (one rule for the
  vector and the raster path). `style` is its inverse for PSD import, naming
  any entry it can't hold (a second instance, satin, pattern overlay).
  `render` pads by `reach × scale`, calls `PixelBuffer.styled`, and returns
  the new origin.
- **Clipping.** `base` walks down from `id`'s index past clipped siblings to
  the first unclipped one; none (the bottom layer, or only clipped layers
  below) gives nil. A group boundary stops the walk, so a clip never reaches
  out of its group. Hiding the base hides its clipped layers (the renderer's
  rule; the adopts test it).
- **Panel.** A two-column sheet: the left column lists the eight kinds with a
  checkbox each (Toggle) and a Fill Opacity row under them; the right shows
  the selected kind's rows: `InspectorColorWellRow`, a blend `Menu`,
  `StudioScrubRow`s with units (°, px, %), `ChoiceChips` for stroke position
  and bevel shape, and the shared `GradientEditor` for a gradient fill. A
  Presets menu and a Done button sit in the footer. Every control emits one
  intent; the panel never edits a document (rule 18's live copy shows it).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LS-1 | – | The `Style/` module as stubs: every type, `StyleRules`, `StylePreset`, `StyleIntent`, the eleven `style.*` specs with ids, schemas and availability, `LayerStyleSVG`, `StyleProgram`, `StyleRoute` (macOS); the C4 part; the four suites written, disabled by name | `Sources/SuiteImaging/Style/LayerStyle.swift`, `Sources/SuiteImaging/Style/LayerStyleRules.swift`, `Sources/SuiteImaging/Style/StyleCommands.swift`, `Sources/SuiteImaging/Style/LayerStyleSVG.swift`, `Sources/SuiteImaging/Style/StyleProgram.swift`, `Sources/SuiteImaging/Route/StyleRoute.swift`, `Tests/SuiteImagingTests/LayerStyleRulesTests.swift`, `Tests/SuiteImagingTests/StyleCommandsTests.swift`, `Tests/SuiteImagingTests/LayerStyleSVGTests.swift`, `Tests/SuiteImagingTests/StyleProgramTests.swift`, `docs/c4/parts/creative-apps/suite-imaging/imaging-style.json` | – | ~380, 11 |
| LS-2 | – | The placeholder `LayerStylePanel`, `LayerStyleRows` and `LayerStylePasteboard`, the gallery's `layer-style` page on a local style, the journey written and skipped (`XCTSkip("waits on LS-4")`) | `Sources/SuiteUI/LayerStylePanel.swift`, `Sources/SuiteUI/LayerStyleRows.swift`, `Sources/SuiteUI/Gallery/GalleryLayerStyle.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `UITests/SuiteJourneyTests+LayerStyle.swift` | LS-1 | ~220, 5 |
| LS-3 | – | The panel: the kind list with switches, each kind's rows, the presets menu, Fill Opacity, Done; identifiers `suite.style.*`; `LayerStylePasteboard`'s body; the `fx` and row-menu bindings where the Layers-panel actions have landed (hand-off) | `Sources/SuiteUI/LayerStylePanel.swift`, `Sources/SuiteUI/LayerStyleRows.swift`, `Tests/SuiteUITests/LayerStylePanelTests.swift` | LS-2 | ~380, 3 |
| LS-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteLayerStyleSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetLayerStyleTests.swift`, `UITests/SuiteJourneyTests+LayerStyle.swift` | LS-3 | ~220, 3 |
| LS-5 | – | `StyleRules` bodies: ranges, defaults, one per kind, paint order, `reach`, presets, the JSON codec; turns on `LayerStyleRulesTests` | `Sources/SuiteImaging/Style/LayerStyle.swift`, `Sources/SuiteImaging/Style/LayerStyleRules.swift`, `Tests/SuiteImagingTests/LayerStyleRulesTests.swift`, `Tests/mutations/SuiteImaging.LayerStyleRules.json` | LS-1 | ~340, 4 |
| LS-6 | – | `StyleCommands` bodies and `StyleIntent.command`; turns on `StyleCommandsTests` on a test target (one step per run, a drag one step, every why-not, copy and paste round-trip) | `Sources/SuiteImaging/Style/StyleCommands.swift`, `Tests/SuiteImagingTests/StyleCommandsTests.swift`, `Tests/mutations/SuiteImaging.StyleCommands.json` | LS-5 | ~320, 3 |
| LS-7 | – | `LayerStyleSVG.filter` body; turns on `LayerStyleSVGTests` | `Sources/SuiteImaging/Style/LayerStyleSVG.swift`, `Tests/SuiteImagingTests/LayerStyleSVGTests.swift`, `Tests/mutations/SuiteImaging.LayerStyleSVG.json` | LS-5, GF-m | ~300, 3 |
| LS-8 | – | `StyleProgram` bodies (`stack`, `style`, `render` on the CPU); turns on `StyleProgramTests` but `cpuEqualsGpu` | `Sources/SuiteImaging/Style/StyleProgram.swift`, `Tests/SuiteImagingTests/StyleProgramTests.swift`, `Tests/mutations/SuiteImaging.StyleProgram.json` | LS-5, core LE-cpu bump | ~300, 3 |
| LS-9 | – | `StyleRoute` body: the core `.style` op through the dispatcher on a resident surface; turns on `cpuEqualsGpu`; macOS tests | `Sources/SuiteImaging/Route/StyleRoute.swift`, `Tests/SuiteImagingTests/StyleRouteTests.swift`, `Tests/mutations/SuiteImaging.StyleRoute.json` | LS-8, IM-m, core LE-metal bump | ~250, 3 |
| LS-9b | – | `StyleRouteLatencyTests`: one style step on a resident 2,000 × 2,000 layer, release, p95 ≤ 16 ms (perf list line) | `Tests/AppSnapshotTests/StyleRouteLatencyTests.swift` | LS-9 | ~120, 1 |
| LS-10 | – | `ClipRules` with its tests; the C4 part | `Sources/SuiteKernel/Layers/ClipRules.swift`, `Tests/SuiteKernelTests/ClipRulesTests.swift`, `Tests/mutations/SuiteKernel.ClipRules.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-clip.json` | – | ~200, 4 |
| LS-11 | – | `ClipTarget` and `ClipCommands` (`layer.clip`, `layer.unclip`) with tests on a test target | `Sources/SuiteKernel/Layers/ClipCommands.swift`, `Tests/SuiteKernelTests/ClipCommandsTests.swift`, `Tests/mutations/SuiteKernel.ClipCommands.json` | LS-10 | ~180, 3 |
| LS-12 | – | The gallery page runs each intent through `StyleCommands` on a local target with a `History` and draws its preview through `StyleRoute`; the live test | `Sources/SuiteUI/Gallery/GalleryLayerStyle.swift`, `Tests/SuiteUITests/LayerStylePanelLiveTests.swift` | LS-4, LS-6, LS-9 | ~150, 2 |
| LS-13 | – | The C4 parts name the commands, the route and the adopters; deletes `LayerActionBar.effectsPending` and `effects(identifier:)` and `LayerPanelCommandsTests.effectsWaitForLayerStyles`, once Photo's PY-2 has moved its `fx` button onto `style.panel` (hand-off, #5327); `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-imaging/imaging-style.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-clip.json`, `docs/blueprints/suiteui/features/layer-styles.wave.json`, `Sources/SuiteUI/LayerActionBar.swift`, `Tests/SuiteUITests/LayerPanelCommandsTests.swift` | LS-12, LS-7, LS-9b, LS-11 | ~45, 5 |

LS-1 declares every type and spec so LS-5 to LS-8 each fill their own file.
LS-10 and LS-11 touch no style file and start with the packet.

## Build waves

- Wave 1: LS-1, LS-10. Independent in this wave: both.
- Wave 2: LS-2, LS-5, LS-11. Independent in this wave: all three.
- Wave 3: LS-3, LS-6, LS-7, LS-8. Independent in this wave: all four.
- Wave 4: LS-4, LS-9. Independent in this wave: both.
- Wave 5: LS-9b, LS-12. Independent in this wave: both.
- Wave 6: LS-13 (`feature-done`, final). Independent in this wave: LS-13 alone.

Longest chain: LS-1 → LS-2 → LS-3 → LS-4 → LS-12 → LS-13 (6). Chain of 6:
the page needs the module's types, the view fills the placeholder, the budget
and journey time the view, the live page swaps the log under the journey, and
LS-13 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| LS-1 | the four suites compile, disabled by name; `ImagingBoundaryTests` still passes (no Metal outside `StyleRoute`'s `#if`); `KernelShapeTests` unchanged | a signature an adopter calls is missing, or the module reaches past SuiteImaging's dependencies | – (stubs) |
| LS-2 | SJ0: the index lists `layer-style`; the page opens | the page is missing | – (UI) |
| LS-3 | `LayerStylePanelTests`: a switch emits one `.toggle`; a Distance scrub emits `.set` under one token; a preset emits one `.preset`; the gradient editor shows only for a gradient fill; every control has a `suite.style.*` id | an intent is wrong or doubled, or a control has no id | – (UI) |
| LS-4 | `SuiteLayerStyleSnapshots`; `RenderBudgetLayerStyleTests.distanceScrubInThreeBodies`; `testLayerStylePanelEditsAStyle` steps 1 to 7 | budget over, or a step fails | – (UI) |
| LS-5 | `LayerStyleRulesTests`: 400° wraps to 40; size 300 clamps to 250; NaN is refused; adding a second shadow replaces the first; decoding two strokes keeps one and `check` names the other; `reach` of a shadow (distance 8, size 12) is 20; paint order puts drop shadow first and stroke last; the JSON round-trips every preset | a range, the one-per-kind rule, reach or the order is wrong | `SuiteImaging.LayerStyleRules`: `>=` for `>` on the size cap → `.sizeCapInclusive`; spread left out of reach → `.reachCountsSpread`; second instance kept → `.onePerKind`; NaN clamped → `.nonFiniteRefused` |
| LS-6 | `StyleCommandsTests`: each edit records one step named its title; 120 `style.set` under one token undo in one; `style.add` of a present kind is unavailable with its reason; `style.copy` then `style.paste` on another layer gives an equal style; `style.panel` records no step; `StyleIntent.command` round-trips each case | a run records zero or two steps, a why-not is missing, or paste differs | `SuiteImaging.StyleCommands`: drag not passed to `setStyle` → `.dragIsOneStep`; `style.panel` recording a step → `.panelIsNotAnEdit`; paste skipping `check` → `.pasteRefusesMalformed` |
| LS-7 | `LayerStyleSVGTests`: a drop shadow writes `feGaussianBlur stdDeviation="4"` and `feOffset dx` and `dy` from 135° and 8 px with y down; a disabled effect writes nothing; linear dodge writes `screen` and one warning; the filter region grows by `reach`; a gradient overlay writes `GradientSVG`'s points | an effect is dropped silently, the offset sign flips, or the region clips | `SuiteImaging.LayerStyleSVG`: dy sign flipped → `.shadowGoesDown`; disabled effect written → `.disabledWritesNothing`; warning omitted for a substituted mode → `.substitutionWarns` |
| LS-8 | `StyleProgramTests`: sRGB 0.5 grey becomes linear 0.214 premultiplied; 135° and 8 px map to core (dx, dy) = (5.66, 5.66); a gradient overlay's points equal `GradientRules.rotated`'s; `style(stack(s))` equals `s` for every preset; `render` of a disc with a 12 px glow is padded by 12 and the origin moves by −12 | a colour space, the angle, the padding or the round trip is wrong | `SuiteImaging.StyleProgram`: colour passed unconverted → `.colourIsLinear`; angle not converted to radians → `.angleIsDegreesYDown`; reach ignored → `.shadowIsPadded` |
| LS-9 | `StyleRouteTests` (macOS): a step encodes one `.style` op and reads back nothing; the GPU picture equals `StyleProgram.render` within the core's `.style` tolerance; a disabled effect costs no pass | a step reads back, or the GPU drifts | `SuiteImaging.StyleRoute`: CPU forced on every step → `.stepStaysOnGPU`; padding dropped on the GPU path → `.gpuIsPadded` |
| LS-9b | `StyleRouteLatencyTests` (release, perf list) | p95 over 16 ms | – (budget) |
| LS-10 | `ClipRulesTests`: in [A, B(clipped), C(clipped)] C's base is A; B's base is A; A's base is nil; a clipped layer at the bottom has no base; a group boundary stops the walk; `clipped(onto: A)` is [B, C] | a base skips a layer, crosses a group, or the bottom layer clips | `SuiteKernel.ClipRules`: walk not stopping at the first unclipped → `.nearestUnclippedBase`; bottom layer given itself → `.bottomHasNoBase` |
| LS-11 | `ClipCommandsTests`: `layer.clip` on the bottom layer is unavailable with `noBaseHelp`; clip then unclip are one step each; `layer.unclip` on an unclipped layer is unavailable | a command runs with no base, or records two steps | `SuiteKernel.ClipCommands`: availability ignoring `hasBase` → `.clipNeedsBase`; `setClipped` called per layer → `.oneStepPerRun` |
| LS-12 | `LayerStylePanelLiveTests`: a Distance scrub on the page leaves one undo step and the preview's shadow moves; `testLayerStylePanelEditsAStyle` on live | the page stays on the local log | – (UI) |
| LS-13 | `scripts/waves render --dry-run`; `scripts/jobs check`; `grep -rn effectsPending Sources Tests` finds nothing | status not built, or the fx placeholder is still there | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Distance scrub on the gallery page | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetLayerStyleTests.distanceScrubInThreeBodies` |
| render: 120-sample bevel Angle scrub | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetLayerStyleTests.bevelAngleInThreeBodies` |
| Live style step | one GPU pass, no readback; p95 ≤ 16 ms on a 2,000 × 2,000 layer (release) | `StyleRouteLatencyTests` (perf list) |
| CPU equals GPU | within core's `.style` parity tolerance on the fixture set | `StyleProgramTests.cpuEqualsGpu` |
| One gesture, one step | a scrub, a colour-panel session, a preset each one undo step | `StyleCommandsTests.dragIsOneStep`, `LayerStylePanelLiveTests` |
| No dead controls | every control registers in `suite.controls`; each refused command shows its reason | `testLayerStylePanelEditsAStyle` |
| Keyboard and VoiceOver parity | Tab reaches every row; Space toggles a style; rows read "Drop Shadow, on" | `testLayerStylePanelEditsAStyle` step 6 |
| Kernel stays small | SuiteKernel imports only Foundation and FlareCore | `KernelShapeTests` (unchanged) |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): LS-m and LS-clip merged-done on the Linux
job with `Mutate:` scores clean; LS-gpu's plan and latency on the
supervisor's Mac (SuiteImaging's Metal half builds only on macOS); LS-u's feel
gate (`mouse`, `taste`, `job` lenses) and its `Mac-Finish:` line; LS-z's
journey on live, and RJ-X51 green on Linux once photo/layer-styles PY-5 has
written its check (until then it gates nothing, rule 21). Then
`Belt-Contact-Sheet:` with `suiteui-layer-style-*`.

## Adopted by

`photo/layer-styles` (pixel layers, and text layers as soon as Photo has
them: the style is a layer attribute), `photo/masks-clipping` (the clipping
rule), `photo/psd-effects` (`StyleProgram.style`, findings #3496 and #3497),
`design/layer-styles` (shapes, text and frames; RJ-D14 and the SVG, PNG and
PDF exports), `halo/layer-styles` (layers, with keys on the drop shadow's and
outer glow's numbers). Each waits on LS-a and runs its UI on these stubs.
**No Flare adopt:** Flare has no raster layers (flare.md, Not in scope: raster
painting is Photo's, compositing and effects Halo's); a Flare shadow would be
a vector filter, a separate decision. Library is an S2 adopter for its own
develop effects and has no layer styles; it stays without a packet.

## Not in this packet

Satin, pattern overlay, contour and texture for bevels, multiple instances of
one kind, a shared global light angle, styles on groups, saved user presets
(the five built-in presets only), keyframes on style colours (they wait on
creative-core's colour keys, animate-properties), PSD write of effects.
