# Feature packet: masks-clipping (Photo)

**Feature:** layer masks on Photo's image layers, and clipping groups. Layer >
Add Mask (Reveal All, Hide All, From Selection), Delete Mask, Apply Mask,
Disable Mask and Edit Mask: the brush and eraser paint the mask in grey while
Edit Mask is on, the pixels it hides stay in the layer, and a disabled mask
shows them. Layer > Create Clipping Mask clips the selected layer to the
nearest unclipped layer below it (its base): the clipped layer draws only
where the base has alpha, and Release Clipping Mask undoes it. Each action is
one undo step, saved in the `.ora`, and a catalog command the CLI runs.
**Line:** `line:photo` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/masks-clipping`
**Beta:** captain, 2026-10-21 (masks and clipping pulled into the beta beside
layer styles; photo.md had clipping as Tier 3 and multi-layer-select listed
clipping groups as a follow-up). Labels `beta` and `p1` when filed.

**Covers:** photo.md PV-5's layer-mask half (journey PJ-13; the selection
shapes beyond rectangles, #421, stay out); feature map S4's and S8's Photo
adopters (`photo/masks-clipping`); real jobs RJ-P05 (closes) and RJ-P45 (new).

**Depends on:** creative-core masks-mattes (core#431, built and on the pinned
core: `Mask`, the masked composite, a mask from alpha); `suiteui/layer-styles`
**LS-clip** (cross-line: `ClipRules`, `ClipTarget`, `layer.clip` and
`layer.unclip`; PK-8 waits on it, the rest of the packet does not). Same
line: `layer-styles` (this line's PY slices own `PhotoLayer.swift`,
`PhotoCommandCatalog.swift`, `photo.txt`, `PhotoCommands+Layer.swift` and
`PhotoLayerComposite.swift` first: PK-a waits on PY-a, PK-m on PY-m) and
`multi-layer-select` (it owns `PhotoStroke.swift` and `PhotoLayerList.swift`
first).

**Hand-offs:** the row's mask badge (`photo.layer.mask-badge`) and the clip
indent use the row accessory of the shared `LayerTreeList`; if that row has
no slot for a second accessory when PK-2 starts, PK-2 files a `needs-ui`
issue on `line:suiteui` and shows the badge in Photo's existing row
accessory meanwhile.

**Rule 20.** No Photo mask engine and no Photo clip rule. Feather, coverage
and the masked composite are creative-core's (masks-mattes); which layer a
clipped layer clips to is the kernel's `ClipRules`, reached through
`PhotoClip+Kernel.swift`. The mask's tiles, its history step and its place in
the `.ora` already exist (PV-0's seams: `PhotoWorkspace.masks`,
`PhotoEdit.maskTiles`, `editsMask`); this packet fills them.

**Render path.** `PhotoLayerComposite` composites a masked layer through
core's masked composite (coverage = the mask's grey) and a clipped layer
through the same op with its base's alpha as the mask, on both of Photo's
routes, so the live canvas and export agree.

Blueprint sections: photo.md 4 (Layers, Masks), 8 (PV-5), the journeys table
(PJ-13).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PK-a | The mask and clip commands are in Photo's catalog on stubs with their reasons, image layers carry a clip flag, and the Layer menu and layer rows show them. | PK-1, PK-2 | MJ-PK | layer-styles:PY-a; multi-layer-select |
| PK-u | The mask badge, clip indent and Edit Mask state have snapshots and a render budget, and both journeys are written. | PK-3, PK-4 | PJ-13, PJ-K2 | PK-a |
| PK-m | Add, delete, apply, enable and paint a mask, and clip and release, each one undo step; masked and clipped layers composite through core's masked composite; the `.ora` keeps both. | PK-5, PK-6, PK-7, PK-8 | MJ-PK | PK-a; layer-styles:PY-m (PK-7, PK-8: `PhotoLayerComposite.swift`, `PhotoDocumentFile.swift`); LS-clip (PK-8, cross-line) |
| PK-z | Both journeys pass on live services and photo.md lists masks and clipping as built. | PK-9, PK-10 | PJ-13, PJ-K2 | PK-u, PK-m |

PK-u waits only on PK-a (rule 18); PK-m never waits on PK-u. MJ-PK is
`PhotoLayerMaskTests` and `PhotoClipTests` on Linux.

## Journey steps

PJ-13 (`PhotoMaskJourneyTests.testLayerMaskFromSelection`, photo.md's row,
with a rectangle marquee instead of an ellipse):
1. Open `layered`, select "Paint", marquee its left half, Layer > Add Mask >
   From Selection (PK-2): the row shows the mask badge; the right half of
   Paint is hidden.
2. Turn on Layer > Edit Mask, paint white with the brush over the right half:
   it shows again where painted; the layer's pixels never changed.
3. Shift-click the badge (Disable Mask): the whole layer shows; again to
   enable. Layer > Apply Mask: hidden pixels become transparent, one step.

PJ-K2 (`PhotoMaskJourneyTests.testClipTextureToShape`):
1. Add a new layer above "Paint", fill it red, Layer > Create Clipping Mask:
   the row indents with the clip mark; red shows only where Paint has alpha.
2. Hide "Paint": the red layer hides with it. Show it, Release Clipping Mask:
   red covers the canvas again. The bottom layer's Create Clipping Mask is
   disabled with "There is no layer below to clip to."

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P05 | closes (with S4) | C | `Tests/RealJobs/photo/soft-mask-blend/soft-mask-blend.jobs.json`: open two photos as layers, `layer.mask-add {from: reveal}` on the top one, a soft black brush stroke across its middle with `layer.mask-edit {on: true}`, `doc.save` `.ora`, reopen, `file.export` PNG | `input/two-photos.ora` |
| RJ-P45 | adds, closes with S8 | C | `Tests/RealJobs/photo/clip-texture/clip-texture.jobs.json`: `layer.clip` on a texture above a disc, `file.export` PNG; `layer.clip` on the bottom layer refused | `input/disc-texture.ora` |

RJ-P05's trap (from its row): the mask is flattened on save, or the brush
paints colour into the mask instead of grey. Assertion: after the reopen the
layer still has its mask and its pixels under the stroke are unchanged; the
PNG blends the two photos across the stroke (the middle column's pixels lie
strictly between the two sources) and the mask's tiles hold only grey.
Mutations: `PhotoModel.PhotoStroke.json` (mask dab written as colour →
`.maskPaintIsGrey`), `PhotoModel.PhotoMask.json` (apply deletes pixels before
the step is recorded → `.applyIsOneStep`).

RJ-P45's trap: the clip uses the base's bounding box, not its alpha, or a
clip with no base succeeds silently. Assertion: every PNG pixel outside the
disc's alpha is the background's; the bottom layer's `layer.clip` exits with
`noBaseHelp`. Mutation: `PhotoModel.PhotoLayerComposite.json` (base bounds
used as the mask → `.clipFollowsBaseAlpha`).

## Screens and states

`photo-mask-badge` (a layer with a mask, enabled and disabled), `photo-mask-edit`
(Edit Mask on, the badge selected), `photo-clip-indent` (a clipped layer
over its base), light and dark.

## Contract slice

```swift
// Sources/PhotoModel/PhotoLayer.swift (PK-1)
public internal(set) var isClipped = false
// Sources/PhotoModel/PhotoMask.swift (PK-1 stubs throwing NotBuilt, PK-5 bodies)
public enum MaskStart: String, Codable, CaseIterable, Sendable { case reveal, hide, selection }
extension PhotoWorkspace {
    public var maskHelp: String? { get }                       // why a mask command can't run now
    public mutating func addMask(_ start: MaskStart) throws    // "Add Layer Mask"
    public mutating func deleteMask() throws                   // "Delete Layer Mask"
    public mutating func applyMask() throws                    // "Apply Layer Mask"
    public mutating func setMaskEnabled(_ on: Bool) throws     // "Disable Layer Mask" / "Enable Layer Mask"
    public mutating func setEditsMask(_ on: Bool)              // the paint target; no step
}
// Sources/PhotoModel/PhotoClip+Kernel.swift (PK-1 stubs, PK-8 bodies)
extension PhotoWorkspace: ClipTarget { ... }
```

Commands, in `PhotoCommandCatalog` (ids in `Tests/command-ids/photo.txt`):
`layer.mask-add {from}`, `layer.mask-delete`, `layer.mask-apply`,
`layer.mask-enable {enabled}`, `layer.mask-edit {on}` (view), plus
`ClipCommands.specs(PhotoWorkspace.self)` (`layer.clip`, `layer.unclip`).
Unavailable: no image layer selected; Add with a mask already there ("This
layer already has a mask."); From Selection with no selection; Delete, Apply,
Enable and Edit with no mask; clip as `ClipRules` says.

## Pseudocode

- **addMask.** `.reveal` all 255, `.hide` all 0, `.selection` the
  selection's coverage (`selectionMask`, or 255 inside the rectangle) at the
  layer's size and place; one `.maskTiles` step plus the layer flag.
- **applyMask.** Multiply the layer's alpha by the mask (straight alpha),
  drop the mask; one step holding both the tiles and the mask.
- **Paint.** While `editsMask` and the layer has a mask, `PhotoStroke`'s
  target is `.mask(id)` (the seam PV-0 left): a dab writes the brush colour's
  luminance as grey with alpha 1; the eraser writes 0; tiles record as
  `.maskTiles`.
- **Geometry.** `layerGeometryChanged` (the PV-0 hook) moves, crops, flips,
  rotates and resamples the mask with its layer; `duplicated` copies it,
  `removed` drops it.
- **Composite.** Masked: core's masked composite with the mask's grey as
  coverage (a disabled mask: plain composite). Clipped: the base and every
  layer `ClipRules.clipped(onto:)` lists draw as a unit; each clipped layer
  composites through the base's alpha as a mask (core's mask from alpha); a
  hidden base hides them; the base's own mask applies to them too.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PK-1 | – | `PhotoLayer.isClipped`; the mask and clip API as stubs; the seven specs and ids; `PhotoLayerMaskTests` and `PhotoClipTests` written, disabled | `Sources/PhotoModel/PhotoLayer.swift`, `Sources/PhotoModel/PhotoMask.swift`, `Sources/PhotoModel/PhotoClip+Kernel.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/PhotoModelTests/PhotoLayerMaskTests.swift`, `Tests/PhotoModelTests/PhotoClipTests.swift` | PY-1 | ~300, 7 |
| PK-2 | – | Layer menu items bound by id; the row's mask badge (Shift-click disables) and clip indent | `Sources/PhotoApp/PhotoCommands+Layer.swift`, `Sources/PhotoApp/PhotoLayerList.swift` | PK-1, PY-2 | ~180, 2 |
| PK-3 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoMaskSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoMaskTests.swift` | PK-2 | ~180, 2 |
| PK-4 | – | Both journeys written and skipped (`XCTSkip("waits on PK-9")`) | `UITests/PhotoJourneyTests+Mask.swift` | PK-2 | ~150, 1 |
| PK-5 | – | The mask bodies and the geometry hook; turns on `PhotoLayerMaskTests` | `Sources/PhotoModel/PhotoMask.swift`, `Tests/PhotoModelTests/PhotoLayerMaskTests.swift`, `Tests/mutations/PhotoModel.PhotoMask.json` | PK-1 | ~320, 3 |
| PK-6 | – | Painting the mask: the stroke target, grey dabs, the eraser | `Sources/PhotoModel/PhotoStroke.swift`, `Tests/PhotoModelTests/PhotoMaskPaintTests.swift`, `Tests/mutations/PhotoModel.PhotoStroke.json` | PK-5 | ~200, 3 |
| PK-7 | – | Masked and clipped layers in the composite; RJ-P05's and RJ-P45's job folders | `Sources/PhotoModel/PhotoLayerComposite.swift`, `Tests/PhotoModelTests/PhotoMaskCompositeTests.swift`, `Tests/mutations/PhotoModel.PhotoLayerComposite.json`, `Tests/RealJobs/photo/soft-mask-blend/soft-mask-blend.jobs.json`, `Tests/RealJobs/photo/soft-mask-blend/input/two-photos.ora`, `Tests/RealJobs/photo/clip-texture/clip-texture.jobs.json`, `Tests/RealJobs/photo/clip-texture/input/disc-texture.ora` | PK-5, PK-8, PY-6 | ~340, 7 |
| PK-8 | – | The clip adapter's bodies over `ClipRules`; the flag in the `.ora`; turns on `PhotoClipTests` | `Sources/PhotoModel/PhotoClip+Kernel.swift`, `Sources/PhotoModel/PhotoDocumentFile.swift`, `Tests/PhotoModelTests/PhotoClipTests.swift`, `Tests/mutations/PhotoModel.PhotoClip+Kernel.json`, `Tests/mutations/PhotoModel.PhotoDocumentFile.json` | PK-1, LS-clip, PY-6 | ~200, 5 |
| PK-9 | – | Both journeys turned on, on live services | `UITests/PhotoJourneyTests+Mask.swift` | PK-4, PK-6, PK-7 | ~40, 1 |
| PK-10 | – | photo.md: masks and clipping groups move into the Layers and Masks rows; `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/masks-clipping.wave.json` | PK-9, PK-3 | ~20, 2 |

## Build waves

- Wave 1: PK-1. Independent in this wave: PK-1 alone.
- Wave 2: PK-2, PK-5, PK-8. Independent in this wave: all three.
- Wave 3: PK-3, PK-4, PK-6, PK-7. Independent in this wave: all four.
- Wave 4: PK-9. Independent in this wave: PK-9 alone.
- Wave 5: PK-10 (shared prose, `feature-done`, final). Independent in this wave: PK-10 alone.

Longest chain: PK-1 → PK-5 → PK-7 → PK-9 → PK-10 (5). Chain of 5: the
composite needs the mask's bodies, the journeys need the composite, PK-10 is
the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PK-1 | both suites compile, disabled; the command-id list matches the catalog; each command is unavailable with its reason on the stubs | an id or a reason is missing | – (stub) |
| PK-2 | `PhotoMaskSnapshots.badge` (PK-3's, first in the slice PR) | a menu item or the badge is missing | – (UI) |
| PK-3 | `PhotoMaskSnapshots`; `RenderBudgetPhotoMaskTests.maskStrokeInThreeBodies` | budget over | – (UI) |
| PK-4 | compiles, skipped | – | – |
| PK-5 | `PhotoLayerMaskTests`: From Selection gives 255 inside the marquee, 0 outside; Reveal All with a mask already there is refused; Apply makes hidden pixels alpha 0 in one undo step; a crop moves the mask with the layer; duplicate copies it | a mask's coverage, place or step is wrong | `PhotoModel.PhotoMask`: selection inverted → `.fromSelectionRevealsInside`; geometry hook skipped on crop → `.maskFollowsCrop`; apply as two steps → `.applyIsOneStep` |
| PK-6 | `PhotoMaskPaintTests`: with Edit Mask on, a red dab writes the red's luminance as grey and leaves the layer's pixels; the eraser writes 0; Edit Mask with no mask paints the layer | a dab lands on the pixels or in colour | `PhotoModel.PhotoStroke`: target ignores `editsMask` → `.paintsTheMask`; colour written to the mask → `.maskPaintIsGrey` |
| PK-7 | `PhotoMaskCompositeTests`: a 50% grey mask halves the layer's coverage; a disabled mask draws the whole layer; a clipped layer draws only inside its base's alpha; a hidden base hides its clipped layers; RJ-P05 and RJ-P45 pass on Linux | coverage, clip shape or visibility is wrong | `PhotoModel.PhotoLayerComposite`: base bounds used as the mask → `.clipFollowsBaseAlpha`; disabled mask still applied → `.disabledMaskShowsAll`; hidden base ignored → `.hiddenBaseHidesClipped` |
| PK-8 | `PhotoClipTests`: clip and release are one step each; the bottom layer refuses with `noBaseHelp`; the flag survives save and reopen; an old file opens unclipped | a clip runs with no base or is lost on save | `PhotoModel.PhotoClip+Kernel`: `hasBase` always true → `.bottomLayerRefuses`; `PhotoModel.PhotoDocumentFile`: flag not written → `.clipSurvivesSave` |
| PK-9 | `testLayerMaskFromSelection` steps 1 to 3; `testClipTextureToShape` steps 1 and 2 | a step fails | – |
| PK-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample brush stroke on a mask | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetPhotoMaskTests.maskStrokeInThreeBodies` |
| One gesture, one step | a mask stroke, Apply, a clip each one step | `PhotoLayerMaskTests`, `PhotoClipTests` |
| No dead controls | every mask and clip item disabled with its reason when it can't run | `PhotoLayerMaskTests`, the journeys |
| Budget | eight layers with masks at 16 MP composite within `PhotoBudgetTests`' limit | `PhotoBudgetTests.limit` (existing fixture) |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PK-m merged-done on the Linux job with
`Mutate:` clean and RJ-P05 and RJ-P45 green there; PK-a and PK-u through the
feel gate (`mouse`, `taste`, `job`) with `Mac-Finish:`; PK-z's journeys on
live. Then `Belt-Contact-Sheet:` with `photo-mask-*` and `photo-clip-*`.

## Not in this packet

Ellipse and lasso selections (#421), vector masks, mask density and feather
sliders, group masks and clipping to a group (Photo's group, PM-g, is
pass-through only), masks on adjustment layers beyond what PV-6 has.
