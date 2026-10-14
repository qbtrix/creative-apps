# Feature packet: photo-edit

**Feature:** PV-2. Get pixels into and between layers: Cut, Copy, Paste as a
new layer (at its place or centered), Paste of another app's image (as a new
layer, or as a new image when none is open), Duplicate Layer, Merge Down and
Flatten Image, each with its reason when it can't run.
**Line:** `line:photo` · **Wave:** 1 (`waves.md`) · **Tier:** p1 · **Lead
branch:** `lead/photo-edit`

**Covers:** no open issue (blueprint 8.1: PV-2 has none). Tier-1 row 7.

**Depends on:** photo-seams (`EditContracts.swift`, `LiveEdit.swift` stub,
`PhotoLayerComposite`, `PhotoWindow+Edit.swift`, `PhotoCommands+Edit.swift`,
`PhotoCommands+Layer.swift`, `layerGeometryChanged`, the internal
`insertLayer`). Only the journey tasks E-9 and E-10 also wait on
photo-journey-kit; if it is still open when they come up, the lead records
the wait, keeps its heartbeat, and builds them once it closes.
No creative-core issue.

Hands over after it merges: `A/PhotoCommands+Layer.swift` to
photo-adjustment-layers (wave 2), `A/PhotoCommands+Edit.swift` to PV-7
(wave 3).

Blueprint sections: 4.2 PJ-5 to PJ-7, 5.1 (`PixelClipboard`,
`LayerMerging`), 5.3 (PV-2 methods), 6.1 rules 7 and 8, 7.1 PB-15, PB-16,
7.3 PF-3, PF-4, 7.5 QB-F4 (Command-J, Command-E; Flatten has none).

## Review notes folded in (review of #768)

1. **PF-3 is within 1/255, not bit for bit.** Layers are Float32
   `TiledPixels`, and the clipboard carries an 8-bit `DecodedImage`
   (`ClipboardImage`), so a painted Float value can't come back exactly. PF-3
   now reads: the pasted layer equals the source inside the selection within
   1/255 per channel, and exactly for pixels that came from an 8-bit file
   untouched. Keeping Float pixels for copies inside the app would need a
   second clipboard type in the contract; not worth it for v2.
2. **Merge Down and Flatten use the render hook.** `LiveMerging` composites
   each layer through `PhotoLayerComposite.composite(_:onto:origin:adjusting:masking:)`
   (photo-seams) with `LiveAdjustmentLayers.make()` and
   `LiveSelection.masking()`, the same per-layer step `PhotoRender` uses.
   When photo-adjustment-layers (wave 2) and PV-5 (later) fill that hook,
   Merge Down and Flatten apply adjustment layers and masks with no edit to
   `Live/LiveEdit.swift` or `Live/LiveMerging.swift`. PF-4 checks Merge Down
   and Flatten against `PhotoRenderer.render` of the same stack, so the
   hook can't drift between the two.
3. **PJ-7's error state launches on a fixture.** "Merge Down onto an
   adjustment layer" needs an adjustment layer, which the UI can't make
   before photo-adjustment-layers. The step launches with
   `-PhotoFixture layered` (Paint, Curves 1, Background, top first) and
   selects Paint. `mergeDownHelp` is workspace code (it reads the lower
   layer's kind), so it gives the reason on `.fake` too.

**Decision:** Cut, Copy and Paste act on the image only when no text field
has focus: not while a sheet is up (as Select All since #709) and not while
the key window's first responder is a text view (a focused crop field,
opacity field or layer name). Then the system's text commands run.

## Journey steps

As blueprint 4.2 writes them, with note 3 for PJ-7:

1. **PJ-5 `testCopyPasteAsNewLayer`** (`+Edit`): no selection: Cut and Copy
   enabled (whole layer), Paste disabled with "Nothing to paste." (the test
   clears the pasteboard); marquee the sun, Command-C, Paste enabled;
   Command-V gives "Pasted Layer" above Background, selected, its bounds on
   the info line equal the selection, "Undo Paste"; select Background,
   Command-X: the sun area transparent, "Undo Cut"; Command-Z twice restores
   both. Error: marquee an empty area of a new transparent layer, Command-C:
   "Nothing to copy." in the status line.
2. **PJ-6 `testPasteFromAnotherApp`** (`+Edit`): the runner writes a 200 ×
   100 PNG to `NSPasteboard.general`; on `beach.png` Edit > Paste gives a
   200 × 100 layer at (300, 250) at Fit, "Undo Paste"; with no image open,
   Paste opens a 200 × 100 image titled "Untitled". Error: a 6000 × 4000
   pasteboard image (24 MP) pastes scaled to fit `maxOpenPixels` (16,777,216) as 5016 × 3344, with
   "Pasted at 84%." (each side rounded down; the scale rounded to whole
   percent).
3. **PJ-7 `testDuplicateMergeAndFlatten`** (`+LayerOps`): Command-J gives
   "Background copy" above, selected, "Undo Duplicate Layer"; blend Screen,
   opacity 60, Command-E: one layer "Background", the canvas shot equal to
   before the merge, "Undo Merge Down"; New Layer, brush, Flatten Image: one
   layer, "Undo Flatten Image"; with one layer Merge Down is disabled with
   "There's no layer below to merge into." and Flatten with "The image
   already has one layer.". Last step (note 3): relaunch with
   `-PhotoFixture layered`, select Paint: Merge Down disabled with "Merge
   Down needs a pixel layer below.".

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Edit menu | no image: Cut and Copy disabled "Open an image first."; Paste enabled only with an image on the pasteboard (opens a new image) | nothing on the pasteboard: Paste disabled "Nothing to paste."; a fully transparent area: "Nothing to copy." in the status line | – |
| Layer menu | one layer: Merge Down and Flatten disabled with their reasons | lower layer is an adjustment layer: "Merge Down needs a pixel layer below." | "Merging…" on the canvas after 100 ms (6.1 rule 8) |
| Status line | – | "Pasted at <n>%." note after an oversized paste | – |

## Contract slice

From blueprint 5.1 (`ClipboardImage`, `PixelClipboard`, `LayerMerging`) and
5.3's PV-2 methods. Added here:

```swift
// M/Live/LiveEdit.swift (stub from photo-seams, filled here)
enum LiveEdit {
    static func clipboard() -> any PixelClipboard   // LiveClipboard
    static func merging() -> any LayerMerging       // LiveMerging (M/Live/LiveMerging.swift)
}

// M/PhotoClipboard.swift
extension PhotoWorkspace {
    /// A pasted image over `maxOpenPixels` (the open limit, 16,777,216) is scaled to fit,
    /// each side rounded down so the product never passes it.
    public var pasteHelp: (_ pasteboardHasImage: Bool) -> String?   // nil, "Nothing to paste."
}

// A/PhotoPasteboard.swift (macOS)
enum PhotoPasteboard {
    /// Writes the image as PNG and TIFF on the general pasteboard.
    static func write(_ image: ClipboardImage, to pasteboard: NSPasteboard = .general)
    /// The first image on the pasteboard (PNG, TIFF or any type ImageIO reads), decoded; nil if none.
    static func read(from pasteboard: NSPasteboard = .general) -> ClipboardImage?
    static func hasImage(_ pasteboard: NSPasteboard = .general) -> Bool
}
```

## Pseudocode

```
LiveClipboard.copy(content, selection, mask):                # E-1
  region = selection ?? content's bounds; clip to content
  pixels weighted by mask coverage when mask != nil
  trim to the bounds of alpha > 0; nil when none
  encode to 8-bit straight sRGB DecodedImage; source = trimmed rect in canvas pixels
LiveClipboard.placement(image, canvas, center):
  if let s = image.source, s overlaps canvas -> s
  else rect of image size centered on center, clamped so at least 1 px lies on the canvas

LiveMerging.mergeDown(upper, onto lower):                    # E-2
  guard lower.pixels != nil else refuse "Merge Down needs a pixel layer below."
  bounds = union(upper bounds, lower bounds); buffer = lower's pixels placed in bounds
  buffer = PhotoLayerComposite.composite(upper, onto: buffer, origin: bounds.origin,
                                         adjusting: LiveAdjustmentLayers.make(), masking: LiveSelection.masking())
  -> PlacedPixels(buffer, bounds.x, bounds.y)
LiveMerging.flatten(layers, canvas, adjustments):
  picture = transparent canvas; for each visible layer bottom-up: picture = composite(layer, onto: picture)
  apply adjustments (today's whole-image path) -> TiledPixels

copySelection(): guard copyHelp == nil; services.clipboard.copy(selected layer, selection, selectionMask) ?? refuse "Nothing to copy."
cutSelection(): image = copySelection(); record "Cut": clear the area (weighted by coverage)
paste(image, viewCenter):                                    # E-3
  no canvas: newCanvas(image size), put the image in Background, name "Untitled", saved
  scale = min(1, sqrt(maxOpenPixels / (w*h))); if scale < 1: size = (floor(w*scale), floor(h*scale)),
    resize (lanczos3), statusMessage "Pasted at <round(scale*100)>%."
  rect = services.clipboard.placement(...); record "Paste": insert "Pasted Layer" above selected, select it
duplicateSelectedLayer(): record "Duplicate Layer": copy layer + tiles + mask, name "<name> copy";
  layerGeometryChanged(new, .duplicated(from: id))                                    # E-4
mergeDownHelp: one layer -> "There's no layer below to merge into."; lower is adjustment -> "Merge Down needs a pixel layer below."
mergeDown(): record "Merge Down": placed = services.merging.mergeDown(upper, lower); replace lower; remove upper
  (layerGeometryChanged(lower, ...) for the new bounds; layerGeometryChanged(upper, .removed))
flattenHelp: one layer and no adjustment layer -> "The image already has one layer."
flattenImage(): record "Flatten Image": one Background layer = services.merging.flatten(...); adjustments reset
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: photo-edit`, `Fast-Check:
pass`, `Head:`. The last one carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| E-1 | – | `LiveClipboard`: copy weighted by the mask, trimmed; placement | `M/Live/LiveEdit.swift`, `MT/LiveClipboardTests.swift` | – | ~240, 2 |
| E-2 | – | `LiveMerging` through `PhotoLayerComposite` | `M/Live/LiveMerging.swift`, `M/Live/LiveEdit.swift`, `MT/LiveMergingTests.swift` | E-1 | ~260, 3 |
| E-3 | – | Workspace Cut, Copy, Paste (new layer; new image when none; oversized scaled) | `M/PhotoClipboard.swift`, `MT/PhotoClipboardTests.swift` | E-1 | ~330, 2 |
| E-4 | – | Duplicate Layer, Merge Down, Flatten Image and their help | `M/PhotoLayerOps.swift`, `MT/PhotoLayerOpsTests.swift` | E-2 | ~320, 2 |
| E-5 | – | Budgets PB-15, PB-16 on `large` | `MT/PhotoEditBudgetTests.swift` | E-3, E-4 | ~140, 1 |
| E-6 | – | `PhotoPasteboard` read and write | `A/PhotoPasteboard.swift`, `ST/PhotoPasteboardTests.swift` | E-1 | ~180, 2 |
| E-7 | – | Edit menu Cut, Copy, Paste with their help, the focus rule; the window's edit intents | `A/PhotoWindow+Edit.swift`, `A/PhotoCommands+Edit.swift` | E-3, E-6 | ~240, 2 |
| E-8 | – | Layer menu Duplicate (Command-J), Merge Down (Command-E), Flatten Image; "Merging…"; snapshots | `A/PhotoWindow+Edit.swift`, `A/PhotoCommands+Layer.swift`, `ST/PhotoEditSnapshots.swift` | E-4, E-7 | ~280, 3 |
| E-9 | – | Journeys PJ-5, PJ-6 | `UT/PhotoJourneyTests+Edit.swift` | E-8, photo-journey-kit | ~260, 1 |
| E-10 | – | Journey PJ-7 | `UT/PhotoJourneyTests+LayerOps.swift` | E-8, photo-journey-kit | ~180, 1 |

Chains: E-1 → E-2 (share `LiveEdit.swift`); E-7 → E-8 (share
`PhotoWindow+Edit.swift`). E-3, E-6 can run beside E-2; E-9 and E-10 run
side by side last.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| E-1 | `LiveClipboardTests`: copy of a rect over a layer with a transparent border trims to the opaque part and sets `source`; a half-coverage mask halves alpha; a fully transparent area gives nil; placement keeps an overlapping source, centers a nil source on `center`, and a source fully off the canvas is centered | the copy isn't trimmed, ignores the mask, or a placement lands off the canvas |
| E-2 | `LiveMergingTests`: PF-4, `PhotoRenderer.render` of the stack after Merge Down of `upper` (Screen, 60 %, offset 7, 5) onto Background equals `render` of the stack before it, bit for bit; `render` after Flatten of three layers with whole-image Exposure equals `render` before it (the adjustments reset in the same step), bit for bit; an adjustment `lower` throws the refusal; merged bounds cover both layers | a merge differs from the render by one bit, or an adjustment lower merges |
| E-3 | `PhotoClipboardTests`: PF-3, copy then paste in place equals the source inside the selection within 1/255, and exactly for an untouched opened 8-bit image; paste adds "Pasted Layer" above the selected layer and selects it, one "Paste" step; Cut clears the area, one "Cut" step; paste with no canvas opens an image of the pasted size, clean; a 6000 × 4000 image pastes as 5016 × 3344 (product ≤ 16,777,216) with "Pasted at 84%."; `nothingToCopyIsImmediate` (QB-F2): a transparent copy sets "Nothing to copy." in that same call; a paste adds a layer id never used before | a pixel drifts past 1/255, a paste takes two undo steps, or the oversized note is missing |
| E-4 | `PhotoLayerOpsTests`: Duplicate gives "Background copy" above, its tiles a copy (painting it leaves Background unchanged); Merge Down keeps lower's id and name and calls `layerGeometryChanged`; Flatten resets the whole-image adjustments; the three help texts for one layer and for an adjustment lower, on `.live` and on `.fake` | a duplicate shares tiles, a merge loses the lower id, or a help text is missing |
| E-5 | `PhotoEditBudgetTests`: PB-15 copy of a 12 MP layer and paste ≤ 120 ms release; PB-16 Merge Down of two 12 MP layers and Flatten of three ≤ 400 ms release; reported in debug | a release gate is missed locally, or a series has no samples |
| E-6 | `PhotoPasteboardTests` (macOS, a private named pasteboard): write then read gives the same 8-bit bytes; a TIFF-only pasteboard reads; an empty one gives nil and `hasImage == false` | an image doesn't round-trip, or a TIFF is missed |
| E-7 | V4 green; a snapshot-host check that Edit > Copy is disabled with "Open an image first." with no image; Command-C in the Image Size sheet's field, and in a focused panel text field, copies text (`PhotoSelectAllMenuTests`' approach) | the image steals Command-C from a field, or a disabled item has no help |
| E-8 | `PhotoEditSnapshots`: `photo-pasted-layer-light.png`, `-dark.png`; Command-J and Command-E are the items' shortcuts and Flatten Image has none; V10 green | a shortcut collides or is missing |
| E-9 | PJ-5 and PJ-6 pass on the macOS run, each step `shot` | any step's assertion fails |
| E-10 | PJ-7 passes, including the fixture step | any step's assertion fails |

## Quality tests

| quality row | budget | test |
|---|---|---|
| PB-15 copy and paste, 12 MP | ≤ 120 ms release, report debug; the new layer drawn ≤ 1 frame after (PB-1's path) | `PhotoEditBudgetTests.copyPaste` |
| PB-16 Merge Down, Flatten | ≤ 400 ms release, report debug; "Merging…" within 100 ms (report until #330) | `PhotoEditBudgetTests.mergeFlatten` |
| PF-3 | within 1/255 (note 1) | `PhotoClipboardTests.pasteInPlace` |
| PF-4 | the render after Merge Down and Flatten equals the render before, bit for bit | `LiveMergingTests` |
| QB-F1 | each new menu item changes the workspace or gives a reason | `PhotoLayerOpsTests.everyItemActsOrSaysWhy`, `PhotoClipboardTests.everyItemActsOrSaysWhy` |
| QB-F2 | a refusal is in `statusMessage` after the call that refused | `PhotoClipboardTests.nothingToCopyIsImmediate` |
| QB-F3 | one named step each: Cut, Paste, Duplicate Layer, Merge Down, Flatten Image | `PhotoClipboardTests`, `PhotoLayerOpsTests`, PJ-5 to PJ-7 |
| QB-F4 | Command-J, Command-E | E-8's shortcut check |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the
  `feature-done` PR is green: PJ-5, PJ-6, PJ-7, V1–V12.
- **Audit zero new:** no Photo count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey and the audit counts.
