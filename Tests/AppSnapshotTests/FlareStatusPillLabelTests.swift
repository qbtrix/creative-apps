// FlareStatusPillLabelTests.swift: the real Flare window's aspect and fps
// pills under the stage carry their text as their accessibility label, which
// is what journeys and VoiceOver read: XCUITest drops a plain Text's own
// label on macOS (#1452), so the 23.976 journey read an empty fps pill
// (#4687). Hosted through the render budget harness, so it nests in
// BodyCountSuites with the other real-window suites. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct FlareStatusPillLabelTests {
        @Test(.timeLimit(.minutes(2))) func aspectAndFPSPillsReadTheirText() async throws {
            var model = FlareWorkspace(services: .built)
            model.newSampleAnimation()
            let pills = model.statusPills(measuredFPS: nil)
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            try await w.settle(500)
            #expect(w.label("flare.status.fps") == pills.fps)
            #expect(w.label("flare.status.aspect") == pills.aspect)
        }
    }
}
#endif
