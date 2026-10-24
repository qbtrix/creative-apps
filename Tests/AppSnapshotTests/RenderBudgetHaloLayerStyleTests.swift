// RenderBudgetHaloLayerStyleTests.swift (layer-styles HY-4, Quality row "render: glow scrub"): what scrubbing
// Glow Size in the inspector's LAYER STYLE group costs the real Halo window. On `-HaloSample keyed` (live
// services, paused) Floor gets an outer glow 10 px at 75%, then HostedHaloWindow (HaloWindowLiveDragTests.swift)
// drags `halo.inspector.row.glowSize` 120 px over 120 samples at 120 Hz. Budget: the window's body runs at most 3
// times, the drag lands as one "Change Glow Size" step, and the size moves. The viewer draws no style until HY-7
// (StyleRoute), so its share of the scrub waits on it; the packet's p95 (≤ 16 ms) belongs in Tests/perf-suites.txt,
// which only the supervisor edits. Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteImaging
import SwiftUI
import Testing

@testable import HaloApp

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
    }
}
#endif
