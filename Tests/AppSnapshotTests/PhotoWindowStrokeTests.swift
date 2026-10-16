// PhotoWindowStrokeTests.swift: what a brush stroke costs the real Photo
// window, on the render budget harness (RenderBudgetHarness.swift). It hosts
// PhotoWindow itself (State, renderer, pacer, every panel and area modifier)
// on the `large` fixture, brush 64 px, and sends it a mouse-down, 120 dragged
// events at 120 Hz and a mouse-up, so CanvasViewport's drag gesture reaches
// PhotoWindow.perform as a hand's would. Spec, during the stroke: the tile
// layers show it, PhotoEditor's body runs at most once (a debug-only counter)
// and no large layer is drawn on the CPU (CALayer `display`, swizzled for the
// process); after it, the window's workspace holds the stroke as one "Undo
// Paint" step. Layout passes and step times are reported, not judged here;
// RenderBudgetPhotoTests' timing test judges them.
// PHOTO_WINDOW_STROKE_SECONDS=20 first strokes for that long, for `sample`.
// The suite nests in BodyCountSuites: it reads a process-global body counter.
import AppKit
import ObjectiveC
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct PhotoWindowStrokeTests {
        @Test(.timeLimit(.minutes(2))) func aBrushStrokeRedrawsOnlyTheCanvas() async throws {
            let stroke = try await Self.stroke()
            let report = stroke.report
            #expect(stroke.inked > 0, "the canvas showed nothing while drawing: \(report)")
            if let editorRuns = stroke.step.bodies {
                #expect(editorRuns <= 1, "the editor ran again during the stroke: \(report)")
            }
            #expect(stroke.bigDisplays == 0, "a large layer was drawn on the CPU during the stroke: \(report)")
            #expect(stroke.after.isDirty && stroke.after.revision > stroke.before.revision, "the window never took the stroke: \(report)")
            #expect(stroke.after.undoActionName == "Undo Paint", "mouse-up left no Paint step: \(report)")
        }

        struct Stroke {
            let step: RenderStep
            /// Tile layers whose image changed during the stroke.
            let inked: Int
            /// CPU layer displays of 256 x 256 or more during the stroke.
            let bigDisplays: Int
            let before: PhotoWorkspace
            let after: PhotoWorkspace
            let report: String
        }

        /// One 120-sample stroke on the hosted window, measured until just before its mouse-up.
        static func stroke() async throws -> Stroke {
            var open = try PhotoWorkspace.fixture(.large)
            open.selectTool(.brush)
            open.setToolOption(.size(64))
            let w = RenderBudgetWindow(PhotoWindow(model: open))
            defer { w.close() }

            // The first picture: every tile layer has its image (seconds in debug).
            let canvas = try #require(await w.first(TileCanvasView.self))
            for _ in 0..<600 where tileImages(canvas).isEmpty { try await Task.sleep(for: .milliseconds(50)) }
            let shown = tileImages(canvas)
            try #require(!shown.isEmpty, "the canvas never showed its first picture")
            try await w.settle()
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let before = try #require(edited.workspace)

            let box = canvas.convert(canvas.bounds, to: nil)
            let seconds = Double(ProcessInfo.processInfo.environment["PHOTO_WINDOW_STROKE_SECONDS"] ?? "") ?? 0
            let clock = ContinuousClock()
            let until = clock.now + .seconds(seconds)
            var row = 0
            while clock.now < until {
                row += 1
                let y = box.minY + 40 + Double(row * 23 % Int(max(box.height - 80, 1)))
                let start = CGPoint(x: box.minX + box.width * 0.25, y: y)
                try await w.drag(from: start, release: false, path: wave(from: start))
                w.send(.leftMouseUp, at: CGPoint(x: start.x + 360, y: y))
            }
            // The last of those strokes lands its panels before the measured one starts.
            if seconds > 0 { try await Task.sleep(for: .milliseconds(500)) }
            let start = CGPoint(x: box.minX + box.width * 0.25, y: box.midY)
            LayerDisplays.start(in: w.host)
            // `measure` lets the stroke's last renders land before the mouse comes up.
            let step = try await w.measure("photo brush stroke, 120 samples", bodies: editorBodies) {
                try await w.drag(from: start, release: false, path: wave(from: start))
            }
            let drawn = LayerDisplays.stop()
            let inked = Set(tileImages(canvas)).subtracting(shown).count
            w.send(.leftMouseUp, at: CGPoint(x: start.x + 360, y: start.y))
            for _ in 0..<100 where edited.workspace?.isDirty != true { try await Task.sleep(for: .milliseconds(20)) }
            let after = try #require(edited.workspace)

            let kinds = Dictionary(grouping: drawn, by: \.name).map { "\($1.count)x \($0)" }.sorted()
            let report = [
                "WINDOW-STROKE config=\(PhotoBrushLatencyTests.config) canvas=4000x3000 window=1280x820 | \(step) |",
                "CPU layer displays \(drawn.count) (\(kinds.joined(separator: ", "))) | tile layers inked \(inked) |",
                "after: dirty \(after.isDirty), revision \(before.revision) -> \(after.revision)",
            ].joined(separator: " ")
            print(report)
            return Stroke(
                step: step, inked: inked, bigDisplays: drawn.filter { $0.area >= 256 * 256 }.count, before: before,
                after: after, report: report)
        }

        /// PhotoEditor's body runs so far; nil in release, which has no counter.
        static func editorBodies() -> Int? {
            #if DEBUG
            return PhotoEditor.bodyRuns
            #else
            return nil
            #endif
        }

        /// Sample i of a stroke from `start`: 3 px apart on a wave.
        private static func wave(from start: CGPoint) -> (Int) -> CGPoint {
            { i in CGPoint(x: start.x + 3 * Double(i), y: start.y + 40 * sin(Double(i) / 12)) }
        }

        /// The images the tile layers show now.
        private static func tileImages(_ canvas: TileCanvasView) -> [ObjectIdentifier] {
            (canvas.layer?.sublayers?.first?.sublayers ?? []).compactMap {
                ($0.contents as AnyObject?).map(ObjectIdentifier.init)
            }
        }
    }
}

/// The CPU-drawn layer displays in one view's layer tree while recording.
/// CALayer's `display` is swapped once per process for one that logs and then
/// draws as before; layers of other windows (other suites) aren't logged.
/// Only the main thread touches the log.
enum LayerDisplays {
    struct Display {
        let name: String
        let area: Double
    }

    nonisolated(unsafe) private static var root: CALayer?
    nonisolated(unsafe) private static var log: [Display] = []
    private static let installed: Bool = {
        guard let original = class_getInstanceMethod(CALayer.self, #selector(CALayer.display)),
            let logging = class_getInstanceMethod(CALayer.self, #selector(CALayer.photoTestLoggedDisplay))
        else { return false }
        method_exchangeImplementations(original, logging)
        return true
    }()

    @MainActor static func start(in view: NSView) {
        #expect(installed, "CALayer.display couldn't be swapped")
        (root, log) = (view.layer, [])
    }

    @MainActor static func stop() -> [Display] {
        root = nil
        return log
    }

    static func note(_ layer: CALayer) {
        guard let root else { return }
        var up: CALayer? = layer
        while let current = up, current !== root { up = current.superlayer }
        guard up != nil else { return }
        let size = layer.bounds.size
        log.append(Display(name: "\(type(of: layer)) \(Int(size.width))x\(Int(size.height))", area: size.width * size.height))
    }
}

extension CALayer {
    /// After the swap this runs for `display`, and the call inside runs the original.
    /// The window's layers display on the main thread; others go unlogged.
    @objc func photoTestLoggedDisplay() {
        if Thread.isMainThread { LayerDisplays.note(self) }
        photoTestLoggedDisplay()
    }
}
