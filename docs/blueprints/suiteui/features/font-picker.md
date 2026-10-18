# Feature packet: font-picker

**Feature:** SuiteUI's one font picker: a searchable list of font families
(each name drawn in its own face), a face menu ordered by weight then
italic, a size row (`StudioScrubRow`), and the rule that switching family
keeps the nearest face. It takes `[FontFamily]` values and a selection in,
and reports picks out through a closure; it never reads a Model or a
service. On the gallery it runs on `FakeText`'s families; live, any app
passes `services.text.families()`.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/font-picker`
**Beta:** beta-80 plan W1 (row E8's SuiteUI piece). Labels `beta` and `p1` when filed.

**Covers:** beta-80 plan row E8 (C4 home "suiteui font picker"); the
duplication guard that no app grows its own font menu (Halo's and Design's
text inspectors adopt this in W3).

**Depends on:** suite `shell-text` (cross-line, soft: its ST-a slice
declares `FontFamily` and `FontFace` in SuiteModel; FP-1 waits on that
slice's merge); editor-kernel (slice EK-u owns `SuiteGallery.swift` before
FP-1 adds the page; a slice wait, not a wave dependency).

**Rule 20.** One picker. Search and nearest-face rules live in one file
here (`FontPickerRules.swift`); no app filters fonts itself.

**C4:** container `suiteui`, component `suiteui-sources` (one component
holds `Sources/SuiteUI/`; FP-6 adds "the font picker" to its description).
No new component.

**Clean-room.** Behaviour from the HIG and the platform's own font panel
conventions in Apple's documentation; no task reads another product's code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets), 7.5 (feel).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FP-a | `FontPicker`'s inputs and outputs and `FontPickerRules` are declared as stubs returning the input order, the gallery's `font-picker` page is in the index on `FakeText`'s families, and the checks are written, disabled. | FP-1, FP-2 | SJ0 | editor-kernel:EK-u (FP-1) |
| FP-u | On the gallery page, typing filters the list per keystroke, each family shows in its own face, the face menu and size row pick, every control is identified, within the render budget. | FP-3, FP-4 | `testFontPickerPicksAFace` | FP-a |
| FP-m | Search matches prefix first then substring, ignoring case and diacritics; faces order by weight then italic; switching family keeps the nearest weight and italic. | FP-5, FP-8 | FJ-m | FP-a |
| FP-z | The page runs on the live families when the gallery is launched with live services, the journey passes on live, and the feature is built. | FP-6, FP-7 | `testFontPickerPicksAFace` | FP-u, FP-m; editor-kernel and canvas-marks (FP-7: they own suiteui.md first) |

FP-u waits only on FP-a (rule 18); FP-m never waits on FP-u. FJ-m is the
rules' unit walk in `SuiteUITests` (macOS only, so FP-m takes a Mac pass).

## Journey steps

1. Open the gallery index, click `font-picker` (FP-1, SJ0): the picker
   shows `FakeText`'s three families, the first selected.
2. Type "gro" (FP-3, `testFontPickerPicksAFace`): the list narrows to the
   family whose name starts with it; the body count per keystroke stays at
   2 or under.
3. Pick its Bold face from the face menu, then scrub the size to 36 (FP-3):
   the page's log shows `pick(family, Bold, 36)`.
4. Pick another family (FP-5): the face stays Bold (the nearest weight).
5. VoiceOver reads each row's family name; the menu and the row work from
   the keyboard (FP-4).

## Screens and states

`suiteui-font-picker` (list, light and dark), `suiteui-font-picker-search`
(filtered), `suiteui-font-picker-faces` (menu open).

## Contract slice

```swift
// Sources/SuiteUI/Contracts/FontPicking.swift (FP-1)
public struct FontPick: Hashable, Sendable { public var family: String; public var face: FontFace; public var size: Double }
// Sources/SuiteUI/FontPickerRules.swift (FP-1 stubs returning the input order, FP-5 bodies)
public enum FontPickerRules {
    public static func filtered(_ families: [FontFamily], query: String) -> [FontFamily]
    public static func orderedFaces(_ family: FontFamily) -> [FontFace] }
// Sources/SuiteUI/FontPickerRules+Nearest.swift (FP-1 stub returning the first face, FP-8 body)
extension FontPickerRules { public static func nearestFace(in family: FontFamily, to face: FontFace) -> FontFace? }
// Sources/SuiteUI/FontPicker.swift (FP-1 placeholder, FP-3 view)
public struct FontPicker: View { public init(families: [FontFamily], pick: FontPick, onPick: @escaping (FontPick) -> Void) }
```

## Pseudocode

- **filtered.** Fold case and diacritics on both sides; families whose name
  starts with the query, in name order, then those containing it; an empty
  query returns all.
- **nearestFace.** Minimise `|weight − w| / 100 + (italic ≠ i ? 0.5 : 0)`;
  ties go to the lighter face.
- **View.** A system `List` with a search field (the platform's searchable
  modifier), rows drawn in their family's regular face at the body size;
  the face menu a system `Picker`; the size row `StudioScrubRow` 1...1,600.
  The list is lazy, so 500 families keep one body per keystroke for the
  list.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FP-1 | – | `FontPick`, the rules stubs, the placeholder view, the gallery page in `SuiteGallery.areas`, the journey written and skipped (`XCTSkip("waits on FP-4")`) | `Sources/SuiteUI/Contracts/FontPicking.swift`, `Sources/SuiteUI/FontPickerRules.swift`, `Sources/SuiteUI/FontPickerRules+Nearest.swift`, `Sources/SuiteUI/FontPicker.swift`, `Sources/SuiteUI/Gallery/GalleryFontPicker.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `UITests/SuiteJourneyTests+FontPicker.swift` | editor-kernel:EK-u, shell-text:ST-a | ~240, 7 |
| FP-2 | – | Checks first: `FontPickerRulesTests` and `FontPickerNearestTests` disabled by name | `Tests/SuiteUITests/FontPickerRulesTests.swift`, `Tests/SuiteUITests/FontPickerNearestTests.swift` | FP-1 | ~160, 2 |
| FP-3 | – | The view: list, search, face menu, size row, identifiers | `Sources/SuiteUI/FontPicker.swift`, `Tests/SuiteUITests/FontPickerTests.swift` | FP-1 | ~300, 2 |
| FP-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteFontPickerSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFontPickerTests.swift`, `UITests/SuiteJourneyTests+FontPicker.swift` | FP-3 | ~200, 3 |
| FP-5 | – | `filtered` and `orderedFaces` bodies; turns on `FontPickerRulesTests` | `Sources/SuiteUI/FontPickerRules.swift`, `Tests/SuiteUITests/FontPickerRulesTests.swift`, `Tests/mutations/SuiteUI.FontPickerRules.json` | FP-2 | ~140, 3 |
| FP-8 | – | `nearestFace` body; turns on `FontPickerNearestTests` | `Sources/SuiteUI/FontPickerRules+Nearest.swift`, `Tests/SuiteUITests/FontPickerNearestTests.swift`, `Tests/mutations/SuiteUI.FontPickerNearest.json` | FP-2 | ~80, 3 |
| FP-6 | – | The page reads live families when the gallery has live services; the journey on live | `Sources/SuiteUI/Gallery/GalleryFontPicker.swift`, `Tests/SuiteUITests/FontPickerLiveTests.swift` | FP-4, FP-5, FP-8 | ~80, 2 |
| FP-7 | – | Shared prose: suiteui.md names the picker; the component's description; `status: built`; `feature-done` | `docs/blueprints/suiteui.md`, `docs/c4/parts/creative-apps/suiteui/suiteui-sources.json`, `docs/blueprints/suiteui/features/font-picker.wave.json` | FP-6 | ~40, 3 |

FP-1 declares every rule in the two rules files so FP-5 and FP-8 each fill
one file and share none.

## Build waves

- Wave 1: FP-1. Independent in this wave: FP-1 alone.
- Wave 2: FP-2, FP-3. Independent in this wave: both.
- Wave 3: FP-4, FP-5, FP-8. Independent in this wave: all three.
- Wave 4: FP-6. Independent in this wave: FP-6 alone.
- Wave 5: FP-7 (shared prose, `feature-done`, final). Independent in this wave: FP-7 alone.

Longest chain: FP-1 → FP-3 → FP-4 → FP-6 → FP-7 (5). Chain of 5: the view
fills FP-1's placeholder, the budget and journey time the view, the live
page swaps the data under the journey, FP-7 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FP-1 | SJ0: the index lists `font-picker`; the page opens | the page is missing | – (UI) |
| FP-2 | compiles, disabled | – | – |
| FP-3 | `FontPickerTests`: rows have stable ids; a pick calls `onPick` once | a pick fires twice | – (UI) |
| FP-4 | `SuiteFontPickerSnapshots`; `RenderBudgetFontPickerTests.typingFiltersInTwoBodies`; `testFontPickerPicksAFace` steps 1 to 5 | budget over, or a step fails | – (UI) |
| FP-5 | `FontPickerRulesTests`: "gro" puts the prefix match first; "é" matches "e"; faces order Light, Regular, Italic, Bold, Bold Italic | an order is wrong | `SuiteUI.FontPickerRules`: substring before prefix → `FontPickerRulesTests.prefixFirst`; diacritics kept → `.foldsDiacritics`; italic sorted before roman of the same weight → `.romanBeforeItalic` |
| FP-8 | `FontPickerNearestTests`: Bold to a family with Semibold and Black keeps Semibold; Bold Italic to a family without italics keeps Bold; ties go lighter; an empty family gives nil | a nearest face is wrong | `SuiteUI.FontPickerNearest`: italic weighted 0 → `FontPickerNearestTests.keepsItalic`; ties go heavier → `.tiesGoLighter` |
| FP-6 | `FontPickerLiveTests`: the page lists the live families' count | the page stays on fakes | – |
| FP-7 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: typing in the search field (500 families) | ≤ 2 window bodies per keystroke; filter p95 ≤ 8 ms | `RenderBudgetFontPickerTests.typingFiltersInTwoBodies` |
| No dead controls | every control registers in `suite.controls` | `SuiteJourneyTests.testFontPickerPicksAFace` |
| Keyboard and VoiceOver parity | search, list, menu and size row reachable by keyboard; rows read their family name | `testFontPickerPicksAFace` step 5 |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17): FP-u's feel gate (`mouse` and `taste`) and its
`Mac-Finish:` line; FP-z's journey on live. Then `Belt-Contact-Sheet:` with
`suiteui-font-picker-*`.

## Adopted later

**W3:** Halo's text inspector, Design's and Photo's text tools and Flare's
text panel swap their font controls for `FontPicker`.

## Not in this packet

Font previews of a sample string, favourites, activating missing fonts.
