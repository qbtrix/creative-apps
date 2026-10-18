# SwiftUI rules

<!-- The SwiftUI field guide: what every lead, builder and Mac finisher reads
     before touching Sources/*App/ or Sources/SuiteUI/. Each rule comes from a
     real defect in these apps (the lesson or PR is named) and carries one
     wrong and one right line. Keep it under 220 lines; detail goes in
     docs/engineering.md or docs/design.md. -->

The apps passed their journeys and still felt slow and dated in the
captain's hands (lesson 154). Tests prove a control exists; these rules are
about how it feels. Layers and tests: `docs/engineering.md`. The look:
`docs/design.md`. Each rule shows the wrong way (`✗`) and the right way (`✓`).

## Performance: what makes a body run

**1. Never write observed state per input sample.** Every write to `@State`
or an observed Model runs the window's body and lays out the whole editor
again. A drag sends 60 to 120 samples a second. Draw the drag on a live
overlay SwiftUI doesn't watch, and commit to the Model once on mouse-up.
Photo's brush felt native only once its strokes drew on `LiveStroke`, a copy
outside SwiftUI's sight. Commit animation went from 38.5% to 10% of the main
thread, layout from 20% to 3.2% (lessons 132, 135). Halo's viewer drag and
its inspector sliders still write per sample (#1458).

```swift
✗ .onChanged { model.viewerDrag(delta: $0.translation) }       // a window body per sample
✓ .onChanged { live.move($0.translation) }  .onEnded { model.commitDrag(live.take()) }
```

A sample that lands on the value already shown is skipped, not written
(#1458, `scrubChanges(to:)`). A skip only helps when most samples change
nothing; when every sample changes the value, it has to be an overlay.

**2. Give rows stable identity and Equatable inputs.** SwiftUI skips a
child's body only when its identity is stable and its inputs compare equal.
`id: \.self` on a value that changes, `ForEach(Array(x.enumerated()))`, or a
fresh `UUID()` in the body rebuild every row. A row that takes plain
`Equatable` values (`RulerTicks`, `CanvasLayout`) can be skipped. A closure
can't be compared, so a view that takes one is treated as changed on every
pass. Pass ids and values down, and keep one action closure at the level
that owns the list, or mark the row `.equatable()` with an `==` that leaves
the closures out.

```swift
✗ ForEach(layers.indices, id: \.self) { i in LayerRow(layer: layers[i], onTap: { model.select(layers[i].id) }) }
✓ ForEach(layers) { LayerRow(name: $0.name, selected: $0.id == selection).equatable() }  // tap handled by the list
```

**3. Keep accessibility modifiers O(1).** Test scaffolding runs on every
render for every user. `ScrubAccessibility` built a hidden stepped `Slider`
in `accessibilityRepresentation`: 200,001 ticks per Halo X row per pass,
95% of every render, 81 to 87% CPU (lesson 153, #1471). No `ForEach`, no
stepped control and no string building over a range inside an
accessibility modifier.

```swift
✗ .accessibilityRepresentation { Slider(value: $v, in: -100_000...100_000, step: 1) }
✓ .accessibilityRepresentation { Slider(value: $v, in: range) }
  .accessibilityAdjustableAction { $0 == .increment ? step(+1) : step(-1) }
```

**4. Give split columns fixed minimum sizes.** A column whose width depends
on its content makes AppKit re-measure the whole hosting view
(`NSHostingView.minSize` → `_sizeThatFits`) on every layout, which is what
a divider drag costs. `ViewThatFits` measures its children twice. Put
explicit `min`/`ideal`/`max` on each column, as `SuiteWindow` does with
`SuiteSize`. Never put a min frame on the window root: it acts on a different
view and brings back the clipped columns of #579 and #933.

```swift
✗ inspector.frame(minWidth: rowsFitWidth)        // measured from content, every pass
✓ inspector.navigationSplitViewColumnWidth(min: SuiteSize.inspectorWidth.min, ideal: ..., max: ...)
```

**5. Use LazyVStack (or LazyVGrid) for long lists.** A plain `VStack` in a
`ScrollView` builds every row up front: every layer, keyframe, page or photo.
Anything that can grow past one screen is lazy. `ThumbnailGrid` is the model.

```swift
✗ ScrollView { VStack { ForEach(keyframes) { KeyRow($0) } } }
✓ ScrollView { LazyVStack(spacing: SuiteSpacing.xs) { ForEach(keyframes) { KeyRow($0) } } }
```

**6. Prove feel on the real window.** A harness that drives the Model
without the window around it measures the cheap part (lesson 132). Count
window bodies with the debug body counter (`HaloWindow.bodyRuns`,
`PhotoEditor.bodyRuns`) in a render budget test, and profile the shipped app
with `sample <pid> 20 1` while you drag. Body counts are deterministic and
gate. Milliseconds are reported, not gated (`Tests/perf-suites.txt`), and
the Mac finisher checks them on a release build.

```swift
✗ #expect(model.dragLatencyP95 < 8)                          // Model only, no window
✓ drag(window, samples: 120); #expect(HaloWindow.bodyRuns <= 3)
```

## Tests and identifiers

**7. Put identifiers on leaf controls only.** SwiftUI copies an
accessibility identifier set on a view with several elements onto every
element inside it. Halo's `KeyframeButton` (stopwatch and key diamond) gave
both buttons one id, so the audit saw one control overlapping itself (lesson
145, #1322). A container gets `.accessibilityElement(children: .contain)`
and its own id; each button gets its own id.

```swift
✗ HStack { stopwatch; diamond }.accessibilityIdentifier("halo.inspector.key.opacity")
✓ HStack { stopwatch.accessibilityIdentifier("halo.inspector.stopwatch.opacity")
           diamond.accessibilityIdentifier("halo.inspector.key.opacity") }
```

**8. Journeys use the mouse.** A journey step that changes mode clicks a
visible control at least once. Shortcuts get their own step. A journey that
only presses Esc proves the feature works, not that a person can find the
way out (lesson 152).

```swift
✗ app.typeKey(.escape, modifierFlags: [])        // the only way back from the loupe
✓ journey.click("Grid", step: "loupe-back-to-grid")
```

## Interaction

**9. Every mode change needs a visible control.** Entering or leaving a
mode (loupe, isolate, edit text, full screen, a tool) needs something on
screen to click. A shortcut and a menu item are extras. Library's loupe
had only Esc, G and View > Grid, until #1449 added a Grid button.

```swift
✗ .onKeyPress(.escape) { model.showGrid() }                  // and nothing on screen
✓ ToolbarAction("Grid", systemImage: "square.grid.2x2", shortcut: "g", identifier: "library.loupe.grid") { model.showGrid() }
```

**10. Every interactive element shows hover, pressed and selected.** A
control that doesn't react under the pointer feels dead. Use the SuiteUI
style that already does it (`SuiteChipStyle`, `InspectorAction`, the
inspector rows: `rowHover` on hover, darker on press, `stateSelected` when
on). Hover is never shown by fill alone (docs/design.md, Surfaces). A canvas
tool also shows feedback while it acts: a cursor, a guide, a live value.

```swift
✗ Button(action: pick) { Image(systemName: "pencil") }.buttonStyle(.plain)
✓ ChoiceChips(options: tools, selection: tool, onSelect: pick)   // hover, pressed, selected built in
```

**11. Reuse SuiteUI before building app-local UI.** When two apps need the
same fix or pattern, it goes in SuiteUI. An app-local copy is a critic
finding (lead.md, rule 16). A missing component is a `needs-ui` issue plus a
plain placeholder. Search `Sources/SuiteUI` first:

| Need | SuiteUI |
|---|---|
| Window, columns, editor layout | `SuiteWindow`, `EditorShell`, `EditorDetail`, `EditorTopBar` |
| Toolbars, app switcher, status | `ToolbarGroup`, `AppSwitcher`, `ViewerStatusBar` |
| Sidebar and lists | `SuiteSidebarList`, `SidebarSection`, `SidebarRow`, `SidebarActionRow` |
| Inspector | `InspectorHeader`, `InspectorRows`, `InspectorAction`, `StudioScrubRow`, `ScrubField`, `NumericInput`, `ColorWell` |
| Choices | `ChoiceChips`, `ChipRow`, `SegmentedTabs`, `PresetGrid` |
| Canvas | `CanvasViewport`, `CanvasSurface`, `CanvasMarks`, `Ruler`, `ZoomMath` |
| Time and curves | `TimelineStrip`, `KeyframeButton`, `CurveEditor`, `ToneCurveEditor` |
| Grids, cards, empty | `ThumbnailGrid`, `GridSelection`, `SurfaceCard`, `GlassPanel`, `EmptyStateView` |
| Look | `Tokens` (`SuiteColor`, `SuiteSpacing`, `SuiteSize`), `suiteGlass(in:)` |

```swift
✗ struct HaloEaseChip: View { … @State var hovering … }          // in Sources/HaloApp
✓ ChoiceChips(options: eases, selection: ease, onSelect: model.setEase)
```

The reference look is Flare's easing panel (`StudioScrubRow`, `ChoiceChips`).

## New APIs: macOS 27 and Swift 6.4

**12. Check new or unfamiliar APIs against Apple's documentation.** Model
training predates macOS 27 and Swift 6.4, so a remembered signature can be
wrong or gone. On the Mac, look it up in Xcode's documentation (the xcode
MCP `DocumentationSearch` tool, which reads the installed SDK) and build. On
a Linux cloud machine, which can't compile SwiftUI, read the `apple-docs`
MCP (CLAUDE.md, Rules) and still list each such call under
`Unverified API:` in the PR body, so the Mac finisher checks it against the
SDK.

```text
✗ (PR body says nothing; the macOS build breaks on dev)
✓ Unverified API: `.navigationSplitViewColumnWidth(min:ideal:max:)` on `.inspector`, HaloWindow.swift
```

## Statics on Views

**13. Mark a pure `static` on a View `nonisolated`.** `View` is `@MainActor`,
and every `static func` and `static var` declared in a type that conforms to
it inherits that. A swift-testing `@Test` that calls one from a worker thread
traps with signal 5 (`dispatch_assert_queue`) and aborts the whole macOS test
run. Linux CI stays green because it never builds that code. It hit three
times in one day (#2633, #2631, #2640); #2700 and #2640 carry the fixes. A helper that truly needs the main actor says so on the line before
it: `// view-static: main-actor`. `scripts/check-view-statics` (run by
`scripts/ci`) fails on a new unmarked one; `Tests/view-statics-baseline.txt`
holds the old ones and only shrinks.

```swift
✗ static func lines(guides: [ViewportGuide], zoom: Double) -> [GuideLine]
✓ nonisolated static func lines(guides: [ViewportGuide], zoom: Double) -> [GuideLine]
```

## Before you open a UI PR

- [ ] No `@State` or Model write per drag, scroll or playback sample (1)
- [ ] Rows have stable ids and Equatable inputs, no closures that break it (2)
- [ ] Accessibility modifiers do constant work (3)
- [ ] Every split column has a fixed min width (4)
- [ ] Lists that grow are lazy (5)
- [ ] Render budget test on the real window for the drag you touched (6)
- [ ] Ids on leaf controls only (7)
- [ ] Each mode change has a visible control and a journey step that clicks it (8, 9)
- [ ] Hover, pressed and selected on every new control (10)
- [ ] SuiteUI searched; shared parts went there (11)
- [ ] New APIs checked in Xcode docs, or listed as `Unverified API:` (12)
- [ ] Pure statics on a View are `nonisolated` (13)
