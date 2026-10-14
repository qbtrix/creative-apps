# Feature packet: photo-adjustment-layers

**Feature:** PV-6, adjustment layers (#580). Exposure, Levels, Curves and
Hue/Saturation as layers in the stack: each changes the layers under it, has
visibility, opacity, blend mode, order (and, with PV-5 later, a mask). The
Adjust tab edits what is selected: the adjustment layer's own section under
a header naming it, or the whole-image sections under "Image".
**Line:** `line:photo` · **Wave:** 2 (`waves.md`) · **Tier:** p1 (#580 moves
from p2 to p1 with the blueprint, section 9 question 2) · **Lead branch:**
`lead/photo-adjustment-layers`

**Covers:** #580 (closes with AL-8). The blueprint answers its `needs-spec`
questions (section 8.1): the Adjust tab keeps a whole-image set; Exposure,
Levels, Curves and Hue/Saturation can be layers, Blur can't (it reads
neighbours); masks come with PV-5. The lead removes `needs-spec` from #580
with a comment linking this packet when it starts.

**Depends on:** photo-edit (it hands over `A/PhotoCommands+Layer.swift`; it
needs no wait for photo-documents or photo-crop, blueprint 8.2). That
implies photo-seams and photo-journey-kit. No creative-core issue; CR-5
(`hueSaturation` in CoreRaster) is optional and filed only if PB-13 fails in
release.

Hands over after it merges: `M/PhotoLayerComposite.swift`,
`A/PhotoLayersTab.swift` and `A/PhotoCommands+Layer.swift` to PV-5;
`A/AdjustmentsInspector.swift` and `A/CurvesSection.swift` to PV-10.

Blueprint sections: 4.2 PJ-9, 5.1 (`AdjustmentLayering`), 5.3 (PV-6
methods, `AdjustTarget`), 6.1 rules 3 and 4, 6.2 (Adjust tab sections,
Layers tab), 7.1 PB-13, PJ-P2, 7.3 PF-8, PF-12.

## Review notes folded in (review of #768)

- **Merge Down and Flatten reach adjustment layers through the hook.**
  photo-edit's `LiveMerging` composites through
  `PhotoLayerComposite.composite(...)`, so filling the adjustment case here
  (AL-2) makes Merge Down of a pixel layer over an adjustment's result, and
  Flatten of a stack with adjustment layers, match the canvas. AL-2's test
  checks Flatten against the render with an adjustment layer in the stack;
  no edit to `Live/LiveEdit.swift` or `Live/LiveMerging.swift`.
- **The layered fixture.** PJ-7's fixture step (photo-edit) and this
  feature's snapshots use `-PhotoFixture layered`, whose "Curves 1" is a
  real adjustment layer once this feature lands on `.live` too.

**Decisions (this packet):**

- **One kind per layer.** New Adjustment Layer > Curves makes a layer whose
  settings have only Curves enabled. The layer shows the sections that are
  enabled, without their enable switch: the row's eye turns the layer off.
  `PhotoLayer` is not edited (photo-seams froze it); the kind is read from
  the settings.
- **Names** count per kind: "Curves 1", "Curves 2", "Levels 1".
- **Rows** use today's `List` rows with the `slider.horizontal.3` symbol and
  the info line; the shared `LayerList` (SuiteUI lists-and-layers, LL-5) and
  its accessory slot come later as a `line:photo` swap. No SuiteUI edit.

## Journey steps

1. **PJ-9 `testAdjustmentLayer`** (`+AdjustmentLayers`), as blueprint 4.2
   writes it: Layers tab; Layer > New Adjustment Layer > Curves gives a row
   "Curves 1" with `photo.layer.<id>.kind` reading "Adjustment layer" above
   Background, selected; the Adjust tab shows only Curves under the header
   "Curves 1" with the info line "Adjusts the layers below"; "Undo New
   Adjustment Layer". Drag the midpoint up: the canvas differs, "Undo
   Curves". Hide the eye: the canvas equals step 1. New Layer above, brush:
   the stroke is unadjusted. Select the adjustment, Send Backward once: it
   is the bottom row, Send Backward disabled, the row's info line "Nothing
   below to adjust.". Opacity 0: the canvas equals step 1; Command-Z
   restores it. Select Background: the header reads "Image", "Adjusts the
   whole image". Error: with the adjustment selected, Brush and drag: the
   status line reads "Pick a pixel layer to paint on." and nothing changes.
2. **PJ-P2's adjustment series `testAdjustmentLayerScrubLatency`**
   (`+PerfAdjustmentLayers`): on `-PhotoFixture large` add an Exposure
   adjustment layer and drag its bar; at least 60 samples; QB-L2 reported.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Layers tab row | an adjustment at the bottom: info line "Nothing below to adjust." | – | – |
| Adjust tab | no image: today's empty state; a pixel layer selected: the whole-image sections under "Image" | – | – |
| Layer > New Adjustment Layer | no image: the four items disabled "Open an image first." | – | – |
| Canvas | – | a paint tool on an adjustment layer: "Pick a pixel layer to paint on." (photo-seams' `paintTarget()`) | none: an adjustment's tile render stays within PB-13 |

## Contract slice

From blueprint 5.1 (`AdjustmentLayering`) and 5.3's PV-6 methods
(`adjustTarget`, `addAdjustmentLayer(_:)`, `adjustLayer(_:_:)`). Added here:

```swift
// M/PhotoAdjustmentLayer.swift
extension PhotoWorkspace {
    /// The kinds New Adjustment Layer offers: services.adjustmentLayers.kinds.
    public var adjustmentLayerKinds: [AdjustmentKind]
    public var addAdjustmentLayerHelp: String?            // "Open an image first." or the service's help
    /// The sections the Adjust tab shows for the target, in order.
    public var adjustSections: [AdjustmentKind]
    /// "Image" or the layer's name, and the info line under it.
    public var adjustHeader: (title: String, info: String)
    /// The info line under a layer's row: "Nothing below to adjust." for an adjustment at the bottom.
    public func layerInfo(_ id: PhotoLayer.ID) -> String?
    /// Ends a slider or curve gesture on an adjustment layer: one history step per gesture.
    public mutating func endAdjustLayer()
}

// M/Live/LiveAdjustmentLayers.swift (stub from photo-seams, filled here)
enum LiveAdjustmentLayers { static func make() -> any AdjustmentLayering }   // LiveAdjustmentLayering
```

## Pseudocode

```
LiveAdjustmentLayering.applying(settings, below, opacity, blend, mask):        # AL-1
  adjusted = below with settings' enabled sections in today's order (exposure, levels, curves, hue/sat;
             blur never applies on a layer)
  if opacity == 1, blend == .normal, mask == nil: return adjusted              # PF-8 bit for bit
  out = composite(adjusted, onto: below, blend, opacity weighted per pixel by mask's gray)

PhotoLayerComposite.composite(content, onto below, origin, adjusting, masking):  # AL-2
  case .pixels: today's
  case .adjustment(settings): guard layer.isVisible, opacity > 0 else below
       adjusting.applying(settings, to: below, opacity, blend, mask: nil)   # PV-5 passes its mask later

addAdjustmentLayer(kind):                                                    # AL-3
  guard addAdjustmentLayerHelp == nil
  settings = AdjustmentSettings() with only `kind` enabled
  record "New Adjustment Layer": insert PhotoLayer(kind: .adjustment(settings), name "<Kind> <n>")
    above the selected layer, select it; no pixels entry; touch(.all)
adjustTarget = selected layer is adjustment(s) ? .layer(id, s) : .image
adjustLayer(id, edit): new = settings.applying(edit) (today's clamps and refusals);
  record "<Kind title>" coalescing per gesture; touch(.all)
endAdjustLayer(): close the coalescing gesture (as endAdjust does today)
paint on adjustment: refused by paintTarget() (photo-seams)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: photo-adjustment-layers`,
`Fast-Check: pass`, `Head:`. The last one carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| AL-1 | #580 (part) | `LiveAdjustmentLayering.applying` | `M/Live/LiveAdjustmentLayers.swift`, `MT/LiveAdjustmentLayeringTests.swift` | – | ~220, 2 |
| AL-2 | #580 (part) | The adjustment case of `PhotoLayerComposite`; render and damaged tiles with adjustment layers (PF-12); Flatten through the hook | `M/PhotoLayerComposite.swift`, `MT/PhotoAdjustmentLayerTileTests.swift` | AL-1 | ~260, 2 |
| AL-3 | #580 (part) | Workspace: add, target, adjust, end gesture, header and info lines | `M/PhotoAdjustmentLayer.swift`, `MT/PhotoAdjustmentLayerTests.swift` | AL-2 | ~340, 2 |
| AL-4 | – | Budget PB-13 (model step) and its event-to-picture series | `MT/PhotoAdjustmentLayerBudgetTests.swift`, `ST/PhotoAdjustmentLayerLatencyTests.swift` | AL-3 | ~200, 2 |
| AL-5 | #580 (part) | Layer > New Adjustment Layer submenu with its help; the window's adjustment-layer intents | `A/PhotoCommands+Layer.swift`, `A/PhotoWindow+AdjustmentLayer.swift` | AL-3 | ~180, 2 |
| AL-6 | #580 (part) | Layer rows: kind symbol, identifiers, the info line; snapshot | `A/PhotoLayersTab.swift`, `ST/PhotoAdjustmentLayerSnapshots.swift` | AL-5 | ~200, 2 |
| AL-7 | #580 (part) | The Adjust tab edits the target: header and info line, only the layer's sections, Curves reads and writes the target's curve | `A/PhotoAdjustTab.swift`, `A/AdjustmentsInspector.swift`, `A/CurvesSection.swift`, `ST/PhotoAdjustTargetSnapshots.swift` | AL-6 | ~300, 4 |
| AL-8 | #580 (closes) | Journeys PJ-9 and the adjustment series of PJ-P2 | `UT/PhotoJourneyTests+AdjustmentLayers.swift`, `UT/PhotoJourneyTests+PerfAdjustmentLayers.swift` | AL-7 | ~260, 2 |

Chain: AL-1 → AL-2 → AL-3, then AL-4 beside AL-5 → AL-6 → AL-7 → AL-8
(AL-5 to AL-7 each change what the window shows, so they go in turn). AL-8
carries `feature-done`.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| AL-1 | `LiveAdjustmentLayeringTests`: PF-8 part one, opacity 1, normal, no mask equals the same settings applied by today's whole-image path bit for bit; opacity 0 returns `below` bit for bit; opacity 0.5 lies halfway within 1/255; a gray mask of 0.5 equals opacity 0.5 within 1/255; Blur enabled in the settings is ignored | the adjustment differs from the whole-image path, or Blur applies on a layer |
| AL-2 | `PhotoAdjustmentLayerTileTests`: PF-12, the damaged tiles with an adjustment layer in a 3-layer stack equal `PhotoRenderer.render` of the full frame; PF-8 part two, an adjustment layer at the top equals whole-image adjustments with the same settings bit for bit; a hidden one equals no layer; Flatten (`LiveMerging`) of the stack equals the render | a tile differs from the frame, or Flatten ignores the adjustment |
| AL-3 | `PhotoAdjustmentLayerTests`: add gives "Curves 1" above the selected layer, selected, one "New Adjustment Layer" step; a second gives "Curves 2"; `adjustTarget` follows the selection; a curve drag of 30 events is one "Curves" step; undo of the layer-list step with an adjustment layer works (photo-seams' guard); `layerInfo` gives "Nothing below to adjust." at the bottom only; `adjustSections` is `[.curves]` for a Curves layer and the five sections for `.image` | names repeat, a gesture takes many steps, or the target is wrong |
| AL-4 | `PhotoAdjustmentLayerBudgetTests`: PB-13, an Exposure drag event on an adjustment layer in a 3-layer stack, one 256 px tile, ≤ 4 ms release (report in debug); the latency series ≤ 8 ms per tile batch release p50 (reported in CI) | a release gate is missed locally, or a series has fewer than 60 samples |
| AL-5 | V4 green; the four kinds are items under New Adjustment Layer, disabled with "Open an image first." with no image (snapshot-host menu check); Blur is not offered | an item is dead, or Blur is offered |
| AL-6 | `PhotoAdjustmentLayerSnapshots`: `photo-adjustment-layer-light.png`, `-dark.png` (Paint, Curves 1, Background, from `layered`); every row has `photo.layer.<id>.eye` and `.kind` with labels; V10 green | a row has no identifier, or the symbol is missing |
| AL-7 | `PhotoAdjustTargetSnapshots`: `photo-adjust-target-light.png`, `-dark.png` (Curves 1 selected: header "Curves 1", "Adjusts the layers below", one section, no enable switch); with Background selected the v1 inspector snapshots are unchanged; V3 and V11 green | the header is wrong, a whole-image section shows for a layer, or the v1 look changes |
| AL-8 | PJ-9 passes on the macOS run with every step `shot`; the adjustment series records at least 60 samples | any step fails |

## Quality tests

| quality row | budget | test |
|---|---|---|
| PB-13 adjustment drag in a 3-layer stack | ≤ 4 ms release, report debug; ≤ 8 ms per damaged tile batch (release p50, reported) | `PhotoAdjustmentLayerBudgetTests.exposureDragOnLayer`, `PhotoAdjustmentLayerLatencyTests`, PJ-P2 series |
| PF-8 | equals whole-image adjustments bit for bit; opacity 0 equals none | `LiveAdjustmentLayeringTests`, `PhotoAdjustmentLayerTileTests` |
| PF-12 | damaged tiles equal the full frame | `PhotoAdjustmentLayerTileTests.tilesMatchFrame` |
| QB-F1 | each New Adjustment Layer item acts or gives a reason | `PhotoAdjustmentLayerTests.everyItemActsOrSaysWhy` |
| QB-F2 | the canvas changes in the same call as a slider event (damage `.all` recorded) | `PhotoAdjustmentLayerTests.adjustDamagesAtOnce` |
| QB-F3 | one gesture, one named step | `PhotoAdjustmentLayerTests.oneGestureOneStep`, PJ-9 |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the
  `feature-done` PR is green: PJ-9, V1–V12 and every wave-1 journey (PJ-1 to
  PJ-8, which must not change).
- **Audit zero new:** no Photo count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey, the PB-13 number and the audit counts.
