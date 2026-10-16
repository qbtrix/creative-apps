// TimelineLookTests.swift: TL-5's look rules (timeline packet, acceptance
// row TL-5): key fills by state, never by the track's selection (#1423); the
// glyphs; the clip fill as the 24 % mix; 3:1 for keys on a clip in all four
// appearances (#62); the pill inside the visible stretch. macOS only.
import Foundation
import SuiteUI
import Testing

@Suite struct TimelineLookTests {
    private static let keys = [0, 12, 24].map { TimelineKey(frame: $0, shape: .linear) }

    @Test func anIdleKeyOnASelectedTrackStaysSecondaryAndAPickedOneIsTheAccent() {
        let track = TimelineTrack(id: "ball", name: "Ball", keys: Self.keys, isSelected: true)
        #expect(TimelineLook.keyFill(Self.keys[1], on: track, playhead: 30) == SuitePalette.textSecondary)
        let picked = TimelineTrack(id: "ball", name: "Ball", keys: Self.keys, pickedFrames: [12])
        #expect(TimelineLook.keyFill(Self.keys[1], on: picked, playhead: 30) == SuitePalette.accent)
        #expect(TimelineLook.keyFill(Self.keys[2], on: picked, playhead: 30) == SuitePalette.textSecondary)
    }

    @Test func aKeyAtThePlayheadIsKeyedPickedOrNot() {
        let picked = TimelineTrack(id: "ball", name: "Ball", keys: Self.keys, pickedFrames: [12], isSelected: true)
        #expect(TimelineLook.keyFill(Self.keys[1], on: picked, playhead: 12) == SuitePalette.stateKeyed)
        let idle = TimelineTrack(id: "ball", name: "Ball", keys: Self.keys)
        #expect(TimelineLook.keyFill(Self.keys[2], on: idle, playhead: 24) == SuitePalette.stateKeyed)
        #expect(TimelineLook.keyFill(Self.keys[0], on: idle, playhead: 24) == SuitePalette.textSecondary)
    }

    @Test func theEdgeIsPanelIdleAndPickedEdgeWhenPicked() {
        let idle = TimelineLook.keyEdge(picked: false)
        let picked = TimelineLook.keyEdge(picked: true)
        #expect(idle.color == SuitePalette.panel && idle.width == 1)
        #expect(picked.color == TimelineLook.pickedEdge && picked.width == 1)
        #expect(TimelineLook.pickedEdge.dark == 0xFFFFFF && TimelineLook.pickedEdge.darkContrast == 0xFFFFFF)
    }

    @Test func eachShapeHasItsGlyphAtTenDrawnAndSixteenToHit() {
        #expect(TimelineLook.keyPath(.linear).glyph == .diamond)
        #expect(TimelineLook.keyPath(.eased).glyph == .circle)
        #expect(TimelineLook.keyPath(.hold).glyph == .square)
        for shape in [TimelineKeyShape.linear, .eased, .hold] {
            let path = TimelineLook.keyPath(shape)
            #expect(path.drawSize == 10 && path.hitSize == 16)
        }
    }

    @Test func clipFillIsTheAccentAQuarterIntoThePanel() {
        let fill = TimelineLook.clipFill.values
        let accent = SuitePalette.accent.values
        let panel = SuitePalette.panel.values
        for i in fill.indices {
            let mix = TokensTests.over(accent[i], panel[i], alpha: 0.24)
            for shift: UInt32 in [16, 8, 0] {
                let drift = abs(Int(fill[i] >> shift & 0xFF) - Int(mix >> shift & 0xFF))
                #expect(drift <= 1, "appearance \(i): clipFill \(String(fill[i], radix: 16)) vs mix \(String(mix, radix: 16))")
            }
        }
    }

    @Test func keysReadOnAClipInAllFourAppearances() {
        let fill = TimelineLook.clipFill.values
        let idle = TimelineLook.keyFill(picked: false, atPlayhead: false).values
        let edge = TimelineLook.keyEdge(picked: true).color.values
        for i in fill.indices {
            #expect(TokensTests.contrast(idle[i], fill[i]) >= 3, "appearance \(i): idle key on a clip")
            #expect(TokensTests.contrast(edge[i], fill[i]) >= 3, "appearance \(i): picked key's edge on a clip")
        }
    }

    @Test func aHoldKeyStepsAndAnEasedOneShowsItsCurveGlyphFrom24Points() {
        let (hold, linear, eased) = (TimelineKey(frame: 0, shape: .hold), TimelineKey(frame: 6, shape: .linear),
                                     TimelineKey(frame: 0, shape: .eased))
        let step = TimelineLook.segment(from: hold, at: 0, to: linear, at: 120)
        #expect(step.kind == .step && step.curveGlyphX == nil)
        let line = TimelineLook.segment(from: linear, at: 0, to: hold, at: 120)
        #expect(line.kind == .line && line.curveGlyphX == nil)
        let wide = TimelineLook.segment(from: eased, at: 10, to: linear, at: 34)
        #expect(wide.kind == .line && wide.curveGlyphX == 22)
        let narrow = TimelineLook.segment(from: eased, at: 10, to: linear, at: 33)
        #expect(narrow.kind == .line && narrow.curveGlyphX == nil)
    }

    @Test func thePillStaysInsideTheVisibleStretch() {
        let mapping = FrameMapping(duration: 120, frameWidth: 10)
        let visible = 0.0...600.0
        let first = TimelineLook.pillRect(
            playheadX: mapping.x(forFrame: 0), labelWidth: 14, height: 20, visible: visible)
        #expect(first.minX >= visible.lowerBound && first.maxX <= visible.upperBound)
        #expect(Double(first.minX) == TimelineLook.pillInset)
        let lastStretch = 600.0...1200.0
        let last = TimelineLook.pillRect(
            playheadX: mapping.x(forFrame: 120), labelWidth: 21, height: 20, visible: lastStretch)
        #expect(last.minX >= lastStretch.lowerBound && last.maxX <= lastStretch.upperBound)
        #expect(Double(last.maxX) == lastStretch.upperBound - TimelineLook.pillInset)
        let middle = TimelineLook.pillRect(playheadX: 300, labelWidth: 14, height: 20, visible: visible)
        #expect(middle.midX == 300 && middle.width == 30 && middle.height == 20)
    }
}
