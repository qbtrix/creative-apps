// FlareTimelineIdentifierTests.swift: the real Flare window's timeline names,
// lanes and keys carry `flare.timeline.name.<id>`, `.lane.<id>` and
// `.key.<id>.<frame>`, so the journeys' identifier audit (#262) finds none of
// them unnamed (#2489, #2768). Hosted through the render budget harness, so it
// nests in BodyCountSuites with the other real-window suites. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct FlareTimelineIdentifierTests {
        @Test(.timeLimit(.minutes(2))) func namesLanesAndKeysHaveIdentifiers() async throws {
            var model = FlareWorkspace(services: .built)
            model.newSampleAnimation()
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            try await w.settle(500)
            let ids = w.identifiers()
            for part in ["name", "lane", "key"] {
                #expect(
                    ids.contains { $0.hasPrefix("flare.timeline.\(part).") },
                    "no flare.timeline.\(part).* in \(ids.filter { $0.hasPrefix("flare.timeline") })")
            }
        }
    }
}
#endif
