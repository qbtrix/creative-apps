// PhotoStrokePacerTests.swift: StrokePacer hands the window's drag samples to
// the workspace in order: the first at once, the ones that come within its
// spacing in one later call, made unasked from the main run loop. Each
// sample keeps its own modifier keys. The canvas overlay shows a pending crop
// as the element `photo.canvas.crop`, an image and not a button (read from
// PhotoCanvasOverlay's `marks` and PhotoCanvasMark's traits: there is no
// accessibility-tree helper in these tests). macOS only.
import AppKit
import CoreRaster
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoStrokePacerTests {
    @Test func theFirstSampleAppliesAtOnceAndQuickOnesWaitTogetherInOrder() {
        let pacer = StrokePacer(spacing: .milliseconds(50))
        var calls: [[Double]] = []
        for x in 0..<3 {
            let move = (from: Mask.Point(x: Double(x), y: 0), to: Mask.Point(x: Double(x) + 1, y: 0), pressure: 1.0, modifiers: DragModifiers())
            pacer.add(move) { calls.append($0.map(\.from.x)) }
        }
        #expect(calls == [[0]])
        // The waiting pair applies unasked once the spacing has passed, from the main run loop.
        for _ in 0..<100 where calls.count < 2 { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        #expect(calls == [[0], [1, 2]])
        pacer.add((from: Mask.Point(x: 3, y: 0), to: Mask.Point(x: 4, y: 0), pressure: 1, modifiers: DragModifiers())) { calls.append($0.map(\.from.x)) }
        pacer.stop()
        pacer.flush()
        #expect(calls.flatMap { $0 } == [0, 1, 2, 3])
    }

    @Test func aSampleAfterTheSpacingAppliesAtOnce() {
        let pacer = StrokePacer(spacing: .zero)
        var calls: [[Double]] = []
        for x in 0..<3 {
            let move = (from: Mask.Point(x: Double(x), y: 0), to: Mask.Point(x: Double(x) + 1, y: 0), pressure: 1.0, modifiers: DragModifiers())
            pacer.add(move) { calls.append($0.map(\.from.x)) }
        }
        #expect(calls == [[0], [1], [2]])
    }

    @Test func eachSampleInAFrameKeepsItsOwnModifiers() {
        let pacer = StrokePacer()
        var applied: [DragModifiers] = []
        let held: [DragModifiers] = [.shift, [], [.shift, .option], .option]
        for (x, keys) in held.enumerated() {
            let move = (from: Mask.Point(x: Double(x), y: 0), to: Mask.Point(x: Double(x) + 1, y: 0), pressure: 1.0, modifiers: keys)
            pacer.add(move) { applied += $0.map(\.modifiers) }
        }
        pacer.stop()
        #expect(applied == held)
    }

    @Test func modifierFlagsMapToDragModifiers() {
        let none: NSEvent.ModifierFlags = []
        let shiftCommand: NSEvent.ModifierFlags = [.shift, .command]
        let optionShift: NSEvent.ModifierFlags = [.option, .shift]
        #expect(DragModifiers(flags: none).isEmpty)
        #expect(DragModifiers(flags: shiftCommand) == .shift)
        #expect(DragModifiers(flags: optionShift) == [.shift, .option])
    }

    @Test func aPendingCropIsAnIdentifiedImageNotAButton() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        #expect(PhotoCanvasOverlay(model: model, zoom: 1, hover: nil).marks.isEmpty)
        model.selectTool(.crop)
        model.drag(from: Mask.Point(x: 40, y: 40), to: Mask.Point(x: 40, y: 40))
        model.drag(from: Mask.Point(x: 40, y: 40), to: Mask.Point(x: 600, y: 400))
        model.endDrag()
        let crop = PhotoCanvasOverlay(model: model, zoom: 0.5, hover: nil).marks
            .first { $0.identifier == "photo.canvas.crop" }
        #expect(crop?.label == "Crop area")
        #expect(crop?.rect == model.pendingCrop?.cgRect)
        #expect(PhotoCanvasMark.traits.contains(.isImage))
        #expect(!PhotoCanvasMark.traits.contains(.isButton))
    }
}
