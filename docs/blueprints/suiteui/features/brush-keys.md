# Feature packet: brush-keys

**Feature:** the keys every painter's hands expect. `[` and `]` make the brush
smaller and larger in steps that grow with the size, Shift-`[` and Shift-`]`
soften and harden it by 25%, and number keys set opacity: 1 is 10%, 5 is 50%,
0 is 100%, and two digits typed quickly set it exactly (4 then 5 is 45%).
With a brush tool active the number keys set the brush's opacity; otherwise
they set the selected layers' opacity, which is what Design and Flare get,
since neither has a brush tool in the beta (adopt-kernel-brush says Flare's
pencil and Design's brush come later, on the same module, and they will take
these keys then). Photo has no bracket-key handler anywhere today; its size is
a slider only (`PhotoToolOptions.swift`).
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps on the kernel track) · **Lead branch:** `lead/brush-keys`
**Beta:** captain, 2026-10-21 (beta gaps C12). Labels `beta` and `p1` when filed.

**Covers:** `paw-workspace/docs/design/drafts/2026-10-21-beta-gaps-combined.md`
C12, evidence in `2026-10-21-gaps-photo.md` row 11; feature map row
`suiteui/brush-keys` (new); real job RJ-X76 (new).

**Depends on:** editor-kernel, command-catalog, adopt-command-catalog (built).
**Waits:** adopt-kernel-brush AB-photo and adopt-suiteui-chrome AC-colour,
which edit Photo's tool options first.

**Free keys, checked:** the existing `KeyboardShortcut("[")` and `("]")` in
Design's Object menu and Flare's Edit menu default to ⌘ (Send Backward, Bring
Forward), so the bare keys are free in all three apps; Flare's `1` is ⌘1
(Actual Size). Library's ⌘[ and ⌘] (orientation-crop) are a different app.

**Hand-offs** (cross-line): the catalog tails photo/file-flow PF-m,
design/pen-paths DP-m and flare/pen-paths FP-m.

**Rule 20.** Brush settings are the kernel's (`BrushSettings`, EK-28). The
key rule goes beside them, and SuiteUI's `ToolKeys`, already "the one home of
an editor's tool keys" (EK-31), gains the route. No app gets its own key
monitor, and no file in `Tests/canonical-baseline.txt` changes.

**AI-accessible first.** `brush.size-up`, `brush.size-down`,
`brush.hardness-up`, `brush.hardness-down`, `brush.set-opacity {percent}` and
`layer.set-opacity {percent}` (Design and Flare map it onto their existing
opacity edit; Flare keys it when auto-key is on, like an inspector edit).
Menu items: Photo's Edit > Brush (Larger, Smaller, Harder, Softer); Design's
and Flare's Object > Opacity (10% to 100%).

**C4:** BK-4 extends `kernel-stroke.json` (`Stroke/BrushKeys.swift`).

Blueprint sections: suite.md 2 (kernel stroke); photo.md (brush); design.md
and flare.md (opacity).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| BK-a | The kernel declares the key rule (size steps, hardness steps, the digit buffer) and the six brush and opacity specs as stubs, with their tests written and disabled. | BK-1, BK-2 | MJ-BK | editor-kernel, command-catalog (built, `depends`) |
| BK-m | Size steps grow with the size and stay in BrushSettings' range, hardness moves in quarters, a digit sets tens and two quick digits set an exact percent, and the right target (brush or layers) gets each key. | BK-3, BK-4 | MJ-BK | BK-a |
| BK-u | SuiteUI routes the bracket and digit keys from any canvas to the kernel's rule, never while a text field or numeric input has focus, and shows the new size or opacity in a brief readout, reachable from the gallery on the fakes. | BK-5, BK-6 | SJ-BK | BK-a; shared files, after anchor-parenting:AN-u (BK-5) |
| BK-photo | In Photo the bracket keys size and harden the active brush, eraser, clone or heal tool, the digits set its opacity (or the selected layers' with the Move tool), and Edit > Brush lists the same commands. | BK-7, BK-8 | MJ-BK-photo, PJ-BK | BK-a (BK-7); BK-m, BK-u, adopt-kernel-brush:AB-photo and adopt-suiteui-chrome:AC-colour (BK-8); photo/file-flow PF-m (cross-line); shared files, after area-selection:AR-photo-u (BK-8), orientation-crop:OC-photo-m (BK-8) |
| BK-design | In Design the number keys set the selected layers' opacity as one undo step, and Object > Opacity lists the same values. | BK-9, BK-10 | DJ-BK | BK-m, BK-u (BK-10); design/pen-paths DP-m (cross-line); shared files, after adopt-suiteui-chrome:AC-tools (BK-10), document-setup:DS-design (BK-10) |
| BK-flare | In Flare the number keys set the selected layers' opacity, keyed at the playhead when auto-key is on, and Object > Opacity lists the same values. | BK-11, BK-12 | FJ-BK | BK-m, BK-u (BK-12); flare/pen-paths FP-m (cross-line); shared files, after anchor-parenting:AN-flare-u (BK-12) |
| BK-z | RJ-X76 passes and the feature is built. | BK-13, BK-14 | MJ-BK, PJ-BK, DJ-BK, FJ-BK | BK-photo, BK-design, BK-flare |

**Slice size.** Each slice is one PR of 150 to 400 lines with its test commit first (lead.md rule 22). BK-z is smaller than that; the lead folds it into whichever adopt slice merges last, as rule 22 says for a same-feature change under 50 lines.

## Journey steps

- `MJ-BK`: `BrushKeysTests` on Linux.
- `SJ-BK` (`SuiteBrushKeysJourneyTests.testKeysStepSizeAndOpacity`, BK-6): on the gallery's brush page press `]` three times, the readout says 35 px; type 4 5, it says 45%; click into the size field and type 9, only the field changes.
- `MJ-BK-photo`: `PhotoBrushKeysTests` on Linux.
- `PJ-BK` (`PhotoBrushKeysJourneyTests.testBracketsAndDigits`, BK-8): pick the Brush, press `]` twice and 5; the options show 30 px and 50%; paint; the stroke is half-opaque.
- `DJ-BK` (`DesignStyleJourneyTests.testDigitsSetOpacity`, BK-10): select three rectangles, press 5; the inspector reads 50% for all.
- `FJ-BK` (`FlareInspectorJourneys.testDigitsSetOpacity`, BK-12): turn on auto-key, move to frame 12, select a layer, press 3; a key at frame 12 reads 30%.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X76 | adds, closes with `suiteui/brush-keys` | C | `Tests/RealJobs/photo/brush-keys/brush-keys.jobs.json`: in Photo, `tool.brush`, `brush.size-up` ×2 from 20, `brush.set-opacity {percent: 50}`, a horizontal stroke by command on white; export PNG | none (a new white image) |

Trap: the size steps by 1 so two presses barely change it, or the opacity
command sets flow instead. Assertion: the stroke's vertical extent is 30 px
within 1, and its centre pixel is 50% grey within 3 levels. Mutations:
`SuiteKernel.BrushKeys` `.stepBands`, `PhotoModel.PhotoBrushKeys+Kernel`
`.activeToolOnly`. Written by BK-7, disabled (`waits_on: BK-8`); BK-13 records
the run.

## Screens and states

- `suite-gallery-brush-keys-{light,dark}.png` (BK-5): the readout capsule over the canvas.
- `photo-edit-menu-brush-{light,dark}.png` (BK-8).
- `design-object-opacity-menu-{light,dark}.png` (BK-10).

## Contract slice

```swift
// Sources/SuiteKernel/Stroke/BrushKeys.swift (BK-1 stubs, BK-3 bodies). Foundation and FlareCore only.
public enum BrushKeyAction: Hashable, Sendable {
    case brush(BrushEdit)               // size, hardness or opacity on the active brush
    case layerOpacity(Double)           // percent, on the selected layers
}
public enum BrushKeys {
    /// The next size for `]` (up) or `[`: steps of 1 under 10, 5 under 100, 25 under 300, 50 above; clamped to BrushSettings.ranges.size.
    public static func step(size: Double, up: Bool) -> Double
    public static func hardnessStep(_ h: Double, up: Bool) -> Double          // ±25, clamped 0...100
    /// The action for a key; nil when the key isn't one of these.
    public static func action(for key: Character, shift: Bool, settings: BrushSettings, brushActive: Bool,
                              digits: inout OpacityDigits, now: Double) -> BrushKeyAction?
}
public struct OpacityDigits: Sendable {
    public static let window: Double                                           // 0.6 s
    public init()
    public mutating func type(_ digit: Int, at now: Double) -> Double         // percent: 1 → 10, 0 → 100, 4 then 5 → 45
}
// Sources/SuiteKernel/Stroke/BrushKeyCommands.swift (BK-1).
public protocol BrushKeyTarget: AnyObject {
    var activeBrush: BrushSettings? { get }                                    // nil with no brush tool
    func setActiveBrush(_ s: BrushSettings) throws
    func setSelectedOpacity(_ percent: Double) throws                          // one undo step for the whole selection
}
public enum BrushKeyCommands { public static let specs: [CommandSpec] }       // brush.size-up/-down, brush.hardness-up/-down, brush.set-opacity, layer.set-opacity
// Sources/SuiteUI/ToolKeys.swift (BK-5): one new entry point.
extension ToolKeys { public static func brushAction(for event: NSEvent, settings: BrushSettings?, digits: inout OpacityDigits) -> BrushKeyAction? }
```

## Pseudocode

- **Size steps:** `]` adds the band's step and snaps to the band's grid (so
  23 goes to 25, not 28); `[` subtracts it, using the band below at a
  boundary (10 goes to 9).
- **Digits:** a digit within `window` of the last one, when the last one
  started a pair, makes a two-digit percent (4, 5 → 45; 0, 5 → 5); otherwise
  digit × 10, with 0 meaning 100. Each typed digit applies at once, so 4 then
  5 shows 40% for a moment then 45%: one undo step for the pair.
- **Focus guard:** the route returns nil when the key window's first responder
  is an `NSText` or a SwiftUI `TextField`, so digits typed in the inspector
  stay in the field.
- **Shift-digits** (flow in some painting apps) are left for later and do
  nothing, never a different meaning.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| BK-1 | – | **Contract as stubs.** `BrushKeys` (`step(size:up:)`, `hardnessStep`, `OpacityDigits` with its 0.6 s window, `action(for:modifiers:brushActive:)`) and `BrushKeyCommands`' six specs | `Sources/SuiteKernel/Stroke/BrushKeys.swift`, `Sources/SuiteKernel/Stroke/BrushKeyCommands.swift` | – | ~150, 2 |
| BK-2 | – | `BrushKeysTests` written, disabled (`waits on BK-3`) | `Tests/SuiteKernelTests/BrushKeysTests.swift` | BK-1 | ~150, 1 |
| BK-3 | – | `BrushKeys` and `BrushKeyCommands` bodies; turns on `BrushKeysTests` | `Sources/SuiteKernel/Stroke/BrushKeys.swift`, `Sources/SuiteKernel/Stroke/BrushKeyCommands.swift`, `Tests/SuiteKernelTests/BrushKeysTests.swift`, `Tests/mutations/SuiteKernel.BrushKeys.json` | BK-1, BK-2 | ~200, 4 |
| BK-4 | – | The kernel's C4 part names `BrushKeys.swift` and its commands | `docs/c4/parts/creative-apps/suite-kernel/kernel-stroke.json` | BK-3 | ~10, 1 |
| BK-5 | – | **Reachable first:** the gallery's brush page answers the keys on the fakes; `ToolKeys.brushAction(for:)` reads the event through `KeyModifiers` and returns nothing while the first responder is a text input; `BrushKeyReadout` (a capsule that shows "Size 25 px" or "Opacity 45%" for 0.8 s, still under Reduce Motion); `BrushKeyRouteTests` first | `Sources/SuiteUI/ToolKeys.swift`, `Sources/SuiteUI/BrushKeyReadout.swift`, `Sources/SuiteUI/Gallery/GalleryBrushKeys.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/SuiteUITests/BrushKeyRouteTests.swift` | BK-1, BK-2 | ~220, 5 |
| BK-6 | – | The gallery journey and the render budget row | `UITests/SuiteJourneyTests+BrushKeys.swift`, `Tests/AppSnapshotTests/RenderBudgetBrushKeysTests.swift` | BK-5 | ~100, 2 |
| BK-7 | – | **Photo, test first.** `PhotoBrushKeysTests`, disabled: `brush.size-up` on a 20 px brush gives 25 and the options slider shows it; digits with the Move tool set the selected layers' opacity as one undo step; RJ-X76's job folder, disabled; the journey, skipped | `Tests/PhotoModelTests/PhotoBrushKeysTests.swift`, `UITests/PhotoJourneyTests+BrushKeys.swift`, `Tests/RealJobs/photo/brush-keys/brush-keys.jobs.json` | BK-1, BK-2 | ~150, 3 |
| BK-8 | – | `PhotoBrushKeys+Kernel.swift`; the canvas routes `ToolKeys.brushAction`; Edit > Brush items; the six specs in Photo's catalog; turns on the tests | `Sources/PhotoModel/PhotoBrushKeys+Kernel.swift`, `Sources/PhotoApp/PhotoToolOptions.swift`, `Sources/PhotoApp/PhotoCommands+Edit.swift`, `Tests/PhotoModelTests/PhotoBrushKeysTests.swift`, `UITests/PhotoJourneyTests+BrushKeys.swift`, `Tests/mutations/PhotoModel.PhotoBrushKeys+Kernel.json`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/AfterGlowCLITests/Golden/apps/photo.list-commands.json` | BK-7, BK-3, BK-4, BK-5, BK-6 | ~220, 9 |
| BK-9 | – | **Design, test first.** `DesignOpacityKeysTests`, disabled: digit 5 on three selected layers sets each to 50% in one step; the journey, skipped | `Tests/DesignModelTests/DesignOpacityKeysTests.swift`, `UITests/DesignJourneyTests+Style.swift` | – | ~110, 2 |
| BK-10 | – | `DesignOpacityKeys+Kernel.swift` onto Design's existing opacity edit; the canvas routes the keys; Object > Opacity; `layer.set-opacity` in the catalog; turns on the tests | `Sources/DesignModel/DesignOpacityKeys+Kernel.swift`, `Sources/DesignApp/DesignObjectMenu.swift`, `Sources/DesignApp/DesignCanvas.swift`, `Tests/DesignModelTests/DesignOpacityKeysTests.swift`, `UITests/DesignJourneyTests+Style.swift`, `Tests/mutations/DesignModel.DesignOpacityKeys+Kernel.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/AfterGlowCLITests/Golden/apps/design.list-commands.json` | BK-9, BK-3, BK-4, BK-5, BK-6 | ~180, 9 |
| BK-11 | – | **Flare, test first.** `FlareOpacityKeysTests`, disabled: digit 3 sets 30% as a base value with auto-key off and as a key at the playhead with it on; the journey, skipped | `Tests/FlareModelTests/FlareOpacityKeysTests.swift`, `UITests/FlareJourneyTests+Inspector.swift` | – | ~110, 2 |
| BK-12 | – | `FlareOpacityKeys+Kernel.swift` onto the inspector's opacity edit; the stage routes the keys; Object > Opacity; `layer.set-opacity` in the catalog; turns on the tests | `Sources/FlareModel/FlareOpacityKeys+Kernel.swift`, `Sources/FlareApp/FlareCommands.swift`, `Sources/FlareApp/FlareStage+Keys.swift`, `Tests/FlareModelTests/FlareOpacityKeysTests.swift`, `UITests/FlareJourneyTests+Inspector.swift`, `Tests/mutations/FlareModel.FlareOpacityKeys+Kernel.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json` | BK-11, BK-3, BK-4, BK-5, BK-6 | ~180, 9 |
| BK-13 | – | Enables RJ-X76 on Linux (its last `waits_on` goes) and adds the keys to each app's Help > Keyboard Shortcuts list where one exists | `Tests/RealJobs/photo/brush-keys/brush-keys.jobs.json` | BK-7, BK-8, BK-9, BK-10, BK-11, BK-12 | ~20, 1 |
| BK-14 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/brush-keys.wave.json` | BK-13 | ~10, 1 |

## Build waves

- Wave 1: BK-1, BK-9, BK-11. Independent in this wave: all.
- Wave 2: BK-2. Independent in this wave: BK-2 alone.
- Wave 3: BK-3, BK-5, BK-7. Independent in this wave: all.
- Wave 4: BK-4, BK-6. Independent in this wave: both.
- Wave 5: BK-8, BK-10, BK-12. Independent in this wave: all.
- Wave 6: BK-13. Independent in this wave: BK-13 alone.
- Wave 7: BK-14. Independent in this wave: BK-14 alone.

Longest chain: BK-1 → BK-2 → BK-3 → BK-4 → BK-8 → BK-13 → BK-14 (7). Chain of 7: each link is a slice waiting on the slice whose types or files it needs (the stubs before the bodies, the bodies before an app's adapter, the adapter before its screen, the delete and the status last); only the named tasks wait, so the other slices run beside it.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| BK-1 | the kernel builds; `CommandShapeTests` with the six specs | a spec has no schema | – (stubs) |
| BK-2 | compiles, disabled | – | – (tests only) |
| BK-3 | `BrushKeysTests`: `]` from 9 is 10, from 10 is 15, from 100 is 125, from 500 stays 500; `[` from 1 stays 1; Shift-`]` from 60 is 85; digits 4 then 5 within 0.6 s give 45, with 0.7 s between give 50; 0 is 100; with no brush tool the action is layer opacity | a step skips a size, the range breaks, or a slow second digit still joins | `SuiteKernel.BrushKeys`: the window compared with `<=` at 0.6 s → `.windowEdge`; the step table off by one band → `.stepBands`; 0 read as 0% → `.zeroIsHundred` |
| BK-4 | `scripts/c4-assemble --check` | a path is missing | – |
| BK-5 | `BrushKeyRouteTests`: `]` on the canvas returns size-up; the same key with a `NumericInput` focused returns nil; Shift is read; the readout text for each action | a digit typed in a field changes opacity | – (SuiteUI view) |
| BK-6 | `SuiteBrushKeysJourneyTests.testKeysStepSizeAndOpacity`; `RenderBudgetBrushKeysTests.tenBracketsInTenBodies` | – | – |
| BK-7 | compile, disabled; `scripts/jobs check` | – | – (tests only) |
| BK-8 | `PhotoBrushKeysTests`; `PhotoBrushKeysJourneyTests.testBracketsAndDigits` | a key changes the wrong tool's settings or a digit in a field leaks | `PhotoModel.PhotoBrushKeys+Kernel`: the eraser's settings left untouched → `.activeToolOnly`; layer opacity as one step per layer → `.oneStepForAll` |
| BK-9 | compile, disabled | – | – (tests only) |
| BK-10 | `DesignOpacityKeysTests`; `DesignStyleJourneyTests.testDigitsSetOpacity` | only the primary layer changes | `DesignModel.DesignOpacityKeys+Kernel`: primary only → `.everySelected`; 0 read as 0% → `.zeroIsHundred` |
| BK-11 | compile, disabled | – | – (tests only) |
| BK-12 | `FlareOpacityKeysTests`; `FlareInspectorJourneys.testDigitsSetOpacity` | the key changes every frame while recording | `FlareModel.FlareOpacityKeys+Kernel`: auto-key ignored → `.keysWhenRecording`; primary only → `.everySelected` |
| BK-13 | `scripts/jobs run RJ-X76` | the job still waits | – |
| BK-14 | `scripts/waves check`; `scripts/jobs check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: ten `]` presses on the gallery canvas | ≤ 1 window body each; the brush cursor redraws, not the window | `RenderBudgetBrushKeysTests.tenBracketsInTenBodies` |
| render: Photo `]` while the brush cursor shows | ≤ 1 window body | `PhotoRenderBudgetTests.bracketResizesCursorOnly` |
| focus | no key changes a value while a field has focus | `BrushKeyRouteTests.fieldKeepsDigits` |
| one gesture, one step | a digit pair on several layers is one undo step | each adopter's tests |
| no dead controls | every key has a menu item with the same command | `CommandPathTests` |

## Done check

Per slice (rules 6, 15, 17, 21): BK-a and BK-m green on Linux with clean
`Mutate:` scores; BK-u and each adopt slice through the feel gate (`mouse`,
`taste`, `job`: resize and fade a brush without leaving the canvas, and find
the same commands in the menu) with their `Mac-Finish:` lines; BK-z with
RJ-X76 green on Linux. Then `Belt-Contact-Sheet:`.
