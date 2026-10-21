# Feature packet: text-style

**Feature:** one way to set type across the suite. SuiteKernel gets a `Text/`
module: `TextStyle` (family, weight, italic, size, colour and FlareCore's
`ParagraphStyle`: alignment with **justified**, **line height**, **letter
spacing** as tracking, paragraph spacing and box width), the rules that
validate it against FlareCore's format ranges, a layout call over FlareCore's
`TextLayout` that takes measured advances, and the text commands every app
registers. SuiteUI gets one `TextStyleRows` view: the font picker
(`font-picker`), weight and italic, size, the four alignment buttons, Line
Height and Letter Spacing scrub rows. The rows never edit a document: they
emit `TextIntent`s, each a text command. Design adopts it on its text layers
(gaining italic, justify, line height and letter spacing, and refitting the box
when the font changes, #3339); Halo on its text layers (gaining font, weight,
italic, alignment, line height, letter spacing and more than one line).
Photo's text layers are their own packet, `photo/text-layers`, on this one.
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps) · **Lead branch:** `lead/text-style`
**Beta:** captain, 2026-10-21 (beta gaps cluster C11). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` C11; Design audit
"under-specified" 2 (no Design text packet; italic and justify missing);
Halo audit item 10; feature map E8 (Design and Halo adopters); finding #3339;
RJ-H04 (re-pointed here) and RJ-D50 (new).

**Depends on:** font-picker **FP-a** (the `FontPicker` signature; TS-2) and
**FP-u** (the real picker; TS-3); creative-core at the pin `2258b62` (text
engine #437, built): `ParagraphStyle`, `TextAlignment.justified`,
`TextLayout`, `ResolvedRun.italic` and `.tracking`. Cross-line: suite
`shell-text` (planned) gives the measured advances (`TextMeasuring`) and the
font list (`FontListing`); until its ST-z lands the adopters measure with
`FakeText`'s fixed advances, and the journeys wait on it.

**Hand-offs** (cross-line; the lead checks each before its slice starts):
- **TS-design:** `StyleTypes.swift` is design/pen-paths DP-a's and
  stroke-style DK-m's; `DesignTextFont.swift`, `DesignTextArtwork.swift` and
  `DesignInspectorText.swift` are design/style-rows SR-t's and
  design-window DW-a's; `DesignCommandCatalog.swift` and
  `Tests/command-ids/design.txt` follow the design packets' last task on them.
- **TS-halo:** `HaloTextInspector.swift` and `HaloTextRasterizer.swift` have
  no other open owner; `HaloTextEdits.swift` is Halo's own text packet's
  (built).

**Rule 20.** One text model. FlareCore already holds the paragraph
(`ParagraphStyle`) and the run (`ResolvedRun`), and shell-text's `TextSpan`
the measured span, so the kernel adds only `TextStyle`, which wraps
`ParagraphStyle` and adds the run fields, and no fourth set of names.
`DesignTextAlignment` becomes a typealias of FlareCore's `TextAlignment`
(same raw values, plus `justified`), so old files decode unchanged; Design's
`DesignTextStyle` keeps its file keys behind `DesignTextStyle+Kernel.swift`.
Halo's `HaloTextContent` gains a `style: TextStyle` field. Each app draws with
its own CoreText rasterizer (an adapter onto the shared layout, not a copy).

**C4:** a new component part `suite-kernel/kernel-text.json`
(`Sources/SuiteKernel/Text/`; TS-1). `TextStyleRows.swift` is a new file in
`suiteui-sources`.

**Clean-room.** Control names and ranges from the HIG and the apps'
blueprints; the line maths is FlareCore's. No task reads another product's
code.

Blueprint sections: design.md (text layers), halo.md (text layers), suite.md 2.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| TS-a | The kernel declares the text style, its rules, layout and commands, and SuiteUI the style row, as stubs, with the Model checks written and disabled. | TS-1, TS-2 | MJ-TS | font-picker:FP-a (TS-2) |
| TS-u | Design's and Halo's text inspectors show the shared style row on the stubs, reachable by selecting a text layer, every control identified and within the render budget. | TS-3, TS-4 | DJ-TS, HJ-TS | TS-a; font-picker:FP-u |
| TS-m | The style validates against FlareCore's ranges, the layout sets line height, letter spacing, italic and justify from measured advances, and every text command is one undo step. | TS-5, TS-6 | MJ-TS | TS-a |
| TS-design | Design's text layers take italic, justify, line height and letter spacing through the catalog, old files open unchanged, and a font change refits the box (#3339). | TS-7, TS-8 | DJ-TS, MJ-TS-design | TS-m, TS-u; adopt-command-catalog:AC-design (built; Design's catalog); brush-keys:BK-design (shared app file) |
| TS-halo | Halo's text layers take a font, weight, italic, alignment, line height, letter spacing and several lines through the catalog, drawn the same in the viewer and the render, and the feature is built. | TS-9, TS-10, TS-11, TS-12 | HJ-TS, MJ-TS-halo, MJ-TS, DJ-TS | TS-design, TS-m, TS-u; adopt-kernel-easing:AE-halo (`HaloValues.swift`); adjust-everywhere:AJ-halo (Halo's catalog and ledger); anchor-parenting:AN-halo (shared app file) |

**Screen early.** TS-u puts the real row in both apps' inspectors on TS-a's
stubs and waits on no slice of this feature but TS-a (and the real picker,
font-picker FP-u), beside TS-m. TS-a is `"ui": true` because TS-2 adds the
row's placeholder to SuiteUI.

**Shared files.** `HaloValues.swift` follows adopt-kernel-easing's AE-halo, and
Halo's catalog and ledger follow adjust-everywhere's AJ-halo, on this line.

## Journey steps

Linux walks first (`MJ-TS`: `TextStyleRulesTests`, `TextStyleLayoutTests`,
`TextCommandsTests`; `MJ-TS-design`: `DesignTextStyleTests`; `MJ-TS-halo`:
`HaloTextStyleTests`), then the journeys on the scoped run:
1. Design: select a text box, pick a family in the font picker, set Italic, Justify, Line Height 1.5 and Letter Spacing 20; the canvas reflows; a family change refits the box; Undo steps back one control at a time (TS-3, TS-8; `DJ-TS`, `DesignTextStyleJourneyTests.testParagraphStyle`).
2. Halo: add a text layer, type two lines, pick a family and Bold, tracking 50, centre; scrub and render a frame; both show the same two lines (TS-4, TS-10; `HJ-TS`, `HaloTextStyleJourneyTests.testTitleCard`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H04 | closes (re-pointed to `suiteui/text-style`; `needs` keep E8) | Cm | `Tests/RealJobs/halo/title-card/`: `text.set-font` a bundled family Bold, `text.set-tracking` 50, two lines, `text.set-alignment` center, `render.frame` | a new comp |
| RJ-D50 | adds, closes with `suiteui/text-style` | Cm | `Tests/RealJobs/design/paragraph-style/`: a 300 pt wide box, three lines of text, `text.set-alignment` justified, `text.set-line-height` 1.5, `text.set-tracking` 20, `text.set-italic`, `file.export` PNG | a new page |

Traps and assertions. RJ-H04: the second line is dropped or overlaps the
first; the render has two separate ink bands whose gap matches 1.2 × the
measured line within 2 px, and a bold face's stems are wider than the regular
fixture's. RJ-D50: line height or justify is set in the inspector but the
export ignores it; the first two lines' ink spans the box's width within 2 px,
the last line doesn't, and the baseline gap is 1.5 × (ascent + descent) within
1 px. Mutations: `SuiteKernel.TextStyleRules` (`.lastLineNotJustified`,
`.lineHeightClamps`). TS-8 and TS-10 write and enable the checks; both need
shell-text's live measurer, so they stay disabled with `waits_on` until it.

## Screens and states

`suiteui-text-style-rows` (defaults; Justify selected), `design-text-justified`
(three justified lines at 1.5), `halo-text-two-lines` (a centred two-line
title, Bold, tracking 50).

## Contract slice

```swift
// Sources/SuiteKernel/Text/TextStyle.swift (TS-1 values, TS-5 coding). Foundation and FlareCore only.
public struct TextStyle: Hashable, Codable, Sendable {
    public var family: String                    // a FontListing family name; "System" the system font
    public var weight: Int                       // 100...900
    public var italic: Bool
    public var size: Double                      // points, 1...1600
    public var rgba: [UInt8]
    public var paragraph: ParagraphStyle          // FlareCore: alignment (incl. .justified), lineHeight, tracking,
                                                 // paragraphSpacing, boxWidth
    public static let standard: TextStyle        // System, 400, upright, 24 pt, leading, 1.2, 0
}
// Sources/SuiteKernel/Text/TextStyleRules.swift (TS-1 stubs, TS-5 bodies)
public enum TextField: String, CaseIterable, Codable, Sendable { case size, lineHeight, tracking }
public enum TextStyleRules {
    public static func range(_ f: TextField) -> ClosedRange<Double>   // size 1...1600; lineHeight 0.5...4; tracking −100...500
    public static func setting(_ s: TextStyle, _ f: TextField, to v: Double) -> TextStyle   // clamped; NaN keeps
    /// FlareCore's layout with `advances(span)` from the app's measurer (shell-text's TextMeasuring or FakeText).
    public static func layout(_ string: String, style: TextStyle,
                              advances: ([String]) -> (advances: [Double], ascent: Double, descent: Double)) -> TextLayout
}
// Sources/SuiteKernel/Text/TextCommands.swift (TS-1 specs, runs throwing NotBuilt; TS-6 bodies)
public protocol TextStyleTarget: Sendable {
    var textStyle: TextStyle? { get }                       // nil: no text layer selected
    var textHelp: String? { get }
    func faces(of family: String) -> [(weight: Int, italic: Bool)]   // for the nearest-face rule
    mutating func setTextStyle(_ s: TextStyle, name: String, drag: String?) throws
}
public enum TextIntent: Hashable, Sendable {
    case font(family: String, weight: Int, italic: Bool), size(Double, drag: String?),
         alignment(TextAlignment), lineHeight(Double, drag: String?), tracking(Double, drag: String?)
    public var command: (id: String, params: JSONValue) { get }
}
public enum TextCommands { public static func specs<T: TextStyleTarget>(_ t: T.Type) -> [CommandSpec<T>] }
// Sources/SuiteUI/TextStyleRows.swift (TS-2)
public struct TextStyleRows: View {
    public init(style: TextStyle?, families: [FontFamily], help: String?, onIntent: @escaping (TextIntent) -> Void)
}
```

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `text.read` | – (query) | – → the style | `textHelp` |
| `text.set-font` | Font | `{family, weight?, italic?}` | `textHelp`; an unknown family |
| `text.set-size` | Text Size | `{size, drag?}` | `textHelp` |
| `text.set-italic` | Italic | `{on}` | `textHelp`; the family has no italic face ("This family has no italic.") |
| `text.set-alignment` | Alignment | `{alignment}` (leading, center, trailing, justified) | `textHelp` |
| `text.set-line-height` | Line Height | `{value, drag?}` | `textHelp` |
| `text.set-tracking` | Letter Spacing | `{value, drag?}` | `textHelp` |

## Pseudocode

- **Layout.** Split the string into graphemes and paragraphs; ask the app's
  measurer for each run's advances; hand FlareCore `TextLayout` the
  `ParagraphStyle` with tracking converted from thousandths of an em to
  points at the style's size. Justify spreads each wrapped line's slack over
  its inter-word gaps; the last line of a paragraph and a line with one word
  keep their alignment's leading edge (FlareCore's rule).
- **Nearest face.** On a family change keep the weight and italic if the new
  family has them, else the nearest weight (ties go lighter), italic only if
  it exists; font-picker's `nearestFace` gives the same answer, and
  `TextCommandsTests` holds both against one fixture.
- **Refit (#3339).** In Design an auto-width box re-measures on any font,
  size or tracking change and keeps its leading edge (or centre, or trailing
  edge, by alignment); a fixed-width box keeps its width and reflows.
- **Halo lines.** The words field keeps newlines; the layer's measured box is
  the layout's bounds, so the viewer's handles, the timeline's thumbnail and
  the render all use the same lines.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| TS-1 | – | **Checks first, then the stubs.** `TextStyleRulesTests`, `TextStyleLayoutTests` and `TextCommandsTests` written, disabled by name; `TextStyle`, `TextStyleRules`, `TextStyleLayout`, `TextStyleTarget`, `TextIntent` and `TextCommands` (real ids, schemas and availability, runs throwing `NotBuilt`); the C4 part | `Sources/SuiteKernel/Text/TextStyle.swift`, `Sources/SuiteKernel/Text/TextStyleRules.swift`, `Sources/SuiteKernel/Text/TextCommands.swift`, `Tests/SuiteKernelTests/TextStyleRulesTests.swift`, `Tests/SuiteKernelTests/TextStyleLayoutTests.swift`, `Tests/SuiteKernelTests/TextCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-text.json` | – | ~240, 7 |
| TS-2 | – | SuiteUI `TextStyleRows` as a placeholder with its final signature (font picker, weight and italic, size, alignment, line height, letter spacing), emitting intents; `TextStyleRowsTests` | `Sources/SuiteUI/TextStyleRows.swift`, `Tests/SuiteUITests/TextStyleRowsTests.swift` | TS-1 | ~150, 2 |
| TS-3 | – | **Reachable first.** Design's text inspector swaps its family, size, weight and alignment rows for `TextStyleRows` (each intent a command, unavailable on the stubs with "Text styles arrive with TS-5."); `DesignTextStyleJourneyTests` written, skipped until TS-8 | `Sources/DesignApp/DesignInspectorText.swift`, `UITests/DesignJourneyTests+TextStyle.swift` | TS-2 | ~160, 2 |
| TS-4 | – | Halo's text inspector shows `TextStyleRows` above its colour row; a multi-line words field; `HaloTextStyleJourneyTests` written, skipped until TS-10; render budget test | `Sources/HaloApp/HaloTextInspector.swift`, `UITests/HaloJourneyTests+TextStyle.swift`, `Tests/AppSnapshotTests/RenderBudgetTextStyleTests.swift` | TS-2 | ~200, 3 |
| TS-5 | – | `TextStyleRules` and `TextStyleLayout` bodies: ranges (size 1...1600, line height 0.5...4, tracking −100...500 in thousandths of an em), the paragraph handed to FlareCore's `TextLayout` with the measured advances; turns on both suites | `Sources/SuiteKernel/Text/TextStyle.swift`, `Sources/SuiteKernel/Text/TextStyleRules.swift`, `Tests/SuiteKernelTests/TextStyleRulesTests.swift`, `Tests/SuiteKernelTests/TextStyleLayoutTests.swift`, `Tests/mutations/SuiteKernel.TextStyleRules.json` | TS-1 | ~220, 5 |
| TS-6 | – | `TextCommands` bodies over `TextStyleTarget`: `text.read`, `text.set-font`, `text.set-size`, `text.set-italic`, `text.set-alignment`, `text.set-line-height`, `text.set-tracking`; a scrub under one drag token is one step; turns on `TextCommandsTests` | `Sources/SuiteKernel/Text/TextCommands.swift`, `Tests/SuiteKernelTests/TextCommandsTests.swift`, `Tests/mutations/SuiteKernel.TextCommands.json` | TS-5 | ~180, 3 |
| TS-7 | – | **Test first.** `DesignTextStyleTests` (every fixture `.design` decodes the same and re-saves byte for byte; the new fields round-trip; a font change refits an auto-width box); `DesignTextStyle+Kernel.swift` conforms the workspace to `TextStyleTarget`; `DesignTextAlignment` becomes FlareCore's `TextAlignment`; `DesignTextStyle` gains `italic`, `lineHeight`, `tracking` (omitted at their defaults); the catalog appends the specs; ids in the ledger | `Tests/DesignModelTests/DesignTextStyleTests.swift`, `Sources/DesignModel/DesignTextStyle+Kernel.swift`, `Sources/DesignModel/Contracts/StyleTypes.swift`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/mutations/DesignModel.DesignTextStyle+Kernel.json` | TS-6 | ~260, 6 |
| TS-8 | – | Design draws the new fields: italic face, kerning from tracking, line spacing from line height, justified lines through `TextStyleLayout`; `DesignTextStyleJourneyTests` on; RJ-D50's job folder | `Sources/DesignApp/DesignTextArtwork.swift`, `Sources/DesignApp/DesignTextFont.swift`, `UITests/DesignJourneyTests+TextStyle.swift`, `Tests/RealJobs/design/paragraph-style/paragraph-style.jobs.json` | TS-7, TS-3 | ~180, 4 |
| TS-9 | – | **Test first.** `HaloTextStyleTests` (a project without styles opens unchanged; the style round-trips; two lines measure two lines high); `HaloText+Kernel.swift` conforms the project to `TextStyleTarget` for the selected text layer; `HaloTextContent` gains `style`; the catalog appends the specs; ids in the ledger | `Tests/HaloModelTests/HaloTextStyleTests.swift`, `Sources/HaloModel/HaloText+Kernel.swift`, `Sources/HaloModel/Contracts/HaloValues.swift`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/mutations/HaloModel.HaloText+Kernel.json` | TS-6 | ~240, 6 |
| TS-10 | – | `HaloTextRasterizer` draws the style through `TextStyleLayout` (the same lines in viewer and render); `HaloTextStyleJourneyTests` on; RJ-H04 re-pointed and enabled | `Sources/HaloApp/HaloTextRasterizer.swift`, `UITests/HaloJourneyTests+TextStyle.swift`, `Tests/RealJobs/halo/title-card/title-card.jobs.json` | TS-9, TS-4 | ~170, 3 |
| TS-11 | – | The text part names its adopters (Design, Halo, and Photo through `photo/text-layers`) | `docs/c4/parts/creative-apps/suite-kernel/kernel-text.json` | TS-8, TS-10 | ~20, 1 |
| TS-12 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/text-style.wave.json` | TS-11 | ~10, 1 |

## Build waves

- Wave 1: TS-1. Independent in this wave: TS-1 alone.
- Wave 2: TS-2, TS-5. Independent in this wave: both.
- Wave 3: TS-3, TS-4, TS-6. Independent in this wave: all.
- Wave 4: TS-7, TS-9. Independent in this wave: both.
- Wave 5: TS-8, TS-10. Independent in this wave: both.
- Wave 6: TS-11. Independent in this wave: TS-11 alone.
- Wave 7: TS-12. Independent in this wave: TS-12 alone.

Longest chain: TS-1 → TS-5 → TS-6 → TS-7 → TS-8 → TS-11 → TS-12 (7). Chain of 7: the stubs before the rules, the rules before the commands that call them, the commands before an app's adapter, the adapter before its drawing, and the drawing before the done tasks.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| TS-1 | the three suites compile, disabled by name; `KernelShapeTests` (unchanged) | a signature an adopter calls is missing | – (stubs) |
| TS-2 | `TextStyleRowsTests`: each control emits its intent; Justify is the fourth alignment; the controls carry `suite.text.<field>` ids | an intent is missing or a control has no id | – (view) |
| TS-3 | the row shows for a text layer with its ids; `DJ-TS` skipped by name | the row shows for a non-text layer, or an id is missing | – (view; render budget row) |
| TS-4 | `RenderBudgetTextStyleTests.lineHeightDragInThreeBodies`; `HJ-TS` skipped by name | a scrub re-renders the window per sample | – (view; render budget row) |
| TS-5 | `TextStyleLayoutTests` (fixed advances): line height 1.5 puts the second baseline 1.5 × (ascent + descent) below the first; tracking 100 widens a 10-grapheme line by 1 em; a justified line spans the box exactly and its last line doesn't; `TextStyleRulesTests`: out-of-range values clamp, NaN keeps the old value | a baseline, a width or a clamp is wrong, or the last line justifies | `SuiteKernel.TextStyleRules`: tracking taken in points, not thousandths of an em → `.trackingIsEmRelative`; clamp to 0.5...4 skipped → `.lineHeightClamps`; last line justified → `.lastLineNotJustified` |
| TS-6 | `TextCommandsTests` on a test target: each command one step, a 60-sample line height scrub one step; `text.set-font` to a family without the current face picks the nearest face; no text layer selected is unavailable with the reason | a scrub is many steps or a family switch drops to the regular face | `SuiteKernel.TextCommands`: drag token ignored → `.scrubIsOneStep`; nearest face skipped → `.familyKeepsWeight` |
| TS-7 | `DesignTextStyleTests`; `scripts/mutate --plan DesignModel.DesignTextStyle+Kernel` | an old file changes bytes, or a font change leaves the old box | `DesignModel.DesignTextStyle+Kernel`: default line height written → `.oldFilesUnchanged`; refit skipped on a family change → `.fontChangeRefits` |
| TS-8 | `DJ-TS`; Design's text snapshots unchanged for a layer at the defaults; RJ-D50 on macOS (`Cm`) | the canvas ignores a field the inspector set | – (drawing; the layout's plan covers the maths) |
| TS-9 | `HaloTextStyleTests`; `scripts/mutate --plan HaloModel.HaloText+Kernel` | an old project changes bytes, or the measured box ignores a line | `HaloModel.HaloText+Kernel`: style encoded at defaults → `.oldProjectsUnchanged`; height from one line only → `.linesAddHeight` |
| TS-10 | `HJ-TS`; RJ-H04 on macOS (`Cm`); Halo's text snapshots unchanged for a one-line default | the render and the viewer break lines differently | – (drawing) |
| TS-11 | `scripts/c4-assemble --check` | the part names no adopter | – |
| TS-12 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Line Height scrub, 120 samples, in Design | ≤ 3 window bodies; reflow p95 ≤ 8 ms for 200 words | `RenderBudgetTextStyleTests.lineHeightDragInThreeBodies` |
| render: font picker open and pick in Halo | ≤ 3 window bodies | `RenderBudgetTextStyleTests.fontPickInHalo` |
| one gesture, one step | a scrub, a pick, a toggle: one undo step | `TextCommandsTests`, `DesignTextStyleTests`, `HaloTextStyleTests` |
| no dead controls | every control is a text command | `CommandPathTests` |
| keyboard parity | ⌘I italic, ⌘⇧L/E/R/J alignment in a text box | `DesignTextStyleJourneyTests` |
| behaviour preserved | old `.design` and `.halo` files re-save byte for byte | `DesignTextStyleTests`, `HaloTextStyleTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): TS-a and TS-m green on Linux with
`Mutate:` scores clean; TS-u, TS-design and TS-halo through the feel gate
(`mouse`, `taste`: set a justified paragraph in Design, a two-line title in
Halo) with their `Mac-Finish:` lines; RJ-D50 and RJ-H04 green in the scoped
macOS run once shell-text's measurer is live. Then `Belt-Contact-Sheet:`.
