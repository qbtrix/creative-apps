// RenderBudgetFlareExportPackTests.swift: the export sheet's progress budget for MP4 and GIF (export-pack FV-5;
// docs/blueprints/flare/features/export-pack.md, Quality tests) on the real window through the harness
// (RenderBudgetHarness.swift). On `bounce` (48 frames) with the fakes and `-FlareExportTo` on a temp folder, it
// passes the window the same launch as its model, so the run writes to the temp folder and no folder panel opens. It
// presses the toolbar's Export…, picks the GIF chip and presses Export: the run counts the plan's 48 frames, so the
// bar moves once per frame. The fake exporter pauses 100 ms after each frame so every tick renders on its own (at
// 20 or 40 ms SwiftUI folds 2 or 3 ticks into one body, and a doubled body per tick would hide under the gate); the
// run takes about 5 s, and the wait for it ends on a 60 s deadline. `progressInOneBodyPerTick` gates the window
// bodies over the run at one per frame plus the start and the finish. The sheet is found from `attachedSheet`'s
// accessibility tree and Export… is a toolbar item, as in RenderBudgetFlareExportTests. Nested in BodyCountSuites,
// as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
@testable import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlareExportPackTests {
        private typealias Sheet = RenderBudgetFlareExportTests

        @Test(.timeLimit(.minutes(2)))
        func progressInOneBodyPerTick() async throws {
            let folder = FileManager.default.temporaryDirectory.appending(path: "flare-export-pack-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let launch = FlareLaunch(arguments: ["-FlareFixture", "bounce", "-FlareExportTo", folder.path])
            var model = FlareWorkspace(launch: launch)
            model.services.export = FakeExport(frameDelay: .milliseconds(100))
            let w = RenderBudgetWindow(FlareWindow(model: model, launch: launch))
            defer { w.close() }
            w.window.styleMask.insert(.titled)
            w.window.contentView = nil
            w.host.sceneBridgingOptions = [.toolbars]
            w.window.toolbar = NSToolbar()
            w.window.contentView = w.host
            let bodies = { () -> Int? in
                #if DEBUG
                return FlareWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            _ = Sheet.node("flare.export.showSheet", in: w.window)?.accessibilityPerformPress?()
            let sheet = try #require(await Sheet.sheet(of: w.window), "Export… opened no sheet")
            #expect(Sheet.press("flare.export.format.gif", in: sheet), "no GIF chip (flare.export.format.gif)")
            try await w.settle(untilStable: bodies)
            let finished = { () -> Bool in
                #if DEBUG
                if case .finished = FlareWindow.shownModel?.exportState { return true }
                #endif
                return false
            }
            let run = try await w.measure("flare GIF export, 48 frames", bodies: bodies) {
                #expect(Sheet.press("flare.export.start", in: sheet), "no Export (flare.export.start)")
                let deadline = ContinuousClock.now + .seconds(60)
                while !finished(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
                try await w.settle(untilStable: bodies)
            }
            #expect(finished(), "the GIF run never finished: \(run)")
            // One body per frame of progress, plus the start and the finish. Target: the same.
            expectBodies(run, atMost: 50, target: 50)
            _ = Sheet.press("flare.export.dismiss", in: sheet)
        }
    }
}
#endif
