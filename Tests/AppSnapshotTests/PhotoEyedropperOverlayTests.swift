// PhotoEyedropperOverlayTests.swift (eyedropper PE-3): the Eyedropper's loupe
// over Photo's canvas and its press. PhotoSampleLoupe sits at the pointer's
// document point at the canvas zoom and moves with it, shows only with the
// Eyedropper, and reads no colour past the image's edge. A press through the
// window's pacer (LiveStroke.press) picks once, at its first sample, however
// many samples follow; the Brush picks the same way with Option held at the
// press and paints without it. macOS only.
import AppKit
import CoreRaster
import PhotoModel
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoEyedropperOverlayTests {
    private func model(_ tool: PhotoTool) throws -> PhotoWorkspace {
        var model = PhotoWorkspace(services: .fake)
        try model.newCanvas(width: 64, height: 48)
        model.selectTool(tool)
        return model
    }

    private func move(_ x: Double, _ y: Double, _ keys: DragModifiers = []) -> PhotoStrokeMove {
        (from: Mask.Point(x: x, y: y), to: Mask.Point(x: x, y: y), pressure: 1, modifiers: keys)
    }

    /// Every pick a press's samples make, through the window's pacer as a drag sends them.
    private func picks(_ moves: [PhotoStrokeMove], on model: PhotoWorkspace) -> [Point] {
        let live = LiveStroke(), pacer = StrokePacer()
        var picked: [Point] = []
        for move in moves {
            pacer.add(move) { batch in
                if case .pick(let point)? = live.press(batch, on: model) { picked.append(point) }
            }
        }
        pacer.stop()
        pacer.flush()
        _ = live.take()
        return picked
    }

    @Test func theLoupeTracksThePointerAtTheZoom() throws {
        let model = try model(.eyedropper)
        #expect(PhotoSampleLoupe(model: model, zoom: 2, hover: nil).center == nil, "no loupe off the canvas")
        let track = [CGPoint(x: 1, y: 1), CGPoint(x: 10, y: 20), CGPoint(x: 63, y: 47)]
        let centers = track.map { PhotoSampleLoupe(model: model, zoom: 2, hover: $0).center }
        #expect(centers == [CGPoint(x: 2, y: 2), CGPoint(x: 20, y: 40), CGPoint(x: 126, y: 94)])
    }

    @Test func theLoupeShowsNoColourPastTheEdge() throws {
        let model = try model(.eyedropper)
        let outside = PhotoSampleLoupe(model: model, zoom: 1, hover: CGPoint(x: -5, y: -5))
        #expect(outside.center == CGPoint(x: -5, y: -5), "the hollow loupe still follows the pointer")
        #expect(outside.color == nil)
        #expect(PhotoSampleLoupe(model: model, zoom: 1, hover: CGPoint(x: 64, y: 10)).color == nil)
    }

    @Test func theLoupeIsTheEyedroppers() throws {
        #expect(PhotoSampleLoupe(model: try model(.brush), zoom: 1, hover: CGPoint(x: 5, y: 5)).center == nil)
    }

    @Test func aClickPicksOnce() throws {
        let model = try model(.eyedropper)
        #expect(picks([move(12, 7)], on: model) == [Point(x: 12, y: 7)])
        let drag = [move(12, 7), move(13, 7), move(14, 8), move(20, 9)]
        #expect(picks(drag, on: model) == [Point(x: 12, y: 7)], "a drag picks at its press only")
    }

    @Test func eachPressPicksAgainAfterTheLastEnds() throws {
        let model = try model(.eyedropper), live = LiveStroke()
        #expect(live.press([move(3, 4)], on: model) == .pick(Point(x: 3, y: 4)))
        #expect(live.press([move(5, 4)], on: model) == .hold)
        _ = live.take()
        #expect(live.press([move(9, 9)], on: model) == .pick(Point(x: 9, y: 9)))
    }

    @Test func anOptionClickWithTheBrushPicksAndAPlainOnePaints() throws {
        let brush = try model(.brush)
        #expect(picks([move(30, 20, .option), move(31, 20)], on: brush) == [Point(x: 30, y: 20)])
        #expect(picks([move(30, 20), move(31, 20, .option)], on: brush).isEmpty, "Option counts at the press only")
        #expect(LiveStroke().press([move(30, 20)], on: brush) == nil)
    }
}
