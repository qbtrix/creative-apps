// RenderBudgetDesignExportTimingTests.swift: the export sheet's time budgets at real size
// (design-export, docs/blueprints/design/features/design-export.md: the "render: the sheet"
// and "render: the live run" rows, QD-S12), gated, on the 2,000-layer `crowd` page through the
// harness (RenderBudgetHarness.swift). `sheetTiming`: File > Export… and 9 format, scale and
// scope picks, each step p95 ≤ 16 ms (the 40-frame plan is rebuilt on every pick).
// `firstProgressTiming`: on the live services, Export of the 40 frames as PNGs into a temp
// folder shows its progress (or its finished line) within 100 ms of the press, then writes all
// 40. Both read the clock, so both are on the perf list (Tests/perf-suites.txt): the gate skips
// them and perf-nightly runs them. The sheet helpers are RenderBudgetDesignExportTests'.
// Nested in BodyCountSuites so no other window's bodies run beside them. macOS, DEBUG hooks.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignExportTimingTests {
        typealias Sheet = RenderBudgetDesignExportTests

        @Test(.timeLimit(.minutes(2)))
        func sheetTiming() async throws {
            var model = DesignFixtures.crowd
            model.useServices(.fake)
            let w = RenderBudgetWindow(DesignWindow(seed: model))
            defer { w.close() }
            try await w.settle(500)
            let chips = [
                "design.export.format.svg", "design.export.format.pdf", "design.export.format.png",
                "design.export.scale.2x", "design.export.scale.3x", "design.export.scale.1x",
                "design.export.scope.page", "design.export.scope.selection", "design.export.scope.frame",
            ]
            var sheet: NSWindow?
            var missing: [String] = []
            let walk = try await w.measure("design export sheet on crowd: open, 9 picks", bodies: { nil }) {
                try await w.ticks(1) { _ in
                    #if DEBUG
                    DesignWindow.openExport?()
                    #endif
                }
                sheet = await Sheet.sheet(of: w.window)
                guard let sheet else { return }
                try await w.ticks(chips.count) { i in
                    if let chip = chips.dropFirst(i - 1).first, !Sheet.press(chip, in: sheet) { missing.append(chip) }
                }
            }
            #expect(sheet != nil, "no export sheet")
            #expect(missing.isEmpty, "nothing to press for \(missing)")
            #expect(walk.p95 <= 16, "\(walk) (budget p95 16 ms)")
            if let sheet { _ = Sheet.press("design.export.cancel", in: sheet) }
        }

        @Test(.timeLimit(.minutes(2)))
        func firstProgressTiming() async throws {
            let folder = try Sheet.folder("crowd-progress")
            defer {
                try? FileManager.default.removeItem(at: folder)
                #if DEBUG
                DesignExportArea.testFolder = nil
                #endif
            }
            let (w, opened) = try await Sheet.openSheet(DesignFixtures.crowd)
            defer { w.close() }
            let sheet = try #require(opened, "no export sheet")
            try await w.settle(300)
            let shown = { Sheet.texts(in: sheet).contains { $0.hasPrefix("Exporting") || $0.contains("Exported") } }
            let clock = ContinuousClock()
            let pressed = clock.now
            #expect(Sheet.press("design.export.start", in: sheet), "no Export button")
            while !shown(), clock.now - pressed < .seconds(5) { try await Task.sleep(for: .milliseconds(1)) }
            let first = Double((clock.now - pressed) / .microseconds(1)) / 1000
            print("RENDER-BUDGET design export first progress on crowd (40 PNGs): \(String(format: "%.1f", first)) ms (budget 100 ms)")
            for _ in 0..<1500 where !Sheet.texts(in: sheet).contains(where: { $0.contains("Exported 40 files") }) {
                try await Task.sleep(for: .milliseconds(20))
            }
            let written = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            #expect(written.count == 40, "the folder holds \(written.count) files, not 40")
            #expect(first <= 100, "first progress \(first) ms after Export (budget 100 ms)")
            _ = Sheet.press("design.export.dismiss", in: sheet)
        }
    }
}
#endif
