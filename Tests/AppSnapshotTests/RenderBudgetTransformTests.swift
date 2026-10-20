// RenderBudgetTransformTests.swift: what the transform tools cost in a real
// 1280 x 820 window (transform-tools TT-4, the packet's budgets). The page is
// the gallery's `transform-handles` layout under a root with its own body
// counter: a box with SelectionHandlesEditor and TransformRows beside it, the
// panel applying each turn, resize and row edit to its local box, so an edit
// redraws the panel, never the window. A knob drag
// (`knobDragInThreeBodies`), a right-handle drag on the box turned 30°
// (`turnedResizeInThreeBodies`) and 120 rotation-row steps
// (`rotationScrubInThreeBodies`) each run at most 3 window bodies with a p95
// step at most 8 ms. Nested in BodyCountSuites: it reads a global body
// counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

/// The window's root, counting its bodies; the box and its edits live in the panel under it, as on the gallery page.
private struct TransformBudgetPage: View {
    #if DEBUG
    static var bodyRuns = 0
    #endif
    let item: TransformBox

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        TransformBudgetPanel(item: item)
    }
}

/// The `transform-handles` layout; `budget.box` is the unturned box.
private struct TransformBudgetPanel: View {
    @State var item: TransformBox

    var body: some View {
        let b = item.box
        let rect = CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height)
        HStack(alignment: .top, spacing: SuiteSpacing.m) {
            ZStack(alignment: .topLeading) {
                SuiteColor.overlayPaper
                Color.clear.frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false).accessibilityElement().accessibilityLabel("Box")
                    .accessibilityIdentifier("budget.box")
                SelectionHandlesEditor(rect: rect, degrees: item.degrees, zoom: 1, onResize: resize,
                                       onRotate: { _ in }, onEnd: {})
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
            expectBodies(step, atMost: 3, target: 1)
            expectP95(step, atMost: 8, target: 4)
        }

        @Test(.timeLimit(.minutes(2))) func turnedResizeInThreeBodies() async throws {
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
            expectBodies(step, atMost: 3, target: 1)
            expectP95(step, atMost: 8, target: 4)
        }

        @Test(.timeLimit(.minutes(2))) func rotationScrubInThreeBodies() async throws {
            let w = RenderBudgetWindow(TransformBudgetPage(item: TransformBox(box: Self.box)))
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            var found = false
            let step = try await w.measure("transform rotation row, 120 steps", bodies: Self.bodies) {
                found = try await w.adjust("suite.transform.rotation", steps: 120)
            }
            #expect(found, "no rotation row (suite.transform.rotation) on the page")
            expectBodies(step, atMost: 3, target: 1)
            expectP95(step, atMost: 8, target: 4)
        }
    }
}
#endif
