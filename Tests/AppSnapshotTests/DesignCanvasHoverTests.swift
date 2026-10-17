// DesignCanvasHoverTests.swift: the canvas's hover feedback (DesignCanvasFeedback). `pointers` maps
// each hover answer of the `cards` fixture to its pointer: a handle of the selection to that
// handle's frame-resize pointer, a layer to move, the same with Option to drag-copy, the Text tool
// to the I-beam, anything else to the tool's own. `samples` opens `cards` in the real window and
// sends 120 pointer samples inside A through the canvas's own pointer handler, the call its
// continuous hover makes: the window body never runs again and the canvas body at most once, since
// the answer changes only on the first sample. Nested in BodyCountSuites, as every suite that reads
// a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignCanvasHoverTests {
        /// The pointer `model` names for a hover at (x, y).
        private func pointer(_ model: DesignWorkspace, _ x: Double, _ y: Double, _ modifiers: DesignModifiers = [])
            -> DesignCanvasPointer
        {
            let store = DesignCanvasHover()
            store.record(DesignPoint(x: x, y: y), modifiers: modifiers, on: model)
            return DesignCanvasPointer(store.hint(for: model), tool: model.tool)
        }

        @Test func pointers() {
            var model = DesignFixtures.cards
            #expect(pointer(model, 150, 140) == .move)
            #expect(pointer(model, 150, 140, .option) == .copy)
            #expect(pointer(model, 5000, 5000) == .tool(.move))
            model.selectItem("node-2")
            // A is (100, 100, 100 × 80): its corners and edge midpoints are its handles.
            #expect(pointer(model, 100, 100) == .resize(.topLeading))
            #expect(pointer(model, 150, 100) == .resize(.top))
            #expect(pointer(model, 200, 100) == .resize(.topTrailing))
            #expect(pointer(model, 200, 140) == .resize(.trailing))
            #expect(pointer(model, 200, 180) == .resize(.bottomTrailing))
            #expect(pointer(model, 150, 180) == .resize(.bottom))
            #expect(pointer(model, 100, 180) == .resize(.bottomLeading))
            #expect(pointer(model, 100, 140) == .resize(.leading))
            model.selectTool(.text)
            #expect(pointer(model, 150, 140) == .text)
            model.selectTool(.rectangle)
            #expect(pointer(model, 150, 140) == .tool(.rectangle))
            #expect(DesignCanvasPointer(nil, tool: .ellipse) == .tool(.ellipse))
        }

        @Test func handlePositions() {
            let positions = DesignHandle.allCases.map(\.position)
            #expect(Set(positions).count == DesignHandle.allCases.count)
            #expect(DesignHandle.bottomRight.position == .bottomTrailing)
            #expect(DesignHandle.topLeft.position == .topLeading)
        }

        @Test func noOutlineMidDrag() {
            var model = DesignFixtures.cards
            let store = DesignCanvasHover()
            let a = DesignPoint(x: 150, y: 140)
            model.drag(from: a, to: a)
            store.record(a, modifiers: [], on: model)
            #expect(store.hint(for: model) == nil)
            model.endDrag()
        }

        @Test func otherPage() {
            var model = DesignFixtures.twoPages
            let store = DesignCanvasHover()
            store.record(DesignPoint(x: 150, y: 140), modifiers: [], on: model)
            #expect(store.hint(for: model) != nil)
            model.selectPage("page-2")
            #expect(store.hint(for: model) == nil)
        }

        @Test(.timeLimit(.minutes(2))) func samples() async throws {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("hover-cards-\(UUID()).design")
            let data = try DesignFixtures.cards.fileData()
            try data.write(to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            let w = RenderBudgetWindow(DesignWindow(launch: DesignLaunch(file: file)))
            defer { w.close() }
            try await w.settle(800)
            _ = try #require(await w.element("suite.canvas"), "no canvas")
            // The same document and page the window shows, so the shared store's answer is its canvas's.
            var model = DesignWorkspace()
            try model.open(data, at: file)
            let shared = DesignCanvasHover.shared
            defer { shared.record(nil, modifiers: [], on: model) }
            let handler = try #require(DesignCanvasFeedback(model: model, zoom: 1).onPointer)
            #if DEBUG
            let windowBefore = DesignWindow.bodyRuns
            shared.canvasReads = 0
            #endif
            // 120 samples inside A (100, 100, 100 × 80), one per 1/120 s.
            try await w.ticks(120) { i in handler(CGPoint(x: 110 + Double(i % 80), y: 110 + Double(i % 60))) }
            try await w.settle(300)
            let hint = try #require(shared.hint(for: model))
            #expect(hint.nodeID == "node-2")
            #expect(hint.pointer == .move)
            #if DEBUG
            #expect(DesignWindow.bodyRuns - windowBefore == 0, "the window body ran on hover")
            #expect(shared.canvasReads <= 1, "the canvas body ran \(shared.canvasReads) times over 120 hover samples")
            // TODO(D0-8b): expect DesignEditor.bodyRuns to stay 0 over these samples once D0-8b adds that counter.
            #endif
        }
    }
}
#endif
