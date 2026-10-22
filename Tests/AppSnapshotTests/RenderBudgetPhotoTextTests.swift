// RenderBudgetPhotoTextTests.swift (text-layers TX-4): what typing into the Type tool's box costs the real
// Photo window, on the render budget harness (RenderBudgetHarness.swift). It hosts PhotoWindow in a
// key-capable window on the `sample` fixture with a box clicked open, then types 20 letters into the box's
// field; each keystroke runs PhotoEditor's body (a debug-only counter) at most 3 times, never the whole
// window per sample. `inspector` writes photo-text-inspector-light/dark.png: the Text section for a
// "SALE" layer restyled to 120 pt, centered. Nested in BodyCountSuites, as every suite that reads a body
// counter is. macOS only.
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
        @Test(.timeLimit(.minutes(2))) func typeTwentyCharsInThreeBodiesEach() async throws {
            var open = try PhotoWorkspace.fixture(.sample)
            open.selectTool(.text)
            let at = Mask.Point(x: 40, y: 40)
            open.drag(from: at, to: at)
            open.endDrag()
            #expect(open.textBox != nil, "a Type tool click opened no box")
            let w = RenderBudgetWindow(PhotoWindow(model: open).allowsWindowActivationEvents(), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            #expect(await w.element("photo.text.box") != nil, "no text box field (photo.text.box)")
            let step = try await w.measure("photo type 20 chars", bodies: bodies) {
                try await w.ticks(20) { _ in
                    BodyCountSuites.RenderBudgetNewDocumentTests.press("a", keyCode: 0, in: w.window)
                }
            }
            // Budget 3 bodies a keystroke; target 1, the draft's own redraw.
            expectBodies(step, atMost: 60, target: 20)
        }
    }
}

@MainActor @Suite struct PhotoTextInspectorSnapshots {
    @Test func inspector() throws {
        var model = PhotoWorkspace()
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
