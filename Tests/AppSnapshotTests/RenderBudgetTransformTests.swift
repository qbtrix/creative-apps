// RenderBudgetTransformTests.swift: what the transform tools cost in a real
// 1280 x 820 window (transform-tools TT-4, the packet's budgets). The page is
// the gallery's `transform-handles` layout under a root with its own body
// counter: a box with SelectionHandlesEditor and TransformRows beside it, the
// panel applying each turn (the drag's start turn plus the turn so far),
// resize and row edit to its local box, so an edit redraws the panel, never
// the window; `budget.turn` reads the turn in whole degrees. A knob drag
// (`knobDragInThreeBodies`), a right-handle drag on the box turned 30°
// (`turnedResizeInThreeBodies`) and 120 rotation-row steps
// (`rotationScrubInThreeBodies`) each gate at most 3 window bodies and that
// the edit landed; `timing` (Tests/perf-suites.txt, report-only) runs all
// three again and judges each p95 step within 8 ms. Nested in
// BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

/// The window's root, counting its bodies; the box and its edits live in the panel under it, as on the gallery page.
private struct TransformBudgetPage: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif
    let item: TransformBox

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        TransformBudgetPanel(item: item)
    }
}

/// The `transform-handles` layout; `budget.box` is the unturned box, `budget.turn` its turn.
private struct TransformBudgetPanel: View {
    @State var item: TransformBox
    /// The turn when the open knob drag began; nil between drags.
    @State private var startTurn: Double?

    var body: some View {
        let b = item.box
        let rect = CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height)
        HStack(alignment: .top, spacing: SuiteSpacing.m) {
            ZStack(alignment: .topLeading) {
                SuiteColor.overlayPaper
                Color.clear.frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false).accessibilityElement().accessibilityLabel("Box")
                    .accessibilityIdentifier("budget.box")
                Color.clear.frame(width: 1, height: 1).allowsHitTesting(false).accessibilityElement()
                    .accessibilityLabel("\(Int(item.degrees.rounded()))").accessibilityIdentifier("budget.turn")
                SelectionHandlesEditor(rect: rect, degrees: item.degrees, zoom: 1, onResize: resize,
                                       onRotate: rotate, onEnd: { startTurn = nil })
            }
            .frame(width: 400, height: 300, alignment: .topLeading)
            TransformRows(selection: item, help: nil, flipHelp: nil, onIntent: apply)
                .frame(width: SuiteSize.inspectorWidth.ideal)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    private func resize(_ next: CGRect) {
        item.box = Rect(minX: Double(next.minX), minY: Double(next.minY), maxX: Double(next.maxX), maxY: Double(next.maxY))
    }

    /// A knob sample, the turn so far since the press: the start turn plus it.
    private func rotate(_ turned: Double) {
        let start = startTurn ?? item.degrees
        startTurn = start
        item.degrees = TransformRules.normalized(start + turned)
    }

    private func apply(_ intent: TransformIntent) {
        switch intent {
        case let .set(next, _): item = next
        case let .rotate(by, _): item.degrees += by
        default: break
        }
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetTransformTests {
        private static let box = Rect(minX: 100, minY: 80, maxX: 300, maxY: 200)

        private static let bodies = { () -> Int? in
            #if DEBUG
            return TransformBudgetPage.bodyRuns
            #else
            return nil
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func knobDragInThreeBodies() async throws {
            expectBodies(try await Self.knobDrag(), atMost: 3, target: 1)
        }

        @Test(.timeLimit(.minutes(2))) func turnedResizeInThreeBodies() async throws {
            expectBodies(try await Self.turnedResize(), atMost: 3, target: 1)
        }

        @Test(.timeLimit(.minutes(2))) func rotationScrubInThreeBodies() async throws {
            expectBodies(try await Self.rotationScrub(), atMost: 3, target: 1)
        }

        @Test(.timeLimit(.minutes(4))) func timing() async throws {
            let (knob, resize, scrub) = try await (Self.knobDrag(), Self.turnedResize(), Self.rotationScrub())
            expectP95(knob, atMost: 8, target: 4)
            expectP95(resize, atMost: 8, target: 4)
            expectP95(scrub, atMost: 8, target: 4)
        }

        /// A quarter turn of the rotate knob over 120 samples, which turns the box about 90°.
        static func knobDrag() async throws -> RenderStep {
            let w = RenderBudgetWindow(TransformBudgetPage(item: TransformBox(box: Self.box)))
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            let frame = try #require(await w.element("budget.box"), "no box on the page")
            let knob = try #require(await w.element("suite.handles.rotate"), "no rotate knob on the page")
            let centre = CGPoint(x: frame.midX, y: frame.midY)
            let start = CGPoint(x: knob.midX, y: knob.midY), radius = start.y - centre.y
            // A quarter turn clockwise on screen: window points are y-up.
            let step = try await w.measure("transform knob drag, 120 samples", bodies: Self.bodies) {
                try await w.drag(from: start) { i in
                    let a = Double.pi / 2 - Double.pi / 2 * Double(i) / 120
                    return CGPoint(x: centre.x + radius * cos(a), y: centre.y + radius * sin(a))
                }
            }
            try await w.settle()
            let turn = try #require(w.label("budget.turn").flatMap { Double($0) }, "no budget.turn on the page")
            #expect(abs(turn - 90) <= 3, "the knob drag turned the box to \(turn)°, not about 90°")
            return step
        }

        /// A 40 pt drag of the right handle on the box turned 30°, which grows W.
        static func turnedResize() async throws -> RenderStep {
            let w = RenderBudgetWindow(TransformBudgetPage(item: TransformBox(box: Self.box, degrees: 30)))
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            let frame = try #require(await w.element("budget.box"), "no box on the page")
            // The right handle turned 30° clockwise on screen about the centre; window points are y-up.
            let a = Double.pi / 6, half = frame.width / 2
            let start = CGPoint(x: frame.midX + half * cos(a), y: frame.midY - half * sin(a))
            let step = try await w.measure("transform turned resize, 120 samples", bodies: Self.bodies) {
                try await w.drag(from: start, by: CGVector(dx: 40 * cos(a), dy: -40 * sin(a)))
            }
            try await w.settle()
            // The press hit the turned right handle: W grew by about the 40 pt drag.
            let grown = try #require(await w.element("budget.box"), "no box after the drag")
            #expect(grown.width > frame.width + 20, "W went from \(frame.width) to \(grown.width), not about +40")
            return step
        }

        /// 120 VoiceOver steps of the Rotation row.
        static func rotationScrub() async throws -> RenderStep {
            let w = RenderBudgetWindow(TransformBudgetPage(item: TransformBox(box: Self.box)))
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            var found = false
            let step = try await w.measure("transform rotation row, 120 steps", bodies: Self.bodies) {
                found = try await w.adjust("suite.transform.rotation", steps: 120)
            }
            #expect(found, "no rotation row (suite.transform.rotation) on the page")
            return step
        }
    }
}
#endif
