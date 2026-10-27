// RenderBudgetLibraryExportPackTests.swift: the export sheet's Metadata row's
// render budget (export-pack LX-5; docs/blueprints/library/features/export-pack.md,
// Quality tests) on the real window, through the harness
// (RenderBudgetHarness.swift). On the `samples` fixture, once the window body is
// still, it selects the first photo and opens the sheet on the window's own
// catalog (LibraryShell's read and take: the hosted window has no menu bar),
// then presses the Metadata row's None chip (`library.export.metadata.none`).
// The pick is one setExportOptions on the catalog, so the window body runs at
// most twice (target 1). The sheet is its own window attached to the hosted
// one, so the chip is found from `attachedSheet`'s accessibility tree. Nested
// in BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SuiteKernel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryExportPackTests {
        @Test(.timeLimit(.minutes(2))) func metadataPickInTwoBodies() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"]))
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
            var catalog = try #require(LibraryShell.read?(), "the window never shared its catalog")
            catalog.select(Set(catalog.order.prefix(1)))
            #expect(catalog.beginExport(folder: NSTemporaryDirectory()), "the export sheet didn't open: \(catalog.exportHelp ?? "")")
            LibraryShell.take?(LibraryHeadless(catalog: catalog))
            let sheet = try #require(await RenderBudgetLibraryBackupTests.sheet(of: w.window), "no export sheet opened")
            try await w.settle(untilStable: bodies, turns: 8)
            let metadata = { LibraryShell.read.flatMap { LibraryExportSheet.options($0().exportState)?.metadata } }
            #expect(metadata() == .noLocation, "the sheet didn't open on All but location")
            var pressed = false
            let pick = try await w.measure("library export metadata pick, None", bodies: bodies) {
                try await w.ticks(1) { _ in
                    let chip = RenderBudgetHistoryPanelTests.node("library.export.metadata.none", in: sheet)
                    pressed = chip?.accessibilityPerformPress?() ?? false
                }
            }
            #expect(pressed, "no None chip (library.export.metadata.none) to press")
            #expect(metadata() == ExportMetadata.none, "the pick didn't reach the catalog: \(pick)")
            // One options edit: one window body. Target: 1.
            expectBodies(pick, atMost: 2, target: 1)
        }
    }
}
#endif
