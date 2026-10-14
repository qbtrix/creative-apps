// TokensTests.swift: checks on SuiteUI's tokens and value types: the
// Visual language geometry (QB-F6) and, in ContrastTests.swift, the color
// table's contrast (QB-V6). macOS only.
import SuiteUI
import SwiftUI
import Testing

@Test func spacingScaleIsStrictlyIncreasingOnTheGrid() {
    let scale = SuiteSpacing.scale
    #expect(scale == [2, 4, 8, 12, 16, 24, 32])
    #expect(zip(scale, scale.dropFirst()).allSatisfy { $0 < $1 })
}

@Test func radiiStepDownForConcentricNesting() {
    #expect(SuiteRadius.field < SuiteRadius.small)
    #expect(SuiteRadius.small < SuiteRadius.medium)
    #expect(SuiteRadius.medium < SuiteRadius.large)
}

@Test func sizesMeetTheHitTargetAndNestInTheWindow() {
    #expect(SuiteSize.toolButton >= 28)
    for width in [SuiteSize.sidebarWidth, SuiteSize.inspectorWidth] {
        #expect(width.min <= width.ideal && width.ideal <= width.max)
    }
    let shell = SuiteSize.sidebarWidth.min + SuiteSize.contentMinimum.width + SuiteSize.inspectorWidth.min
    #expect(shell <= SuiteSize.windowMinimum.width)
}

/// #215: at its ideal widths the split view still fits the window minimum.
@Test func splitViewIdealWidthsFitTheWindowMinimum() {
    #expect(SuiteSize.windowMinimum.width == 880)
    let ideal = SuiteSize.sidebarWidth.ideal + SuiteSize.contentMinimum.width + SuiteSize.inspectorWidth.ideal
    #expect(ideal <= SuiteSize.windowMinimum.width)
}

/// #579: the window opens wide enough for both side columns at their ideals
/// around the content's ideal width, and that launch size is within the minimum.
@Test func windowLaunchSizeComesFromTheColumnTokens() {
    let launch = SuiteSize.sidebarWidth.ideal + SuiteSize.contentIdealWidth + SuiteSize.inspectorWidth.ideal
    #expect(SuiteSize.windowLaunch.width == launch)
    #expect(SuiteSize.contentIdealWidth >= SuiteSize.contentMinimum.width)
    #expect(SuiteSize.windowLaunch.width >= SuiteSize.windowMinimum.width)
    #expect(SuiteSize.windowLaunch.height >= SuiteSize.windowMinimum.height)
}

@Test func editorRowsMatchTheVisualLanguage() {
    // 34 pt filled rows 6 pt apart, the label inside on the left: no label column.
    #expect(SuiteSize.inspectorBar == 34 && SuiteSpacing.row == 6)
    #expect(SuiteSize.compactControl == .small)
    // A bar slider plus the keyframe button and its diamond slot fit the panel inside its padding.
    let row = SuiteSize.inspectorBar * 3 + 2 * SuiteSize.keyframeButton + 2 * SuiteSpacing.xs
    #expect(row <= SuiteSize.editorPanelWidth - 2 * SuiteSpacing.m)
    // The editor shell still fits the window minimum: rail, canvas and panel across;
    // top bar, canvas and the status row down.
    #expect(SuiteSize.toolButton + SuiteSize.contentMinimum.width + SuiteSize.editorPanelWidth <= SuiteSize.windowMinimum.width)
    #expect(SuiteSize.editorTopBar + SuiteSize.contentMinimum.height + SuiteSize.inspectorBar <= SuiteSize.windowMinimum.height)
}

/// QB-F6: the geometry the Visual language names, so a slide back to framework defaults fails.
@Test func geometryMatchesTheVisualLanguage() {
    #expect([SuiteRadius.field, SuiteRadius.small, SuiteRadius.control, SuiteRadius.medium, SuiteRadius.lane, SuiteRadius.large]
        == [4, 6, 8, 10, 12, 16])
    #expect([SuiteSpacing.row, SuiteSpacing.m, SuiteSpacing.l, SuiteSpacing.pillGap, SuiteSpacing.markerInset] == [6, 12, 16, 4, 6])
    #expect(SuiteInset.barButton.top == 4 && SuiteInset.barButton.leading == 8)
    #expect(SuiteInset.pill.top == 2 && SuiteInset.pill.leading == 8)
    #expect(SuiteInset.card.top == 8 && SuiteInset.card.leading == 12)
    let sizes = [
        SuiteSize.inspectorBar, SuiteSize.keyframeButton, SuiteSize.chip, SuiteSize.preset, SuiteSize.presetHit,
        SuiteSize.actionButton, SuiteSize.pill, SuiteSize.pillHit, SuiteSize.transportButton, SuiteSize.playButton,
        SuiteSize.selectionHandle, SuiteSize.selectionHandleHit, SuiteSize.anchor, SuiteSize.anchorHit,
        SuiteSize.statusDot, SuiteSize.editorTopBar, SuiteSize.editorPanelWidth, SuiteSize.timelineLane,
        SuiteSize.timelineKeyframe, SuiteSize.timelineKeyframeHit,
    ]
    #expect(sizes == [34, 28, 28, 24, 28, 32, 20, 24, 32, 36, 8, 12, 6, 12, 6, 48, 280, 32, 10, 16])
    #expect(SuiteSize.swatch == CGSize(width: 24, height: 16))
    // Hit areas: at least 28 where the layout allows, never under 20.
    for hit in [SuiteSize.inspectorBar, SuiteSize.keyframeButton, SuiteSize.chip, SuiteSize.presetHit, SuiteSize.actionButton] {
        #expect(hit >= 28)
    }
    for hit in [SuiteSize.pillHit, SuiteSize.timelineKeyframeHit, SuiteSize.selectionHandleHit, SuiteSize.anchorHit] {
        #expect(hit >= 12)
    }
    #expect(SuiteColor.disabledOpacity == 0.4)
    #expect(SuiteMotion.state(reduceMotion: true) == nil && SuiteMotion.state(reduceMotion: false) != nil)
}

@Test func toolbarActionUsesItsTitleAsId() {
    let action = ToolbarAction("New Animation", systemImage: "plus")
    #expect(action.id == "New Animation")
    #expect(!action.isSelected)
}

@Test func sidebarItemDefaultsToNoCount() {
    let item = SidebarItem(id: "a", title: "All", systemImage: "photo")
    #expect(item.count == nil)
}

/// QB-V6: the color table's promises, computed from SuitePalette's literal hex
/// in all four appearances, and the table in docs/design.md matched value for value.
@Suite struct TokensTests {
    /// WCAG 2.x contrast between two sRGB colors (0xRRGGBB).
    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            func channel(_ shift: UInt32) -> Double {
                let c = Double(hex >> shift & 0xFF) / 255
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// `color` laid over `background` at `alpha`, rounded to 8 bits.
    static func over(_ color: UInt32, _ background: UInt32, alpha: Double) -> UInt32 {
        [16, 8, 0].reduce(0) { hex, shift in
            let mixed = Double(color >> shift & 0xFF) * alpha + Double(background >> shift & 0xFF) * (1 - alpha)
            return hex | UInt32(mixed.rounded()) << shift
        }
    }

    typealias P = SuitePalette
    static let surfaces = [P.panel, P.card, P.row, P.rowHover]
    static let sliderText = [P.textPrimary, P.textSecondary, P.accentText, P.stateKeyed]
    static let states = [
        P.stateKeyed, P.stateSelected, P.stateRecording, P.stateSuggested, P.stateWarning, P.stateError,
        P.stateSuccess, P.onionBefore, P.onionAfter,
    ]

    @Test func textAndStateColorsClearFourPointFive() {
        for color in [P.textPrimary, P.textSecondary, P.accentText] + Self.states {
            for look in 0..<4 {
                var backgrounds = Self.surfaces.map { $0.values[look] }
                if Self.sliderText.contains(color) { backgrounds += [P.valueFill.values[look], P.dragFill.values[look]] }
                if Self.states.contains(color) {
                    let alpha = look % 2 == 0 ? Double(P.tintDark) : Double(P.tintLight)
                    backgrounds.append(Self.over(color.values[look], P.panel.values[look], alpha: alpha))
                }
                for background in backgrounds {
                    #expect(Self.contrast(color.values[look], background) >= 4.5, "\(color) on \(background) in \(look)")
                }
            }
        }
    }

    @Test func marksClearThreeAndWhiteOnTheFillClearsFourPointFive() {
        for look in 0..<4 {
            for background in [P.panel, P.row] {
                #expect(Self.contrast(P.accent.values[look], background.values[look]) >= 3)
            }
            #expect(Self.contrast(P.marker.values[look], P.valueFill.values[look]) >= 3)
            #expect(Self.contrast(P.markerDragging.values[look], P.dragFill.values[look]) >= 4.5)
            #expect(Self.contrast(0xFFFFFF, P.accentFill.values[look]) >= 4.5)
        }
        // The figures docs/design.md quotes.
        #expect(abs(Self.contrast(P.accent.dark, P.row.dark) - 3.02) < 0.01)
        #expect(abs(Self.contrast(P.marker.dark, P.valueFill.dark) - 3.86) < 0.01)
        #expect(abs(Self.contrast(0xFFFFFF, P.accentFill.dark) - 5.05) < 0.01)
    }

    /// The token sheet for waves 2 to 4 (SuiteUI blueprint section 6.2, #774): the timeline
    /// slot, the rotate zone, the point mark, the node graph, the insertion line and the
    /// 20 pt icon-button hit, each at its value, so no later wave edits Tokens.swift.
    @Test func geometry() {
        let sizes = [
            SuiteSize.timelineSlotMinimum, SuiteSize.timelineSlotToolbar, SuiteSize.timelineGrab,
            SuiteSize.rotateZone, SuiteSize.pointMarkRing, SuiteSize.pointMarkCross, SuiteSize.pointMarkInk,
            SuiteSize.pointMarkPaper, SuiteSize.arrowHead, SuiteSize.arrowStroke, SuiteSize.insertionLine,
            SuiteSize.iconButtonHit,
        ]
        #expect(sizes == [120, 36, 8, 16, 12, 6, 1.5, 3, 6, 1.5, 2, 20])
        #expect(SuiteSize.nodeSize == CGSize(width: 120, height: 56))
        #expect(SuiteSpacing.nodeGap == 32)
        // The slot's collapsed height is its chip row with 4 pt above and below.
        #expect(SuiteSize.timelineSlotToolbar == SuiteSize.chip + 2 * SuiteSpacing.xs)
        #expect(SuiteSize.timelineSlotMinimum > SuiteSize.timelineSlotToolbar)
        // The point mark's paper halo shows on both sides of its ink.
        #expect(SuiteSize.pointMarkPaper > SuiteSize.pointMarkInk)
        // docs/design.md's hit floor: never under 20.
        #expect(SuiteSize.iconButtonHit == 20)
    }

    /// QB-S32: the new token pairs at docs/design.md's ratios, in all four appearances.
    @Test func contrast() {
        for look in 0..<4 {
            // Node text (title and detail) on a `card`-filled node: text, 4.5:1.
            for text in [P.textPrimary, P.textSecondary] {
                #expect(Self.contrast(text.values[look], P.card.values[look]) >= 4.5, "node text in \(look)")
            }
            // The refused-rename message, `stateError` under the row on the panel: text, 4.5:1.
            #expect(Self.contrast(P.stateError.values[look], P.panel.values[look]) >= 4.5, "rename error in \(look)")
            // The timeline slot divider, a 1 pt `hairline` on the editor's `panel`. docs/design.md
            // makes hairlines structure between bars and panels with no minimum (the slot is also
            // found by its toolbar row and the row-resize pointer); it must still differ from the panel.
            #expect(Self.contrast(P.hairline.values[look], P.panel.values[look]) > 1.1, "slot divider in \(look)")
        }
        // The point mark: white ink over its black paper halo, a non-text mark, 3:1 on any pixels.
        #expect(Self.contrast(0xFFFFFF, 0x000000) >= 3)
    }

    /// Every hex row in docs/design.md's Visual language tables is in SuitePalette with those values.
    @Test func paletteMatchesTheDesignDoc() throws {
        let doc = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "../../docs/design.md").standardizedFileURL
        let palette: [String: SuiteHex] = [
            "canvasSurround": P.canvasSurround, "ground": P.ground, "panel": P.panel, "card": P.card, "row": P.row,
            "rowHover": P.rowHover, "valueFill": P.valueFill, "dragFill": P.dragFill, "fieldActive": P.fieldActive,
            "hairline": P.hairline, "outline": P.outline, "tick": P.tick, "marker": P.marker, "laneBed": P.laneBed,
            "accent": P.accent, "textPrimary": P.textPrimary, "textSecondary": P.textSecondary,
            "textTertiary": P.textTertiary, "accentText": P.accentText, "stateKeyed": P.stateKeyed,
            "stateSelected": P.stateSelected, "stateRecording": P.stateRecording, "stateSuggested": P.stateSuggested,
            "stateWarning": P.stateWarning, "stateError": P.stateError, "stateSuccess": P.stateSuccess,
            "onionBefore": P.onionBefore, "onionAfter": P.onionAfter,
        ]
        var seen: Set<String> = []
        for line in try String(contentsOf: doc, encoding: .utf8).split(separator: "\n") {
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 5, cells[0].hasPrefix("`"), cells[1].hasPrefix("`#") else { continue }
            let name = cells[0].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            let hex = cells[1...4].compactMap { UInt32($0.trimmingCharacters(in: CharacterSet(charactersIn: "`#")), radix: 16) }
            #expect(palette[name]?.values == hex, "\(name) in docs/design.md")
            seen.insert(name)
        }
        #expect(seen == Set(palette.keys))
        #expect(P.accentFill.dark == 0x156BDB)
    }
}
