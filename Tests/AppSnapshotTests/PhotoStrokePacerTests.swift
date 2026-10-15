// PhotoStrokePacerTests.swift: StrokePacer hands the window's drag samples to
// the workspace in order, everything that waited for a display frame in one
// call, and the frame's display link does it unasked (when the display is
// awake to show frames). Without a screen each sample applies at once. Each
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
    @Test func samplesWaitingForAFrameArriveTogetherInOrder() {
        let pacer = StrokePacer()
        var calls: [[Double]] = []
        for x in 0..<3 {
            let move = (from: Mask.Point(x: Double(x), y: 0), to: Mask.Point(x: Double(x) + 1, y: 0), pressure: 1.0, modifiers: DragModifiers())
            pacer.add(move) { calls.append($0.map(\.from.x)) }
        }
        if NSScreen.main == nil {
            #expect(calls == [[0], [1], [2]])
        } else {
            #expect(calls.isEmpty)
            if CGDisplayIsAsleep(CGMainDisplayID()) == 0 {
                // The display link runs on the main run loop; a frame is at most 1/24 s.
                for _ in 0..<50 where calls.isEmpty { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            } else {
                pacer.flush()  // A sleeping display (a locked Mac) shows no frames.
            }
            #expect(calls == [[0, 1, 2]])
        }
        pacer.add((from: Mask.Point(x: 3, y: 0), to: Mask.Point(x: 4, y: 0), pressure: 1, modifiers: DragModifiers())) { calls.append($0.map(\.from.x)) }
        pacer.stop()
        pacer.flush()
        #expect(calls.flatMap { $0 } == [0, 1, 2, 3])
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
