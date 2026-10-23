// FlareSaveStatusPlacementTests.swift: where Flare's failed-save status sits in a real window. On `bounce` with
// an edit and a failed save, hosted at the harness's 1280 by 820, "Not saved" (`flare.saveStatus`) is in the
// stage pane's status bar (`flare.stagePane`), as Design's and Photo's sit in their status lines, and never over
// the inspector column (`suite.inspector`), whose rows scroll under a floating badge. Nested in BodyCountSuites
// because the hosted window bumps FlareWindow's body counter. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct FlareSaveStatusPlacementTests {
        @Test(.timeLimit(.minutes(1)))
        func notSavedSitsInTheStageStatusBar() async throws {
            var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
            model.addLayer()
            model.saveFailed("You don't have permission to save the file in the folder.")
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            try await w.settle()
            let status = try #require(await w.element("flare.saveStatus"), "no Not saved (flare.saveStatus)")
            let stage = try #require(await w.element(FlareStage.identifier), "no stage pane")
            #expect(stage.contains(status), "Not saved \(status) isn't in the stage pane \(stage)")
            if let inspector = await w.element("suite.inspector") {
                #expect(!inspector.intersects(status), "Not saved \(status) covers the inspector \(inspector)")
            }
        }
    }
}
#endif
