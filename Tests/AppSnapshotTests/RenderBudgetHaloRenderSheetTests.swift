// RenderBudgetHaloRenderSheetTests.swift: the render sheet's codec budget
// (export-pack HX-5, Quality row "render: switching codec in the sheet") on
// the real window, through the harness (RenderBudgetHarness.swift). With
// File > Render… open on a movie (the Model's `beginRender`), switching the
// codec, as the Codec row's picker sends it through `setRenderSettings`,
// runs the window at most twice per switch, and so does ticking Transparent
// background on the codec that keeps alpha. Both reach the hosted window's
// model through its debug `renderDrive` hook (HaloWindow+Render.swift). The
// switch writes the settings directly: until HX-4 the picker refuses ProRes
// 4444 (`HaloRenderSettings.choosing(codec:)`), but the sheet's redraw is
// the same. Nested in BodyCountSuites, as every suite that reads a body
// counter is. macOS only.
#if canImport(AppKit)
import HaloModel
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloRenderSheetTests {
        /// render: one codec switch ≤ 2 window bodies (gate), target 1.
        static let switchBodies = 2

        @Test(.timeLimit(.minutes(3))) func codecSwitchInTwoBodies() async throws {
            #if DEBUG
            HaloWindow.renderDrive = nil
            let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let w = RenderBudgetWindow(HaloWindow(model: project))
            defer { w.close() }
            try await w.settle()
            let drive = try #require(HaloWindow.renderDrive, "the window never installed its render hook")
            let movie = HaloRenderSettings(format: .movie)
            drive { _ = $0.beginRender(movie) }
            try await w.settle()

            let prores = HaloRenderSettings(format: .movie, codec: .prores4444)
            let switched = try await w.measure("halo render sheet, H.264 to ProRes 4444", bodies: HaloWindowPlaybackTests.windowBodies) {
                w.timed { drive { $0.setRenderSettings(prores) } }
            }
            expectBodies(switched, atMost: Self.switchBodies, target: 1)

            let alpha = HaloRenderSettings(format: .movie, codec: .prores4444, alpha: true)
            let ticked = try await w.measure("halo render sheet, Transparent background on", bodies: HaloWindowPlaybackTests.windowBodies) {
                w.timed { drive { $0.setRenderSettings(alpha) } }
            }
            expectBodies(ticked, atMost: Self.switchBodies, target: 1)

            drive { $0.dismissRender() }
            try await w.settle()
            #endif
        }
    }
}
#endif
