// DesignWindowDragTests.swift: design-window DW-b's bound on the real window
// (D0-8b). On `crowd` (2,000 layers, `.fake`), a 120-sample move, resize,
// marquee and rectangle draw each run DesignEditor's body 3 times or fewer:
// the samples go to the live drag box (DesignLiveDrag), which only the canvas
// reads. The same gestures on DesignEditor hosted without the box, every
// sample written straight to the workspace, run it about once per sample, so
// the bound can fail. `dragSamples` drives one gesture and counts the editor;
// later drag checks (D0-9d) call it. The window is hosted off screen through
// the render-budget harness (RenderBudgetHarness.swift); DesignEditor.bodyRuns
// is a process-global debug counter, so the suite nests in BodyCountSuites.
// macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignWindowDragTests {
        /// One canvas gesture on `crowd`: its starting workspace, and where it presses and how far it goes
        /// (page points). Frame 1 is node-1 at (10, 10, 160 × 150) and its Rectangle 1 node-2 at
        /// (12, 12, 16 × 16); the page's bottom right corner past (1395, 960) holds no frame.
        enum Gesture: String, CaseIterable, Sendable {
            case move, resize, marquee, draw

            /// `crowd` on the fake services, with the gesture's tool and selection.
            var seed: DesignWorkspace {
                var workspace = DesignFixtures.crowd
                workspace.useServices(.fake)
                switch self {
                case .resize: workspace.selectItem("node-1")
                case .draw: workspace.selectTool(.rectangle)
                case .move, .marquee: break
                }
                return workspace
            }

            /// The press: inside Rectangle 1, on Frame 1's bottom-right handle, or on empty page.
            var from: CGPoint {
                switch self {
                case .move: CGPoint(x: 20, y: 20)
                case .resize: CGPoint(x: 170, y: 160)
                case .marquee, .draw: CGPoint(x: 1420, y: 1010)
                }
            }

            var by: CGVector {
                switch self {
                case .move: CGVector(dx: 160, dy: 90)
                case .resize: CGVector(dx: 120, dy: 80)
                case .marquee, .draw: CGVector(dx: -300, dy: -240)
                }
            }
        }

        static let page = CGSize(width: 1440, height: 1024)

        @Test(.timeLimit(.minutes(3))) func aDragRunsTheEditorAtMostThreeTimes() async throws {
            #if DEBUG
            for gesture in Gesture.allCases {
                let w = RenderBudgetWindow(DesignWindow(seed: gesture.seed))
                defer { w.close() }
                let step = try await Self.dragSamples(gesture, in: w)
                // The press and the release reach the window; the 120 samples between them don't.
                #expect((step.bodies ?? 0) >= 1, "the \(gesture) never reached the window: \(step)")
                expectBodies(step, atMost: 3, target: 3)
            }
            #endif
        }

        @Test(.timeLimit(.minutes(3))) func withoutTheBoxTheEditorRunsPerSample() async throws {
            #if DEBUG
            for gesture in Gesture.allCases {
                let w = RenderBudgetWindow(DesignEditorWithoutBox(model: gesture.seed))
                defer { w.close() }
                let step = try await Self.dragSamples(gesture, in: w)
                // About 120: one run per sample. Over 60 leaves room for a coalesced event.
                #expect((step.bodies ?? 0) > 60, "without the box the \(gesture) ran the editor too few times: \(step)")
            }
            #endif
        }

        /// Drags `gesture` across the canvas of the window `w` hosts in 120 samples at 120 Hz, then
        /// releases it, and reports DesignEditor's body runs over the whole gesture.
        static func dragSamples<V: View>(
            _ gesture: Gesture, in w: RenderBudgetWindow<V>, samples: Int = 120
        ) async throws -> RenderStep {
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas"), "no canvas")
            let start = w.point(gesture.from, on: page, in: board)
            let end = w.point(
                CGPoint(x: gesture.from.x + gesture.by.dx, y: gesture.from.y + gesture.by.dy), on: page, in: board)
            return try await w.measure("design \(gesture.rawValue), \(samples) samples", bodies: editorBodies) {
                try await w.drag(from: start, by: CGVector(dx: end.x - start.x, dy: end.y - start.y), samples: samples)
            }
        }

        /// DesignEditor's body runs so far; nil in release, which has no counter.
        static func editorBodies() -> Int? {
            #if DEBUG
            return DesignEditor.bodyRuns
            #else
            return nil
            #endif
        }
    }
}

/// DesignEditor without the live drag box: every sample is written straight to the workspace, as
/// the window did before D0-8a. The control the bound is checked against.
private struct DesignEditorWithoutBox: View {
    @State private var model: DesignWorkspace
    @State private var zoom = 1.0

    init(model: DesignWorkspace) { _model = State(initialValue: model) }

    var body: some View {
        DesignEditor(model: model, zoom: zoom, onViewport: fit, perform: perform)
    }

    private func perform(_ intent: DesignIntent) {
        switch intent {
        case .drag(let from, let to, let modifiers):
            model.drag(from: DesignPoint(from), to: DesignPoint(to), modifiers: modifiers)
        case .endDrag: model.endDrag()
        default: break
        }
    }

    /// Fits the page to the canvas, as the window does on open.
    private func fit(_ viewport: CGSize) {
        guard let page = model.selectedPage, viewport != .zero else { return }
        let layout = EditorDetailLayout(viewport: viewport, toolCount: DesignTool.allCases.count)
        let scale = layout.fitScale(artboard: CGSize(width: page.frameWidth, height: page.frameHeight))
        zoom = scale > 0 ? scale : 1
        model.setHandleTolerance(Double(SuiteSpacing.s) / zoom)
    }
}
#endif
