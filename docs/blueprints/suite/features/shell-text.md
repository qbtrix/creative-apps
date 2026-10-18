# Feature packet: shell-text

**Feature:** the platform half of the suite's text, once: measure styled
spans into per-grapheme advances, ascent and descent; list the Mac's font
families and their faces; and draw placed glyphs into an 8-bit sRGB frame.
The contract and its values live in SuiteModel (Linux-safe; a fixed-advance
fake measures the same way creative-core's `FixedAdvances` does, so Model
tests lay out text on Linux); the Core Text code lives in SuiteShell as the
new `shell-text` component, reached through `SuiteServices.text`. Layout
itself (line breaks, alignment, type on a path) is creative-core
`text-engine`'s: an app Model measures here, lays out there, and draws
here. Halo's Core Text rasterizer moves here, so no second copy grows.
**Line:** `line:suite` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/shell-text`
**Beta:** beta-80 plan W1 (row E8, the macOS half). Labels `beta` and `p1` when filed.

**Covers:** beta-80 plan row E8 (C4 home "suite-shell ✚`shell-text`
(CoreText)") and section 7 call 4 (macOS-only text lives in `suite-shell`
with its contract in `suite-model`, captain-approved 2026-10-18); the
Halo text-layer rasterizer (text-layers TX-4) as the code to move.

**Depends on:** suite-contracts (built); `shell-media` (SM-1, for the two
shared `SuiteServices` files: this packet's ST-1 waits on it). Cross-repo,
soft: creative-core `text-engine` defines the layout these metrics feed;
nothing here imports FlareCore (the values mirror its `GlyphRunMetrics` and
`PlacedGlyph`, and each app Model maps between them in one adapter file).

**Rule 20 (canonical first).** One measurer, one font list, one glyph
rasterizer for the suite. No layout here (that would copy `text-engine`).
The font picker is SuiteUI's (`docs/blueprints/suiteui/features/font-picker.md`),
drawn from this packet's `FontFamily` values.

**C4:** container `suite-model`, components `suite-contracts`
(`TextMeasuring`, `FontListing`, `GlyphRasterizing`), `suite-identity`
(`Values/Text.swift`), `suite-fakes` (`FakeText`), `suite-services` (the
`text` member); container `suite-shell`, ✚ new component `shell-text`
(`docs/c4/parts/creative-apps/suite-shell/shell-text.json`, `paths:
["Sources/SuiteShell/Text/"]`), added by ST-4 with its first file, and
`shell-live` (`Live/TextSlot.swift`).

**Clean-room.** Behaviour from Apple's Core Text and Core Graphics
documentation; no task reads another product's code.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| ST-a | Callers can code against `TextMeasuring`, `FontListing`, `GlyphRasterizing`, the text values and `FakeText` through `SuiteServices.text`, with the Linux and macOS checks written and disabled. | ST-1, ST-2 | MJ-ST0 | shell-media:SM-a (ST-1) |
| ST-m | `TextSpan` and `PlacedSpan` refuse what can't be drawn (empty or unknown fonts fall back by rule, sizes out of range, positions that don't match the graphemes), and the fake measures by fixed advances so Linux layouts match creative-core's. | ST-3, ST-6 | MJ-ST1 | ST-a |
| ST-live | On a Mac, spans measure through Core Text with one advance per grapheme (ligatures and emoji included), the font list names every family with its faces, and placed glyphs draw into a frame at their positions and angles. | ST-4, ST-5, ST-7 | MJ-ST2, MJ-ST3 | ST-a |
| ST-z | The slot is live, a walk measures, lays out (on the fake layout rule) and draws a two-style line on the Mac, the shared prose names the service, and the feature is built. | ST-8, ST-9 | MJ-ST4 | ST-m, ST-live; shell-media (ST-9: suite.md) |

`ui_slice: none`: the service has no screen. Its screens are SuiteUI's
`font-picker` and each app's text tool.

## Journey steps

No XCUITest here (the picker's journeys are `font-picker`'s).

- **MJ-ST0** (ST-2, `TextContractTests`): `SuiteServices.fake().text`
  measures "Hi 👋" as 4 advances; `pending["text"]` names the reason.
- **MJ-ST1** (ST-3, ST-6): span rules and the fake's advances on Linux.
- **MJ-ST2** (ST-4, `ShellTextMeasureTests`): "office" in a font with an
  "ffi" ligature gives 6 advances that sum to the line's width; "👋🏽" is one
  grapheme with one advance; ascent and descent match the font's.
- **MJ-ST3** (ST-5, ST-7, `ShellTextDrawTests`, `ShellFontListTests`):
  the system UI family is listed with at least a regular and a bold face; a
  span drawn at 45° covers pixels along the diagonal and none at the
  opposite corner.
- **MJ-ST4** (ST-8): `SuiteServices.live.text` end to end; `pending` has no
  `text` key.

## Screens and states

None.

## Contract slice

```swift
// Sources/SuiteModel/Values/Text.swift (ST-1)
public struct TextSpan: Hashable, Codable, Sendable { public var string: String; public var fontFamily: String; public var fontSize: Double
    public var weight: Int; public var italic: Bool; public var rgba: [UInt8]; public var tracking: Double }          // weight 100...900
public struct SpanMetrics: Hashable, Codable, Sendable { public var advances: [Double]; public var ascent: Double; public var descent: Double
    public var resolvedFamily: String }                                                                                 // what drew it (fallback named)
public struct PlacedSpan: Hashable, Sendable { public var span: TextSpan; public var origins: [SuitePoint]; public var degrees: [Double] }  // one per grapheme
public struct FontFace: Hashable, Codable, Sendable { public var name: String; public var weight: Int; public var italic: Bool }
public struct FontFamily: Hashable, Codable, Sendable, Identifiable { public var id: String { name }; public var name: String; public var faces: [FontFace] }
public enum TextRules { public static let sizes: ClosedRange<Double> = 1...1_600; public static let maxGraphemes = 100_000
    public static func validated(_ span: TextSpan) throws(SuiteError) -> TextSpan
    public static func validated(_ placed: PlacedSpan) throws(SuiteError) -> PlacedSpan }
// Sources/SuiteModel/Contracts/TextMeasuring.swift (ST-1)
public protocol TextMeasuring: Sendable { func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics] }   // one per span, one advance per grapheme
public protocol FontListing: Sendable { func families() -> [FontFamily] }                                            // sorted by name
public protocol GlyphRasterizing: Sendable {
    func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame }                    // shell-media's frame value
public typealias TextServices = TextMeasuring & FontListing & GlyphRasterizing
// Sources/SuiteModel/Fakes/FakeText.swift (ST-1): fixed advances (0.5 em per grapheme, ascent 0.8 em, descent 0.2 em),
//   three families, draw returns a clear frame and records the spans. SuiteServices gains `text: any TextServices` (default FakeText()).
```

SuiteModel has no point value on `dev`, so ST-1 adds `SuitePoint { x, y:
Double }` to `Values/Text.swift`.

## Pseudocode

- **Rules (ST-3).** Sizes inside `TextRules.sizes`; weight 100...900 in
  hundreds; `rgba` exactly 4 bytes; tracking finite; at most `maxGraphemes`
  per call; `origins` and `degrees` counts equal the span's grapheme count;
  every value finite. An empty family name means the system UI font; an
  unknown family falls back to it and `resolvedFamily` says so (never a
  throw: a document from another Mac still draws).
- **Fake advances (ST-6).** For each span: `fontSize × 0.5` per grapheme
  plus `tracking`, ascent `0.8 × size`, descent `0.2 × size`: the same
  numbers creative-core's `FixedAdvances` gives, so a Model test that lays
  out with the fake matches core's own tests.
- **Measure (ST-4, macOS).** A `CTLine` per span from an attributed string
  (font from family, weight and italic traits through the font descriptor;
  tracking as the kern attribute); for each glyph run, map glyph string
  indices to grapheme clusters (Swift `Character` boundaries over the
  UTF-16 indices Core Text reports) and sum glyph advances per cluster, so a
  ligature's advance splits evenly across its graphemes and a multi-glyph
  emoji is one advance. Ascent and descent from the line's typographic
  bounds.
- **Fonts (ST-5).** Available font families from the font manager, each
  family's members as faces with their weight (mapped from the trait's
  -1...1 to 100...900) and italic flag; sorted, de-duplicated.
- **Draw (ST-7).** Moved from Halo's `HaloTextRasterizer`: an 8-bit sRGB
  premultiplied bitmap context the frame's size, each grapheme's glyphs
  drawn at its origin rotated by its angle (baseline origin, y up inside the
  context, flipped to the frame's top-row-first order), colour from `rgba`;
  then unpremultiplied into `MediaFrame`. A context Core Graphics won't make
  throws `notAvailable`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| ST-1 | – | The contract: values, the three protocols, `FakeText`, the `text` member and `pending` reason, the fake slot; MJ-ST0 | `Sources/SuiteModel/Values/Text.swift`, `Sources/SuiteModel/Contracts/TextMeasuring.swift`, `Sources/SuiteModel/Fakes/FakeText.swift`, `Sources/SuiteModel/SuiteServices.swift`, `Sources/SuiteShell/SuiteServices+Live.swift`, `Sources/SuiteShell/Live/TextSlot.swift`, `Tests/SuiteModelTests/TextContractTests.swift`, `Tests/mutations/SuiteModel.TextValues.json` | shell-media:SM-1 | ~320, 8 |
| ST-2 | – | Checks first: `TextRulesTests`, `FakeTextTests` (Linux), `ShellTextMeasureTests`, `ShellFontListTests`, `ShellTextDrawTests` (macOS) disabled by name | `Tests/SuiteModelTests/TextRulesTests.swift`, `Tests/SuiteModelTests/FakeTextTests.swift`, `Tests/AppSnapshotTests/ShellTextMeasureTests.swift`, `Tests/AppSnapshotTests/ShellFontListTests.swift`, `Tests/AppSnapshotTests/ShellTextDrawTests.swift` | ST-1 | ~300, 5 |
| ST-3 | – | `TextRules`; turns on `TextRulesTests` | `Sources/SuiteModel/Values/Text+Rules.swift`, `Tests/SuiteModelTests/TextRulesTests.swift`, `Tests/mutations/SuiteModel.TextRules.json` | ST-2 | ~160, 3 |
| ST-4 | – | `CoreTextMeasurer` and the `shell-text` C4 part; turns on `ShellTextMeasureTests`; `Unverified API:` for the glyph-to-cluster mapping | `Sources/SuiteShell/Text/CoreTextMeasurer.swift`, `Tests/AppSnapshotTests/ShellTextMeasureTests.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-text.json` | ST-2 | ~260, 3 |
| ST-5 | – | `FontCatalog`; turns on `ShellFontListTests` | `Sources/SuiteShell/Text/FontCatalog.swift`, `Tests/AppSnapshotTests/ShellFontListTests.swift` | ST-4 | ~140, 2 |
| ST-6 | – | `FakeText`'s fixed advances and its parity with creative-core's numbers; turns on `FakeTextTests` | `Sources/SuiteModel/Fakes/FakeText.swift`, `Tests/SuiteModelTests/FakeTextTests.swift`, `Tests/mutations/SuiteModel.FakeText.json` | ST-2 | ~120, 3 |
| ST-7 | – | `GlyphRasterizer` (moved from `HaloTextRasterizer`); turns on `ShellTextDrawTests` | `Sources/SuiteShell/Text/GlyphRasterizer.swift`, `Tests/AppSnapshotTests/ShellTextDrawTests.swift` | ST-4 | ~240, 2 |
| ST-8 | – | `LiveText` joins the three; the slot goes live; MJ-ST4 | `Sources/SuiteShell/Text/LiveText.swift`, `Sources/SuiteShell/Live/TextSlot.swift`, `Tests/AppSnapshotTests/ShellTextLiveTests.swift` | ST-3, ST-5, ST-6, ST-7 | ~100, 3 |
| ST-9 | – | Shared prose: suite.md names the text service and the measure-here, lay-out-in-core split; the part's final words; `status: built`; `feature-done` | `docs/blueprints/suite.md`, `docs/c4/parts/creative-apps/suite-shell/shell-text.json`, `docs/blueprints/suite/features/shell-text.wave.json` | ST-8, shell-media | ~50, 3 |

ST-5 and ST-7 wait on ST-4 because it adds the `shell-text` part that owns
their folder; they share no file with each other. ST-9 waits on
`shell-media` because both final tasks edit `suite.md`.

## Build waves

- Wave 1: ST-1 (after shell-media's SM-1). Independent in this wave: ST-1 alone.
- Wave 2: ST-2. Independent in this wave: ST-2 alone.
- Wave 3: ST-3, ST-4, ST-6. Independent in this wave: all three.
- Wave 4: ST-5, ST-7. Independent in this wave: both.
- Wave 5: ST-8. Independent in this wave: ST-8 alone.
- Wave 6: ST-9 (shared prose, `feature-done`, final). Independent in this wave: ST-9 alone.

Longest chain: ST-1 → ST-2 → ST-4 → ST-7 → ST-8 → ST-9 (6). Chain of 6:
the checks code against the contract, the rasterizer lives in the folder
ST-4's part owns, the live service joins them, ST-9 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| ST-1 | `TextContractTests` (MJ-ST0): the fake measures "Hi 👋" as 4 advances; an `unavailable` fake throws its reason; `pending["text"]` set | a member is missing | `SuiteModel.TextValues` (owned by ST-1, `Tests/mutations/SuiteModel.TextValues.json`): grapheme count from `utf16` → `TextContractTests.emojiIsOneAdvance`; reason dropped → `.pendingNamesText` |
| ST-2 | suites compile, disabled | – | – |
| ST-3 | `TextRulesTests`: size 0 and 1,601 refused; weight 450 refused; 3-byte colour refused; origins count ≠ graphemes refused; an empty family is the system font; NaN tracking refused | a bad span draws | `SuiteModel.TextRules`: size bound `<` for `<=` at 1,600 → `TextRulesTests.sizeSixteenHundredAccepted`; count check by `utf8` → `.originsPerGrapheme` |
| ST-4 | `ShellTextMeasureTests` (MJ-ST2) | a ligature or emoji gives the wrong number of advances | none: live |
| ST-5 | `ShellFontListTests` | the system family or a face is missing | none: live |
| ST-6 | `FakeTextTests`: advances, ascent and descent equal creative-core `FixedAdvances`' (0.5, 0.8, 0.2 em) for three sizes and with tracking | Linux layouts diverge from core's | `SuiteModel.FakeText`: tracking added once per span → `FakeTextTests.trackingPerGrapheme`; ascent 0.75 em → `.matchesCoreNumbers` |
| ST-7 | `ShellTextDrawTests` (MJ-ST3) | a glyph lands at the wrong place or angle | none: live |
| ST-8 | `ShellTextLiveTests` (MJ-ST4) | the slot stays fake | none: integrate |
| ST-9 | `scripts/waves render --dry-run`; suite.md names the service | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Measure while typing | a 2,000-grapheme paragraph in 3 spans ≤ 3 ms (release) | `ShellTextMeasureTests.paragraphFast` (reported; Mac finisher) |
| Draw a title frame | 1920 × 1080, 40 placed graphemes ≤ 8 ms | `ShellTextDrawTests.titleFrameFast` (reported) |
| Linux-safe contract | `Sources/SuiteModel` imports no Core Text or Core Graphics | `scripts/ci` Linux job |
| Never throws on a missing font | fallback named in `resolvedFamily` | `TextRulesTests`, `ShellTextMeasureTests.unknownFamilyFallsBack` |

## Done check

Per slice (rules 6, 15, 17). ST-live and ST-z need the Mac finisher
(`Mac-Finish-Wanted:`), their tests being macOS-only. Then
`Belt-Contact-Sheet:` with the measure and draw numbers.

## Adopted later

- SuiteUI `font-picker` (suiteui line, beside this one) lists `families()`.
- **W2:** S21 text animators draw through `GlyphRasterizing`.
- **W3:** Halo text layers swap `HaloTextRasterizer` for `services.text` and
  delete it; Design, Photo and Flare text tools measure and draw here.

## Not in this packet

Layout (creative-core `text-engine`). Glyph outlines as paths (convert text
to shapes): a later `GlyphOutlining` member. Font activation of files a
document names but the Mac lacks (fallback only). Vertical and
bidirectional text.
