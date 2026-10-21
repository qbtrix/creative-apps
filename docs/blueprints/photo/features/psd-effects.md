# Feature packet: psd-effects (Photo)

**Feature:** Photo opens a layered PSD as layers, and the layer effects in it
arrive as editable layer styles. File > Open (and `doc.open` on the CLI)
takes `.psd`: each pixel layer keeps its name, place, opacity, blend mode,
visibility, clipping, mask and effects; drop and inner shadows, glows,
strokes, colour and gradient overlays and bevel and emboss become the
layer's `LayerStyle` through the shared mapping; Linear Dodge and Linear
Burn open as themselves. Anything the reader or the mapping can't keep
(satin, pattern overlay, a second instance of an effect, a text or
adjustment layer's live settings) is named in the open's warning, never
dropped silently. This fixes findings #3496 and #3497.
**Line:** `line:photo` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/psd-effects`
**Beta:** captain, 2026-10-21 (PSD import keeps layer effects). Labels `beta`
and `p1` when filed.

**Covers:** findings #3496 (PSD import drops layer effects) and #3497 (PSD
import turns unknown blend modes into Normal; Linear Dodge and Linear Burn);
feature map `photo/psd-effects` (new; part of E10's Photo adopter); real job
RJ-P46 (new). PSD save stays out (RJ-P09 keeps its row).

**Depends on:** creative-core `layer-style-engine` **LE-psd** (the reader
fills `PixelLayer.style` from `lfx2` and lists what it dropped in
`LayeredImage.notes`; `BlendMode.linearDodge` and `.linearBurn` with their
PSD keys) through a `scripts/bump-core` PR, before PS-3 and PS-4 (cross-line;
that bump also adds the two new cases to Halo's exhaustive blend switches,
`HaloViewerCanvas.swift` and `HaloKeying.swift`, as the core packet says);
`suiteui/layer-styles` **LS-m** (`StyleProgram.style`, cross-line) before
PS-3. Same line: `masks-clipping` **PK-m** (the last owner of
`PhotoDocumentFile.swift` and the mask and clip flags PS-3 sets) and
`layer-styles` (`PhotoLayer.style`); `export-pack` **PX-m**
(`PhotoHeadless.swift`) and `file-flow` **PF-m** (`PhotoWindow+File.swift`).

**Rule 20.** No Photo PSD reader and no Photo effect mapping: the reader is
core's `PSD.read`, and the effect-to-style mapping is SuiteImaging's
`StyleProgram.style`, which any other app that opens a PSD reuses.
`PhotoLayered+Imaging.swift` is only the adapter from core's `LayeredImage` to
Photo's layers.

**Render path.** None new. An opened PSD is a Photo document; its styles draw
through `photo/layer-styles`' composite and route.

Blueprint sections: photo.md 4 (Files), 9 (formats).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PS-a | The fidelity corpus writes a real `lfx2` descriptor, the PSD-open tests and RJ-P46's job are written and disabled, and Photo's open types list `.psd` with a stub that refuses with "Opening PSD files is not built yet (PS-3)." | PS-1, PS-2 | MJ-PS | masks-clipping:PK-m; export-pack:PX-m; file-flow:PF-m |
| PS-m | A PSD opens as Photo layers with their masks, clipping and effects as layer styles, Linear Dodge and Linear Burn open as themselves and round-trip the `.ora`, and every dropped item is named in the open's warning. | PS-3, PS-4 | MJ-PS | PS-a; core LE-psd bump and LS-m (cross-line) |
| PS-z | The two findings' known issues are gone from the fidelity gate, RJ-P46 passes, and the feature is built. | PS-5, PS-6 | MJ-PS | PS-m; masks-clipping:PK-z (PS-6, `photo.md`) |

`"ui_slice"` is not `none`: PS-a adds `.psd` to the Open panel's types (one
`PhotoApp` line), so it is `"ui": true`; the panel and its warning sheet are
the existing ones, so there is no new screen and no render budget row beyond
the open's. MJ-PS is `PhotoPSDOpenTests` and `ImportFidelityPSDTests` on
Linux.

## Journey steps

Model walks only (`journeys_none`: the Open panel and warning sheet are
unchanged and covered by Photo's file journeys):
1. `PhotoPSDOpenTests.opensLayerEffects` (PS-3): `layer_effects.psd` opens
   with one layer "Badge" whose style holds a 3 px outside crimson stroke;
   `style.read` shows it; `style.set` changes its width.
2. `PhotoPSDOpenTests.blendKeys` (PS-4): `blend_extended.psd` opens with
   "Linear dodge" in `.linearDodge` and "Linear burn" in `.linearBurn`; saved
   as `.ora` and reopened, both keep their modes.
3. `PhotoPSDOpenTests.namesWhatItDrops` (PS-3): a satin effect and a second
   drop shadow come back in the open's warning as "Badge: satin (not kept)",
   "Badge: second drop shadow (not kept)".

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P46 | adds, closes with `photo/psd-effects` | C | `Tests/RealJobs/photo/psd-effects/psd-effects.jobs.json`: `doc.open` a PSD with a drop shadow and a stroke on a badge, `style.set {kind: dropShadow, distance: 12}`, `file.export` PNG | `input/badge-effects.psd` (written by `Tests/import_fidelity/gen.py`) |

Trap: the effects open flattened into pixels (not editable), or they vanish
and the badge opens bare with no warning. Assertion: `style.read` after open
lists exactly dropShadow and stroke; after the edit, the PNG's shadow centroid
sits 12 px from the badge's along the PSD's angle (y down) within 1 px.
Mutations: `PhotoModel.PhotoLayered+Imaging.json` (style not carried onto the
layer → `.effectsAreEditable`; notes not joined into the warning →
`.dropsAreNamed`).

## Screens and states

None new: the Open panel lists PSD; an import with drops shows the existing
open-warning sheet with the named items.

## Contract slice

```swift
// Sources/PhotoModel/PhotoLayered+Imaging.swift (PS-2 stub throwing NotBuilt, PS-3 body)
extension PhotoWorkspace {
    /// The workspace for a layered file: layers back to front with masks, clipping and styles; `warnings` names
    /// every drop (core's notes plus StyleProgram.style's `dropped`), "<layer>: <what> (not kept)".
    public static func opening(_ image: LayeredImage) throws -> (workspace: PhotoWorkspace, warnings: [String])
}
```

## Pseudocode

- **Layers.** Walk `LayeredImage.nodes` back to front: a `PixelLayer` becomes
  an image layer at (x, y) with its opacity, blend, hidden flag, `isClipped`
  (from `clipsToBelow`), its mask (a `PlacedMask`, moved to the layer's place,
  disabled flag kept) and `style = StyleProgram.style(pixelLayer.style).0`. A
  group opens as Photo's group where `multi-layer-select` PM-g has built it,
  otherwise its children are flattened into the parent's list with the
  warning "<group>: group opened as separate layers".
- **Blend.** `BlendMode` comes straight from core; Photo's blend menu lists
  `BlendMode.allCases`, so the two new modes appear with no Photo list to
  edit; `photo/document.json` stores the raw value, so the `.ora` keeps them.
- **Warnings.** core's `notes` plus each layer's `dropped`, in layer order,
  joined into the open's warning; a file with nothing dropped shows none.
- **Corpus.** `gen.py`'s `layer_effects.psd` writes a real `lfx2` block (the
  published Photoshop file format's object-based effects descriptor: version
  0, descriptor version 16, an `FrFX` stroke, a `DrSh` drop shadow, and a
  `ChFX` satin the reader must name), replacing today's 24 zero bytes; the
  merged image it stores is drawn with the same effect rules, so the gate
  compares within its tolerance (edge pixels within 8 levels for effect
  layers, the gate's 2 elsewhere).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PS-1 | #3496, #3497 | Checks first: `gen.py` writes the real `lfx2` descriptor and `badge-effects.psd`, the corpus regenerated; `PhotoPSDOpenTests` written, disabled; `ImportFidelityPSDTests` flattens with styles (still under the two known issues); RJ-P46's job folder, disabled (`waits_on: PS-3`) | `Tests/import_fidelity/gen.py`, `Tests/import_fidelity/manifest.json`, `Tests/import_fidelity/psd/layer_effects.psd`, `Tests/PhotoModelTests/ImportFidelityPSDTests.swift`, `Tests/PhotoModelTests/PhotoPSDOpenTests.swift`, `Tests/RealJobs/photo/psd-effects/psd-effects.jobs.json`, `Tests/RealJobs/photo/psd-effects/input/badge-effects.psd` | – | ~340, 7 |
| PS-2 | – | `PhotoLayered+Imaging.swift` as a stub; `.psd` in the headless document's `openExtensions` and the Open panel's types, routed to the stub | `Sources/PhotoModel/PhotoLayered+Imaging.swift`, `Sources/PhotoModel/PhotoHeadless.swift`, `Sources/PhotoModel/PhotoDocumentFile.swift`, `Sources/PhotoApp/PhotoWindow+File.swift` | – | ~120, 4 |
| PS-3 | – | `opening(_:)`'s body: layers, masks, clipping, styles, groups, warnings; turns on `PhotoPSDOpenTests` but `blendKeys` | `Sources/PhotoModel/PhotoLayered+Imaging.swift`, `Tests/PhotoModelTests/PhotoPSDOpenTests.swift`, `Tests/mutations/PhotoModel.PhotoLayered+Imaging.json` | PS-1, PS-2, LE-psd bump, LS-m | ~320, 3 |
| PS-4 | – | The two blend modes in Photo's `.ora` (an unknown raw value opens as Normal with a warning, never silently) and the blend menu's tests; turns on `blendKeys` | `Sources/PhotoModel/PhotoDocumentFile.swift`, `Tests/PhotoModelTests/PhotoBlendModeTests.swift`, `Tests/mutations/PhotoModel.PhotoDocumentFile.json` | PS-3 | ~140, 3 |
| PS-5 | – | Drops the two gaps from `gen.py`'s manifest and regenerates, so `ImportFidelityPSDTests` runs both files as errors, not known issues; `Fixes #3496`, `Fixes #3497` | `Tests/import_fidelity/gen.py`, `Tests/import_fidelity/manifest.json`, `Tests/import_fidelity/psd/blend_extended.psd` | PS-3, PS-4 | ~40, 3 |
| PS-6 | – | photo.md: PSD open with effects in Files; `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/psd-effects.wave.json` | PS-5 | ~20, 2 |

## Build waves

- Wave 1: PS-1, PS-2. Independent in this wave: both.
- Wave 2: PS-3. Independent in this wave: PS-3 alone.
- Wave 3: PS-4. Independent in this wave: PS-4 alone.
- Wave 4: PS-5. Independent in this wave: PS-5 alone.
- Wave 5: PS-6 (shared prose, `feature-done`, final). Independent in this wave: PS-6 alone.

Longest chain: PS-1 → PS-3 → PS-4 → PS-5 → PS-6 (5). Chain of 5: the
open needs its tests and the corpus, the blend test opens through it, the
gaps go only once both pass, PS-6 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PS-1 | `python3 Tests/import_fidelity/gen.py` is deterministic (a second run changes no byte); the new suite compiles, disabled; `ImportFidelityPSDTests` still passes under its known issues; `scripts/jobs check` | the corpus drifts or a check is missing | – (tests only) |
| PS-2 | Photo's Model tests; opening a `.psd` refuses with the stub's reason | a PSD opens as a flat picture with no reason | – (stub) |
| PS-3 | `PhotoPSDOpenTests.opensLayerEffects`, `.namesWhatItDrops`, `.masksAndClipping` (a clipped layer and a masked layer open with their flags), `.groupsFlatten`; RJ-P46 passes on Linux | an effect is baked or lost, a drop is silent, or a flag is lost | `PhotoModel.PhotoLayered+Imaging`: style not carried → `.effectsAreEditable`; notes not joined → `.dropsAreNamed`; `clipsToBelow` ignored → `.masksAndClipping` |
| PS-4 | `PhotoBlendModeTests`: both modes survive an `.ora` round trip; the blend menu's list is `BlendMode.allCases` | a mode saves as Normal | `PhotoModel.PhotoDocumentFile`: unknown raw value decoded as `.normal` silently → `.newModesRoundTrip` |
| PS-5 | `ImportFidelityPSDTests` with no `withKnownIssue` for #3496 and #3497 | either file still differs | – (data) |
| PS-6 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Open a 20-layer 4K PSD with effects | ≤ 1.5 s to the first draw (release, reported) | `PhotoPSDOpenTests.twentyLayerCost` |
| Never silent | every dropped item named in the open's warning | `PhotoPSDOpenTests.namesWhatItDrops`, the fidelity gate |
| One step | opening is not an undo step; the first edit is | `PhotoPSDOpenTests.opensLayerEffects` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 17, 21): PS-m merged-done on the Linux job with
`Mutate:` clean and RJ-P46 green there; PS-a's one App line through the Mac
finisher (`Mac-Finish:`); PS-z with the fidelity gate free of #3496 and
#3497, both closed by PS-5's merge. Then `Belt-Contact-Sheet:` with the
opened badge's snapshot.

## Not in this packet

PSD save (layers or effects; RJ-P09), editable text and adjustment layers
from a PSD (they open as pixels with a warning), satin, pattern overlay and
contour, more than one instance of an effect, 16-bit effects beyond what core
reads.
