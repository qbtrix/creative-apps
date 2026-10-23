# Feature packet: text-layers

**Feature:** type over a photo. Photo gets a **Type** tool (T): click to
place a text layer, type, press Esc or click away to commit. A text layer
holds its words and the suite's `TextStyle` (font, weight, italic, size,
colour, alignment, line height, letter spacing) and is drawn into pixels by
the shared glyph rasterizer every time it changes, so blend modes, opacity,
transform and export treat it like any layer. It saves into the `.ora` as its
pixels plus an AfterGlow text attribute, so it reopens editable in Photo and
shows as pixels in other OpenRaster editors. Selecting a text layer shows the
shared `TextStyleRows` in the inspector; double-clicking it edits the words.
Every action is a catalog command (`text.add`, `text.set-words` and the
suite's `text.*` style commands), one undo step each.
**Line:** `line:photo` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/text-layers`
**Beta:** captain, 2026-10-20 (everyday gaps, "Text in Photo is IN") and
2026-10-21 (beta gaps C11). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` C11 (Photo text layers);
Photo audit row 16 and under-specified 5; feature map E8, Photo adopter;
RJ-P02 (re-pointed here).

**Depends on** (cross-line, so in `waits_on` and the hand-offs, not `waits`):
suiteui **text-style** TS-a (the `TextStyle` value, `TextStyleTarget`,
`TextCommands` and the `TextStyleRows` signature; TX-1) and TS-m (the rules
and commands; TX-5); suite **shell-text** ST-a (`GlyphRasterizing` and
`FakeText`; TX-1) and ST-z (the live CoreText rasterizer; the journey and
RJ-P02). creative-core text engine #437 (built, at the pin).

**Hand-offs** (the lead checks each before its slice starts):
- **TX-u:** `PhotoWorkspace.swift` (the `PhotoTool.text` case) is also
  suiteui fill-heal FH-3's and the kernel adopts'; `PhotoPaletteTool.swift`
  is photo/eyedropper PE-a's and fill-heal FH-3's.
- **TX-m, TX-z:** Photo's catalog and `Tests/command-ids/photo.txt` follow
  the other Photo packets' last task on them (waits below on this line;
  suiteui adjust-everywhere AJ-photo and fill-heal FH-photo cross-line).
- **multi-layer-select PM-g** (group layers, the captain's call) now waits on
  TX-m for `PhotoLayer.swift` and `PhotoDocumentFile.swift` (re-cut in this
  PR), so the two new layer kinds land one after the other.

**Rule 20.** No Photo text model: the style is the kernel's `TextStyle`, the
layout the kernel's `TextStyleRules.layout`, the pixels shell-text's
`GlyphRasterizing`, the controls SuiteUI's `TextStyleRows` and font picker.
Photo keeps one adapter, `PhotoText+Kernel.swift`, and one file-format piece,
`PhotoTextLayer+ORA.swift`.

**Render path.** A style or words change re-rasterizes the layer's bounds once
on commit; a scrub (size, tracking, line height) re-rasterizes at most once per
display frame, into the layer's tiles, and the composite's damage covers only
those tiles.

**C4:** no new container or component; the new files sit in PhotoModel and
PhotoApp.

**Clean-room.** The Type tool's behaviour from the HIG and Photo's blueprint.
No task reads another product's code.

Blueprint sections: photo.md 4 (tools, layers), suite.md 2.

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (area-selection AR-photo-m, clipboard-interop CB-photo, orientation-crop OC-photo-m, document-setup DS-photo, brush-keys BK-photo) also edit `PhotoCommandCatalog.swift` and `Tests/command-ids/photo.txt`. The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| TX-a | Photo declares the text layer kind, its adapter onto the kernel's text style and the `text.add` and `text.set-words` commands as stubs, with the Model checks written and disabled. | TX-1, TX-2 | MJ-TX | suiteui text-style:TS-a and suite shell-text:ST-a (cross-line) |
| TX-u | Photo's palette has the Type tool, a click places an editable text box on the canvas, and the inspector shows the shared style row for a text layer, on the stubs, every control identified and within the render budget. | TX-3, TX-4 | PJ-TX | TX-a; gradient-fill:PG-a, multi-layer-select:PM-a (`PhotoWorkspace.swift`); eyedropper:PE-a (`PhotoPaletteTool.swift`); history-panel:PH-a (`PhotoPanel.swift`) |
| TX-m | A text layer rasterizes through the shared layout and glyph rasterizer, re-rasterizes on every edit as one undo step, and saves into the `.ora` as pixels plus a text attribute that reopens editable. | TX-5, TX-6 | MJ-TX | TX-a; file-flow:PF-m (Photo's catalog and ledger, the last on this line); suiteui text-style:TS-m (cross-line) |
| TX-z | The Type tool and the inspector run live end to end, RJ-P02 passes on macOS, and the feature is built. | TX-7, TX-8 | PJ-TX, MJ-TX | TX-u, TX-m; file-flow:PF-z (`photo.md`); suite shell-text:ST-z (cross-line) |

**Screen early.** TX-u builds the Type tool and the inspector on TX-a's stubs
and waits on no slice of this feature but TX-a, beside TX-m.

**Shared files.** `PhotoLayer.swift` and `PhotoDocumentFile.swift`: TX-a
and TX-m first, then multi-layer-select's PM-g (re-cut). Photo's catalog and ledger:
TX-5 follows the other Photo packets' last owner (the waits data).

## Journey steps

`MJ-TX` on Linux (`PhotoTextLayerTests`, `PhotoTextORATests`), then:
1. Open `beach.png`, press T, click the sky, type SUMMER SALE, Esc: a text layer above the photo (TX-3, TX-7).
2. In the inspector pick a heavy weight, size 120, Center; the text redraws; Undo steps back one control at a time (TX-4, TX-7).
3. Save, close, reopen: the layer is still text; double-click it, change SALE to DEALS (TX-6, TX-7; `PJ-TX`, `PhotoTextJourneyTests.testTitleOverPhoto`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P02 | closes (re-pointed to `photo/text-layers`; `needs` keep E8, add `suiteui/text-style`) | Cm | `Tests/RealJobs/photo/sale-title/`: `text.add` "SUMMER SALE" at the centre, `text.set-font` a bundled family weight 900, `text.set-size` 120, `text.set-alignment` center, `file.save` then reopen, `file.export` PNG | its existing `beach.png` |

Trap: the title is set but the file keeps only pixels, so the next session
can't fix a typo (or the export drops the layer). Assertion: after reopen
`text.read` returns the words and weight 900; the export has ink in the
centre band and none outside the measured box. Mutation:
`PhotoModel.PhotoTextLayer+ORA` (`.reopensEditable`). TX-7 enables the check
once shell-text's live rasterizer has merged.

## Screens and states

`photo-text-editing` (the in-place box with a caret), `photo-text-inspector`
(the style row for a text layer), `photo-text-done` (the title over the photo).

## Contract slice

```swift
// Sources/PhotoModel/PhotoTextLayer.swift (TX-1)
public struct PhotoTextLayer: Hashable, Sendable, Codable {
    public var words: String
    public var style: TextStyle                     // SuiteKernel
    public var origin: Mask.Point                   // the box's top-left, canvas pixels
    public var boxWidth: Double?                    // nil: one line per paragraph, no wrap
}
// Sources/PhotoModel/PhotoLayer.swift (TX-1)
public enum PhotoLayerKind: Hashable, Sendable { case pixels, adjustment(AdjustmentSettings), text(PhotoTextLayer) }
// Sources/PhotoModel/PhotoText+Kernel.swift (TX-2 stubs, TX-5 bodies)
extension PhotoWorkspace: TextStyleTarget { /* textStyle, textHelp, faces(of:), setTextStyle */ }
extension PhotoWorkspace {
    public struct TextAddParams: Codable, Sendable { public var x, y: Int; public var words: String; public var style: TextStyle? }
    public struct TextWordsParams: Codable, Sendable { public var words: String }
    static var textCommands: [CommandSpec<PhotoWorkspace>] { get }   // text.add, text.set-words + TextCommands.specs
}
```

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `text.add` | Add Text | `{x, y, words, style?}` | no image |
| `text.set-words` | Edit Text | `{words}` | no text layer selected; empty words |
| `text.*` (the kernel's seven) | as in `suiteui/text-style` | as there | no text layer selected |

## Pseudocode

- **Rasterize.** `TextStyleRules.layout(words, style, advances:)` with the
  advances from `services.text.measure`; the layout's bounds padded by 2 px
  give the layer's box; `GlyphRasterizing.draw` of the placed spans fills it;
  the pixels go into the layer's tiles in linear premultiplied form (Photo's
  layer format).
- **Edits.** Every text command replaces the layer's `PhotoTextLayer` and its
  pixels in one `History` step; a scrub under one drag token folds.
- **File.** The `.ora` stack entry keeps `src` (the PNG) and adds
  `afterglow:text` (JSON of `PhotoTextLayer`); on read, a valid attribute
  makes a text layer, else a pixel layer, never an error.
- **Commit.** The overlay's text field commits on Esc, Return with ⌘, or a
  click outside; an empty field on a new layer removes it, as one step.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| TX-1 | – | **Checks first, then the kind.** `PhotoTextLayerTests` and `PhotoTextORATests` written, disabled by name (`waits on TX-5`, `TX-6`); `PhotoLayerKind.text(PhotoTextLayer)` with `PhotoTextLayer` (words, `TextStyle`, origin, box width); `PhotoDocumentFile` reads and writes the case through a stub that refuses with `NotBuilt` | `Sources/PhotoModel/PhotoLayer.swift`, `Sources/PhotoModel/PhotoTextLayer.swift`, `Sources/PhotoModel/PhotoDocumentFile.swift`, `Tests/PhotoModelTests/PhotoTextLayerTests.swift`, `Tests/PhotoModelTests/PhotoTextORATests.swift` | – | ~200, 5 |
| TX-2 | – | `PhotoText+Kernel.swift` conforms `PhotoWorkspace` to `TextStyleTarget` (stubbed bodies) and declares `text.add` and `text.set-words` specs with real ids, schemas and availability; `PhotoTextJourneyTests` written, skipped until TX-7 | `Sources/PhotoModel/PhotoText+Kernel.swift`, `UITests/PhotoJourneyTests+Text.swift` | TX-1 | ~140, 2 |
| TX-3 | – | **Reachable first.** `PhotoTool.text` in the palette (T); a click on the canvas opens an in-place text box (a SwiftUI text field over the canvas at the zoom), Esc or a click away commits through `text.add` (unavailable on the stubs with "Text arrives with TX-5.") | `Sources/PhotoModel/PhotoWorkspace.swift`, `Sources/PhotoApp/PhotoPaletteTool.swift`, `Sources/PhotoApp/PhotoTextEditorOverlay.swift` | TX-2 | ~200, 3 |
| TX-4 | – | The inspector shows `TextStyleRows` for a text layer (the font list from `services.text`); double-click a text layer edits its words; render budget test | `Sources/PhotoApp/PhotoTextInspector.swift`, `Sources/PhotoApp/PhotoPanel.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoTextTests.swift` | TX-3 | ~170, 3 |
| TX-5 | – | `PhotoText+Kernel` bodies: `text.add`, `text.set-words` and the kernel's text specs; each edit lays out with `TextStyleRules.layout` (advances from `services.text`), rasterizes through `GlyphRasterizing` into the layer's tiles, one undo step; the catalog appends the specs; ids in the ledger; turns on `PhotoTextLayerTests` | `Sources/PhotoModel/PhotoText+Kernel.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/PhotoModelTests/PhotoTextLayerTests.swift`, `Tests/mutations/PhotoModel.PhotoText+Kernel.json` | TX-2 | ~250, 5 |
| TX-6 | – | `PhotoTextLayer+ORA.swift`: a text layer saves as its PNG plus an `afterglow:text` attribute (words and style JSON); reading it restores an editable layer; another editor's file without it reads as pixels; turns on `PhotoTextORATests` | `Sources/PhotoModel/PhotoTextLayer+ORA.swift`, `Sources/PhotoModel/PhotoDocumentFile.swift`, `Tests/PhotoModelTests/PhotoTextORATests.swift`, `Tests/mutations/PhotoModel.PhotoTextLayer+ORA.json` | TX-1 | ~160, 4 |
| TX-7 | – | The window on live: the overlay commits through `text.add`, the inspector's intents run the kernel's commands; `PhotoTextJourneyTests` on; RJ-P02 re-pointed and enabled | `Sources/PhotoApp/PhotoWindow+Text.swift`, `UITests/PhotoJourneyTests+Text.swift`, `Tests/RealJobs/photo/sale-title/sale-title.jobs.json` | TX-4, TX-5, TX-6 | ~150, 3 |
| TX-8 | – | `status: built`; `feature-done`; the blueprint's tools section names the Type tool | `docs/blueprints/photo/features/text-layers.wave.json`, `docs/blueprints/photo.md` | TX-7 | ~20, 2 |

## Build waves

- Wave 1: TX-1. Independent in this wave: TX-1 alone.
- Wave 2: TX-2, TX-6. Independent in this wave: both.
- Wave 3: TX-3, TX-5. Independent in this wave: both.
- Wave 4: TX-4. Independent in this wave: TX-4 alone.
- Wave 5: TX-7. Independent in this wave: TX-7 alone.
- Wave 6: TX-8. Independent in this wave: TX-8 alone.

Longest chain: TX-1 → TX-2 → TX-3 → TX-4 → TX-7 → TX-8 (6). Chain of 6: the kind before the adapter, the adapter before the tool and the commands, both before the live window, and the window before the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| TX-1 | the suites compile, disabled by name; every existing `.ora` fixture opens unchanged | an existing layer kind decodes differently | – (stubs) |
| TX-2 | compiles; the specs list with their schemas | a spec the window calls is missing | – (stubs) |
| TX-3 | the tool and the overlay exist with their ids; T selects it | the tool has no key or the overlay no id | – (view; render budget row) |
| TX-4 | `RenderBudgetPhotoTextTests.typeTwentyCharsInThreeBodiesEach` | a keystroke re-renders the whole window | – (view; render budget row) |
| TX-5 | `PhotoTextLayerTests` (FakeText): `text.add` makes one text layer above the selected one, one step; a size change re-rasterizes the bounds; undo restores the old pixels and style; the layer blends and transforms like a pixel layer | an edit doesn't re-rasterize, or undo leaves new pixels | `PhotoModel.PhotoText+Kernel`: re-rasterize skipped on a style change → `.styleChangeRedraws`; undo keeps the new style → `.undoRestoresStyle` |
| TX-6 | `PhotoTextORATests`: save and reopen keeps words and style; the stack's PNG equals the rasterized pixels; an attribute with an unknown style key opens with defaults for it | a text layer reopens as pixels, or an unknown key fails the open | `PhotoModel.PhotoTextLayer+ORA`: attribute not written → `.reopensEditable`; strict decode → `.unknownKeyTolerated` |
| TX-7 | `PJ-TX`; RJ-P02 (`Cm`) | the canvas shows text the file doesn't keep, or the inspector edits the wrong layer | – (window wiring) |
| TX-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: typing 20 characters into a text box on an 8K photo | ≤ 3 window bodies per keystroke; keystroke to pixels p95 ≤ 16 ms | `RenderBudgetPhotoTextTests.typeTwentyCharsInThreeBodiesEach` |
| render: size scrub on a text layer | 120-sample drag ≤ 3 window bodies | `RenderBudgetPhotoTextTests.sizeScrub` |
| one gesture, one step | add, edit words, each style control | `PhotoTextLayerTests` |
| no dead controls | the tool and every row are catalog commands | `CommandPathTests` |
| keyboard parity | T, Esc to commit, ⌘B and ⌘I in the box | `PhotoTextJourneyTests` |
| behaviour preserved | every existing `.ora` fixture opens and re-saves unchanged | `PhotoTextORATests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): TX-a and TX-m green on Linux with
`Mutate:` scores clean; TX-u and TX-z through the feel gate (`mouse`, `taste`:
add a title, restyle it, reopen it) with their `Mac-Finish:` lines; RJ-P02
green in the scoped macOS run. Then `Belt-Contact-Sheet:`.
