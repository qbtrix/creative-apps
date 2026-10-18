// DesignArrangeDragTests.swift: copy-group C-4's bound on an Option-drag. On `cards`, a 120-sample
// Option-drag of A runs DesignEditor's body 3 times or fewer and ends with exactly one "Duplicate"
// step: the samples go to the live drag box, as every canvas drag does, and its mouse-up replays
// the last one as one step. The canvas sends the modifier keys held right now
// (`NSEvent.modifierFlags`, the device state), which an event a test sends can't set, so the editor
// is hosted with the window's live-drag routing and Option held for it. The drag is design-window
// D0-8b's `dragSamples` (DesignWindowDragTests): its `move` presses at (20, 20) and goes by
// (160, 90), so A starts selected around that point. DesignEditor.bodyRuns is a process-global debug
// counter, so the suite nests in BodyCountSuites. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignArrangeDragTests {
        typealias Drags = BodyCountSuites.DesignWindowDragTests

        /// `cards` with A (node-2) selected and moved to (-180, -180, 400 × 400): the `move` press at
        /// (20, 20) is inside it, 200 points from every handle, past the fit zoom's handle reach.
        static func seed() throws -> DesignWorkspace {
            var workspace = DesignFixtures.cards
            try workspace.setNodeFrame("node-2", x: -180, y: -180, width: 400, height: 400)
            workspace.selectItem("node-2")
            return workspace
        }

        @Test(.timeLimit(.minutes(2))) func anOptionDragRunsTheEditorAtMostThreeTimes() async throws {
            #if DEBUG
            let seed = try Self.seed()
            let host = OptionDragHost(model: seed)
            let w = RenderBudgetWindow(host)
            defer { w.close() }
            let step = try await Drags.dragSamples(.move, in: w)
            #expect((step.bodies ?? 0) >= 1, "the Option-drag never reached the editor: \(step)")
            expectBodies(step, atMost: 3, target: 3)

            var after = try #require(host.recorder.workspace, "the drag never reached the editor")
            let copy = try #require(after.selectedNode)
            #expect(copy.id != "node-2" && copy.name == "A")
            #expect(copy.frame.x > -180 && copy.frame.y > -180)
            let a = after.selectedPage?.nodes.first?.children.first { $0.id == "node-2" }
            #expect(a?.frame == DesignRect(x: -180, y: -180, width: 400, height: 400))
            #expect(after.undoActionName == "Undo Duplicate")
            // Exactly one step: one Undo puts back the document as it was before the press.
            after.undo()
            #expect(after.pages == seed.pages)
            #expect(after.undoActionName == seed.undoActionName)
            #expect(host.live.workspace == nil)
            #endif
        }
    }
}

/// The last workspace the host's editor was handed, for the test to read after the drag.
@MainActor private final class OptionDragRecorder {
    var workspace: DesignWorkspace?
}

/// DesignEditor with the window's live drag box and drag routing, Option held for every canvas drag.
private struct OptionDragHost: View {
    @State private var model: DesignWorkspace
    @State private var zoom = 1.0
    let live = DesignLiveDrag()
    let recorder = OptionDragRecorder()

    init(model: DesignWorkspace) { _model = State(initialValue: model) }

    var body: some View {
        DesignEditor(model: model, zoom: zoom, onViewport: fit, perform: perform)
            .environment(\.designLiveDrag, live)
    }

    private func perform(_ intent: DesignIntent) {
        defer { recorder.workspace = model }
        switch intent {
        case .drag(let from, let to, let modifiers):
            let start = DesignPoint(from)
            if live.workspace == nil {
                model.drag(from: start, to: start, modifiers: modifiers.union(.option))
                live.begin(from: model)
            }
            live.sample(from: start, to: DesignPoint(to), modifiers: modifiers.union(.option))
        case .endDrag:
            if live.workspace == nil { model.endDrag() } else { live.end(into: &model) }
        default: break
        }
    }

    /// Fits the page to the canvas, as the window does on open, so `dragSamples` finds its points.
    private func fit(_ viewport: CGSize) {
        guard let page = model.selectedPage, viewport != .zero else { return }
        let layout = EditorDetailLayout(viewport: viewport, toolCount: DesignTool.allCases.count)
        let scale = layout.fitScale(artboard: CGSize(width: page.frameWidth, height: page.frameHeight))
        zoom = scale > 0 ? scale : 1
        model.setHandleTolerance(Double(SuiteSpacing.s) / zoom)
    }
}
#endif
