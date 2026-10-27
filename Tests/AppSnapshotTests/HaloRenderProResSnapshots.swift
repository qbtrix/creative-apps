// HaloRenderProResSnapshots.swift: the render sheet's Codec row and
// Transparent background checkbox (export-pack HX-2, HX-5's snapshot first)
// on `keyed` with the fakes. A ProRes 4444 movie with alpha on, seeded through
// `beginRender`: the checkbox enabled and checked. An H.264 movie: the checkbox off and disabled, its
// help ExportRules' sentence. The control inventory stands in for the
// accessibility tree. halo-render-prores-light/-dark.png and
// halo-render-h264-alpha-off.png. macOS only.
import AppKit
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

@MainActor
@Suite struct HaloRenderProResSnapshots {
    private let folder = URL(fileURLWithPath: "/nonexistent/Renders", isDirectory: true)

    private func editing(_ settings: HaloRenderSettings) throws -> HaloRenderExportAdapter {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let began = project.beginRender(settings)
        #expect(began && project.renderRun == .editing(settings))
        return HaloRenderExportAdapter(model: project, destination: folder, output: nil) { _ in }
    }

    private func controls(_ sheet: HaloRenderExportAdapter) throws -> [String: ControlEntry] {
        let store = SuiteControlStore()
        _ = try #require(render(sheet.environment(\.suiteControlStore, store), scheme: .light))
        return Dictionary(store.inventory.document().controls.map { ($0.id, $0) }) { a, _ in a }
    }

    @Test func sheet() throws {
        let prores = try editing(HaloRenderSettings(format: .movie, codec: .prores4444, alpha: true))
        let shown = try controls(prores)
        #expect(shown["halo.render.codec"]?.enabled == true)
        #expect(shown["halo.render.alpha"]?.enabled == true)
        #expect(HaloRenderMovieRows.codecHelp(busy: nil) == nil)
        try snapshot(prores, name: "halo-render-prores-light", scheme: .light)
        try snapshot(prores, name: "halo-render-prores-dark", scheme: .dark)

        let h264 = HaloRenderSettings(format: .movie)
        let off = try editing(h264)
        let found = try controls(off)
        #expect(found["halo.render.codec"]?.enabled == true)
        #expect(found["halo.render.alpha"]?.enabled == false)
        #expect(found["halo.render.alpha"]?.reason == "H.264 can't keep transparency. Choose ProRes 4444.")
        #expect(HaloRenderMovieRows.alphaHelp(HaloRenderSettings(format: .pngSequence), busy: nil) == nil)
        try snapshot(off, name: "halo-render-h264-alpha-off", scheme: .light)
    }
}
