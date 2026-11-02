// RenderBudgetConnectTests.swift (cli-bundle CB-5b): what Help > Connect an AI Assistant… costs a real app window
// (Tests/render-budgets.md). On Flare's titled harness window SuiteHelpPresenter begins the sheet, its own window,
// so the app window's body runs at most for the key change; Close ends it. Install Command-Line Tool… (CB-6) begins
// its question on the sheet within the same budget, and Cancel writes nothing. Every control carries its id. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SuiteModel
import SwiftUI
import Testing

@testable import FlareApp
@testable import SuiteShell
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetConnectTests {
        static let bundle = "/Applications/AfterGlow.app"

        @Test(.timeLimit(.minutes(2))) func openSheetInTwoBodies() async throws {
            let presenter = SuiteHelpPresenter()
            let w = try await Self.window()
            defer { w.close() }
            let open = try await w.measure("connect sheet appear", bodies: Self.bodies) {
                try await w.ticks(1) { _ in presenter.showConnect(bundle: Self.bundle, in: w.window) }
                try await w.settle(300)
            }
            #expect(w.window.attachedSheet != nil, "Connect an AI Assistant… began no sheet on the window")
            // Target: 0, the sheet's key change and its end are the window's only bodies.
            expectBodies(open, atMost: 2, target: 0)
            presenter.closeConnect()
            try await w.settle(300)
            #expect(w.window.attachedSheet == nil, "Close left the sheet on the window")
        }

        @Test(.timeLimit(.minutes(2))) func installAsksOnTheSheetInTwoBodies() async throws {
            let presenter = SuiteHelpPresenter()
            let home = FileManager.default.temporaryDirectory.appendingPathComponent("suite-home-\(UUID().uuidString)").path
            let w = try await Self.window()
            defer { w.close() }
            presenter.showConnect(bundle: Self.bundle, in: w.window)
            try await w.settle(300)
            let connect = try #require(presenter.connect, "Connect an AI Assistant… made no sheet")
            var install: Task<Void, Never>?
            let ask = try await w.measure("install prompt appear", bodies: Self.bodies) {
                try await w.ticks(1) { _ in
                    install = Task { @MainActor in
                        await InstallCommandLineTool.run(bundle: Self.bundle, on: connect, arguments: ["-SuiteHomeDir", home])
                    }
                }
                try await w.settle(300)
            }
            let prompt = try #require(connect.attachedSheet, "Install Command-Line Tool… asked nothing on the sheet")
            // Target: 0, the question is the connect sheet's own sheet.
            expectBodies(ask, atMost: 2, target: 0)
            connect.endSheet(prompt, returnCode: .alertSecondButtonReturn)
            await install?.value
            #expect(!FileManager.default.fileExists(atPath: home + "/.local"), "Cancel wrote into the home")
            presenter.closeConnect()
            try await w.settle(300)
        }

        @Test(.timeLimit(.minutes(2))) func everyControlCarriesItsId() async throws {
            let sheet = AssistantConnectSheet(
                panel: AssistantConnectPanel(bundle: Self.bundle), onCopy: { _ in }, onOpenAIAccess: {}, onClose: {})
            let w = RenderBudgetWindow(sheet, size: CGSize(width: 720, height: 560))
            defer { w.close() }
            try await w.settle(500)
            for control in AssistantConnectSheet.controls {
                let id = AssistantConnectSheet.identifier(control)
                #expect(await w.element(id) != nil, "the sheet has no \(id)")
            }
        }

        /// Flare's window on New Sample Animation with Ellipse chosen, in a titled harness window, settled.
        static func window() async throws -> RenderBudgetWindow<FlareWindow> {
            var model = FlareWorkspace(services: .built)
            model.newSampleAnimation()
            model.selectTool(.ellipse)
            let w = RenderBudgetWindow(FlareWindow(model: model))
            w.window.styleMask.insert(.titled)
            try await w.settle(500)
            return w
        }

        /// FlareWindow's body runs; nil in release, which has no counter.
        static func bodies() -> Int? {
            #if DEBUG
            return FlareWindow.bodyRuns
            #else
            return nil
            #endif
        }
    }
}
#endif
