// TimelineLookTests.swift: TL-5's look rules. A key on a selected track with
// nothing picked stays secondary text (#1423); a picked key is the accent and
// a key at the playhead is keyed, picked or not. Linear, eased and hold keys
// draw a diamond, a circle and a square, 10 pt drawn and 16 pt to hit. The
// clip fill is the accent 24 % into the panel within 1/255 in all four
// appearances, and on it the idle key fill and the picked key's edge reach
// 3:1 (#62). The time pill stays inside the visible stretch at frame 0 and at
// the last frame. No SwiftUI. macOS only.
import Foundation
import SuiteUI
import Testing

@Suite struct TimelineLookTests {
    private static let keys = [0, 12, 24].map { TimelineKey(frame: $0, shape: .linear) }

    @Test func anIdleKeyOnASelectedTrackStaysSecondary() {
        let track = TimelineTrack(id: "ball", name: "Ball", keys: Self.keys, isSelected: true)
        #expect(TimelineLook.keyFill(Self.keys[1], on: track, playhead: 30) == SuitePalette.textSecondary)
        #expect(TimelineLook.keyFill(picked: false, atPlayhead: false) == SuitePalette.textSecondary)
    }

    @Test func aPickedKeyIsTheAccentOnAnyTrack() {
        let track = TimelineTrack(id: "ball", name: "Ball", keys: Self.keys, pickedFrames: [12])
        #expect(TimelineLook.keyFill(Self.keys[1], on: track, playhead: 30) == SuitePalette.accent)
        #expect(TimelineLook.keyFill(Self.keys[2], on: track, playhead: 30) == SuitePalette.textSecondary)
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
            #expect(path.hitRect(center: CGPoint(x: 40, y: 16)) == CGRect(x: 32, y: 8, width: 16, height: 16))
            #expect(path.drawRect(center: CGPoint(x: 40, y: 16)) == CGRect(x: 35, y: 11, width: 10, height: 10))
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

    @Test func aHoldKeySteps() {
        let hold = TimelineLook.segment(from: .init(frame: 0, shape: .hold), at: 0, to: .init(frame: 12, shape: .linear), at: 120)
        #expect(hold.kind == .step && hold.curveGlyphX == nil)
        let line = TimelineLook.segment(from: .init(frame: 0, shape: .linear), at: 0, to: .init(frame: 12, shape: .hold), at: 120)
        #expect(line.kind == .line && line.curveGlyphX == nil)
    }

    @Test func anEasedKeyShowsItsCurveGlyphFrom24Points() {
        let eased = TimelineKey(frame: 0, shape: .eased)
        let next = TimelineKey(frame: 6, shape: .linear)
        let wide = TimelineLook.segment(from: eased, at: 10, to: next, at: 34)
        #expect(wide.kind == .line && wide.curveGlyphX == 22)
        let narrow = TimelineLook.segment(from: eased, at: 10, to: next, at: 33)
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
