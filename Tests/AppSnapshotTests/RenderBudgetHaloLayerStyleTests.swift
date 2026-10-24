// RenderBudgetHaloLayerStyleTests.swift (layer-styles HY-4, Quality row "render: glow scrub"): what scrubbing
// Glow Size in the inspector's LAYER STYLE group costs the real Halo window. On `-HaloSample keyed` (live
// services, paused) Floor gets an outer glow 10 px at 75%, then HostedHaloWindow (HaloWindowLiveDragTests.swift)
// drags `halo.inspector.row.glowSize` 120 px over 120 samples at 120 Hz. Budget: the window's body runs at most 3
// times, the drag lands as one "Change Glow Size" step, and the size moves. HY-7: the viewer's GPU layer view
// uploads Floor once over a Glow Size scrub (glowScrubUploadsTheLayerOnce); its pixels wait on LS-9 (StyleRoute's
// draw). The packet's p95 (≤ 16 ms) belongs in Tests/perf-suites.txt, which only the supervisor edits. Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import Metal
import SuiteImaging
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloLayerStyleTests {
        /// Floor spans the artboard's bottom band.
        static let floor = "comp-1-layer-1"

        /// An outer glow 10 px at 75%.
        static let glow = LayerStyle(effects: [
            StyleEffect(kind: .outerGlow, isEnabled: true, blendMode: .screen, opacity: 0.75,
                        parameters: .glow(StyleGlow(color: .white, spread: 0, size: 10))),
        ], fillOpacity: 1)

        @Test(.timeLimit(.minutes(3))) func glowScrubInThreeBodies() async throws {
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            project.selectLayer(Self.floor)
            try project.setStyle(Self.glow, name: "Add Outer Glow", drag: nil)
            let size = try #require(project.propertyRows.first { $0.property == .glowSize }?.value, "no Glow Size row")
            let hosted = try await HostedHaloWindow(project)
            defer { hosted.close() }
            let row = try #require(hosted.frame(of: "halo.inspector.row.glowSize"), "no halo.inspector.row.glowSize")
            let start = CGPoint(x: row.midX, y: row.midY)

            let (runs, after) = try await hosted.drag(from: start, to: CGPoint(x: start.x + 120, y: start.y), every: 20) {}

            let moved = after.propertyRows.first { $0.property == .glowSize }?.value
            let report = "GLOW-SCRUB samples=120@120Hz | window bodies \(runs.map(String.init) ?? "n/a"), undo \(after.undoTitle ?? "nil"), Glow Size \(size) -> \(moved.map { "\($0)" } ?? "nil")"
            print(report)

            if let runs { #expect(runs <= 3, "the window ran per scrub sample: \(report)") }
            #expect(after.history.undo.count == project.history.undo.count + 1, "the scrub isn't one step: \(report)")
            #expect(after.undoTitle == "Undo Change Glow Size", "\(report)")
            #expect(moved != nil && moved != size, "the scrub didn't change Glow Size: \(report)")
        }

        /// HY-7: the viewer's GPU layer view on a Glow Size scrub. Floor's styled run goes through
        /// StyleLayerRoute into a Metal-path host as HaloStyledViewer sends it, Glow Size 10 to 40 over 31 steps:
        /// the layer uploads once and every step writes it (styled once LS-9 builds the draw, unstyled until).
        /// A move is new content and uploads again. Skipped without a GPU.
        @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil), .timeLimit(.minutes(1)))
        func glowScrubUploadsTheLayerOnce() async throws {
            let preference = FakeRenderingPreference(choice: .gpu)
            let route = StyleLayerRoute(preference: preference)
            // The backend compiles its pipelines in the background.
            for _ in 0..<300 where !route.isAvailable { try await Task.sleep(for: .milliseconds(100)) }
            try #require(route.isAvailable, "the GPU style route never came up")
            let host = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 400, height: 225))
            host.followRendering(preference)
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            project.selectLayer(Self.floor)
            try project.setStyle(Self.glow, name: "Add Outer Glow", drag: nil)
            let list = try #require(project.viewerDrawList, "no draw list")
            let floor = try #require(list.items.first { $0.layerID == Self.floor }, "Floor isn't drawn")
            #expect(list.styledRuns.contains(.styled(floor)), "Floor's glow doesn't reach the GPU view")

            let draw = { (item: HaloDrawItem, list: HaloDrawList, size: Double) in
                let style = LayerStyle(effects: [
                    StyleEffect(kind: .outerGlow, isEnabled: true, blendMode: .screen, opacity: 0.75,
                                parameters: .glow(StyleGlow(color: .white, spread: 0, size: size))),
                ], fillOpacity: 1)
                route.draw(item.layerID, content: AnyHashable(list.styleContent(item)), width: list.width,
                           height: list.height, style: style, pixels: { list.stylePixels(item) }, into: host)
            }
            for size in 10...40 { draw(floor, list, Double(size)) }
            let gpu = try #require(route.layer(Self.floor), "the route dropped Floor's layer")
            #expect(!route.failed, "a GPU write failed")
            #expect(gpu.uploads == 1, "a style-only step uploaded the layer: \(gpu.uploads) uploads")
            #expect(gpu.styled + gpu.unstyled == 31, "steps written: \(gpu.styled) styled, \(gpu.unstyled) unstyled")

            let moved = list.offsetting(Self.floor, by: HaloPoint(x: 4, y: 0))
            let shifted = try #require(moved.items.first { $0.layerID == Self.floor })
            draw(shifted, moved, 40)
            #expect(gpu.uploads == 2, "a move didn't upload the new content")
        }
    }
}
#endif
