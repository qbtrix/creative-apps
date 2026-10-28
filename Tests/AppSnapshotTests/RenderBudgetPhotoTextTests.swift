// RenderBudgetPhotoTextTests.swift (text-layers TX-4, #5951): what the Type tool and the Text section cost the
// real Photo window, on the render budget harness (RenderBudgetHarness.swift), on an 8K image. Typing 20
// letters into an open box runs PhotoEditor's body (a debug-only counter) at most 3 times a keystroke; its 16 ms
// p95 is a disabled wall-clock test until Tests/perf-suites.txt lists it, and misses today (gap #6000). A
// 120-sample Size scrub on a text layer runs the body at most 3 times in all; a box a canvas click opened
// takes a space and Return adds it as a layer. `inspector` writes photo-text-inspector-light/dark.png: the
// Text section for a "SALE" layer restyled to 120 pt, centered, on the window's live text (its Weight, Style
// and Color rows).
// Nested in BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoTextTests {
        /// An 8K image (7680 x 4320), the packet's size for the text budgets.
        static func eightK() throws -> PhotoWorkspace {
            var open = PhotoWorkspace()
            try open.newCanvas(width: 7680, height: 4320)
            return open
        }

        /// Types 20 letters into a box clicked open on an 8K image; the window's measured step.
        static func typeTwentyOnEightK(_ name: String) async throws -> RenderStep {
            var open = try Self.eightK()
            open.selectTool(.text)
            let at = Mask.Point(x: 400, y: 400)
            open.drag(from: at, to: at)
            open.endDrag()
            #expect(open.textBox != nil, "a Type tool click opened no box")
            let w = RenderBudgetWindow(PhotoWindow(model: open).allowsWindowActivationEvents(), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            #expect(await w.element("photo.text.box") != nil, "no text box field (photo.text.box)")
            let step = try await w.measure(name, bodies: bodies) {
                try await w.ticks(20) { _ in
                    BodyCountSuites.RenderBudgetNewDocumentTests.press("a", keyCode: 0, in: w.window)
                }
            }
            #expect(w.value("photo.text.box") == String(repeating: "a", count: 20), "the box didn't take the 20 letters")
            return step
        }

        @Test(.timeLimit(.minutes(2))) func typeTwentyCharsInThreeBodiesEach() async throws {
            let step = try await Self.typeTwentyOnEightK("photo type 20 chars on 8K")
            // Budget 3 bodies a keystroke; target 1, the draft's own redraw.
            expectBodies(step, atMost: 60, target: 20)
        }

        /// The packet's keystroke budget on 8K, a wall-clock test: off until the supervisor lists it in
        /// Tests/perf-suites.txt. Each key lays the whole editor out again, about 54 ms in debug (gap #6000).
        @Test(.disabled("wall-clock: waits for its Tests/perf-suites.txt line; over budget, gap #6000"),
              .timeLimit(.minutes(2)))
        func typeOnEightKInSixteenMs() async throws {
            let step = try await Self.typeTwentyOnEightK("photo type 20 chars on 8K, timed")
            withKnownIssue("a keystroke lays the whole editor out again on 8K (gap #6000)", isIntermittent: true) {
                expectP95(step, atMost: 16, target: 8)
            }
        }

        /// A 120-sample Size scrub on a text layer of an 8K image: the window body runs at most 3 times.
        @Test(.timeLimit(.minutes(2))) func sizeScrub() async throws {
            var open = try Self.eightK()
            open.selectTool(.text)
            let at = Mask.Point(x: 400, y: 400)
            open.drag(from: at, to: at)
            open.endDrag()
            open.typeText("SALE")
            open.commitTextBox()
            #expect(open.textStyle != nil, "no text layer selected")
            let w = RenderBudgetWindow(PhotoWindow(model: open).allowsWindowActivationEvents())
            defer { w.close() }
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let box = try #require(await w.element("photo.text.size"), "the Text section shows no Size (photo.text.size)")
            let start = CGPoint(x: box.midX, y: box.midY)
            // A control below the window's edge would take the drag nowhere and pass on zero cost.
            #expect(w.host.bounds.insetBy(dx: 0, dy: box.height / 2).contains(start), "Size at \(box) is off the window")
            let before = w.value("photo.text.size")
            let step = try await w.measure("photo text Size scrub, 120 samples on 8K", bodies: bodies) {
                try await w.drag(from: start) { CGPoint(x: start.x + Double($0) / 2, y: start.y) }
            }
            #expect(w.value("photo.text.size") != before, "the scrub didn't move Size")
            expectBodies(step, atMost: 3, target: 0)
        }

        /// PJ-TX (#5951): a Type tool click on the canvas, as the journey makes, then "A B" and Return: the space
        /// reaches the box. The canvas kept focus and took Space for its pan, so SUMMER SALE became SUMMERSALE.
        @Test(.timeLimit(.minutes(2))) func aClickedBoxTakesASpace() async throws {
            var open = try PhotoWorkspace.fixture(.sample)
            open.selectTool(.text)
            let w = RenderBudgetWindow(PhotoWindow(model: open).allowsWindowActivationEvents(), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let canvas = try #require(await w.element("suite.canvas"), "no canvas (suite.canvas)")
            try await w.ticks(1) { _ in w.click(at: CGPoint(x: canvas.midX, y: canvas.midY)) }
            #expect(await w.element("photo.text.box") != nil, "the click opened no box (photo.text.box)")
            try await w.settle(untilStable: bodies)
            let keys: [(String, UInt16)] = [("A", 0), (" ", 49), ("B", 11)]
            try await w.ticks(keys.count) { i in
                BodyCountSuites.RenderBudgetNewDocumentTests.press(keys[i - 1].0, keyCode: keys[i - 1].1, in: w.window)
            }
            try await w.settle(untilStable: bodies)
            #expect(w.value("photo.text.box") == "A B")
            #expect(await w.element("photo.text.size") == nil, "a Text section before any text layer")
            // Return adds the layer: the box closes, and the new text layer, selected, shows the Text section.
            try await w.ticks(1) { _ in
                BodyCountSuites.RenderBudgetNewDocumentTests.press("\r", keyCode: 36, in: w.window)
            }
            try await w.settle(untilStable: bodies)
            #expect(await w.element("photo.text.box") == nil, "Return left the box open")
            #expect(await w.element("photo.text.size") != nil, "Return added no text layer (no Text section)")
        }
    }
}

@MainActor @Suite struct PhotoTextInspectorSnapshots {
    @Test func inspector() throws {
        // The window's own services: Core Text's families, so the Weight and Style rows show the faces the app has.
        var model = PhotoWorkspace(services: PhotoWindow.liveServices)
        try model.newCanvas(width: 640, height: 480)
        model.selectTool(.text)
        let at = Mask.Point(x: 80, y: 120)
        model.drag(from: at, to: at)
        model.endDrag()
        model.typeText("SALE")
        model.commitTextBox()
        model.runText(.size(120, drag: nil))
        model.runText(.alignment(.center))
        #expect(model.textStyle?.size == 120 && model.statusMessage == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoAdjustTab(model: model, perform: { _ in }, showsLayerSettings: true)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 720, alignment: .topLeading)
                    .background(SuiteColor.panel),
                name: "photo-text-inspector-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
#endif
