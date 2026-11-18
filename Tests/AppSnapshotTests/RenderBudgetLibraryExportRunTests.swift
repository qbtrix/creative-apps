// RenderBudgetLibraryExportRunTests.swift: P8's progress row (QB-L9, quality
// gate #6205) on the real window, through the harness (RenderBudgetHarness.swift).
// On the `samples` fixture, once the window body is still, it selects ten photos,
// opens the export sheet on the window's own catalog (LibraryShell's read and
// take: the hosted window has no menu bar) into a fresh folder, and presses
// Export (`library.export.export`) in the attached sheet. It runs to the summary,
// then reads the app's own `export`, `progress` and `summary` marks from the
// window's `suite.perf` element (the window wrapped in `-SuitePerfProbe`), the
// marks P8 gates, and prints them. Fails when the run takes more than two window
// bodies, the catalog's start and its summary: the ten progress steps land in the
// export area's live run, which only the sheet reads (12 bodies, the running row
// 100-150 ms after Export in debug, when each step wrote the catalog). Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryExportRunTests {
        @Test(.timeLimit(.minutes(3))) func exportRunBodies() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"])
                .suiteProbes(arguments: ["Library", SuiteFrameProbe.launchFlag]))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return LibraryWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies, turns: 8)
            let folder = FileManager.default.temporaryDirectory.appending(path: "LibraryExportRun-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            var catalog = try #require(LibraryShell.read?(), "the window never shared its catalog")
            catalog.select(Set(catalog.order.prefix(10)))
            let began = catalog.beginExport(folder: folder.path)
            #expect(began, "the export sheet didn't open: \(catalog.exportHelp ?? "")")
            LibraryShell.take?(LibraryHeadless(catalog: catalog))
            let sheet = try #require(await RenderBudgetLibraryBackupTests.sheet(of: w.window), "no export sheet opened")
            try await w.settle(untilStable: bodies, turns: 8)
            let finished = { LibraryShell.read.flatMap { $0().exportFinished } }
            var pressed = false
            let run = try await w.measure("library export run, 10 samples", bodies: bodies) {
                try await w.ticks(1) { _ in
                    let export = RenderBudgetHistoryPanelTests.node("library.export.export", in: sheet)
                    pressed = export?.accessibilityPerformPress?() ?? false
                }
                for _ in 0..<600 where finished() == nil { try await w.settle(100) }
                try await w.settle(untilStable: bodies, turns: 8)
            }
            #expect(pressed, "no Export button (library.export.export) to press")
            #expect(finished()?.written.count == 10, "the run didn't write ten files: \(String(describing: finished()))")
            let marks = try Self.marks(w)
            let at = { (name: String) in marks.last { $0.name == name }?.time }
            let export = try #require(at("export"), "no export mark"), progress = try #require(at("progress"), "no progress mark")
            let summary = try #require(at("summary"), "no summary mark")
            print("LIBRARY-EXPORT-RUN progress \((progress - export) * 1000) ms, summary \((summary - export) * 1000) ms after export")
            // The catalog's start and its summary; the ten steps rerun the sheet only (12 before).
            expectBodies(run, atMost: 2, target: 2)
        }

        /// The `library.export` marks the window's `suite.perf` element carries.
        static func marks(_ w: RenderBudgetWindow<some View>) throws -> [ProbeMark] {
            let json = try #require(w.label(SuitePerfElement.identifier), "no suite.perf element")
            let document = try JSONDecoder().decode(ProbeDocument.self, from: Data(json.utf8))
            return document.marks.filter { $0.series == "library.export" }
        }
    }
}
#endif
