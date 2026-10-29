// GestureContractTests.swift: the behaviour half of the canonical guard (docs/factory/lead.md, rule 20).
// `scripts/check-dup-logic` matches file and type names, so two behaviours for one gesture pass it (lesson 358:
// Photo's Free Transform drag rode the compositor's live layer while the Move tool's drag rewrote layer offsets
// on every sample). Here every tool of every app, through its PaletteTool `gesture` class (SuiteUI's
// ToolGesture), runs the same drag on its app's real window (RenderBudgetHarness.swift) and owes its class's
// contract:
//   movesContent  0 pixel work and at most 1 root body while the pointer is down (the move rides a live copy)
//   selects       0 pixel work while the pointer is down
//   every class   root bodies while the pointer is down within `bodyBound`, set at today's best path
// Pixel work is Photo's PhotoRenderCount (regions, layer composites, resamples); the other apps have no pixel
// counter yet, so they owe the body bound only. Step p95 is printed per tool (GESTURE-CONTRACT lines), not gated:
// a timing gate belongs in Tests/perf-suites.txt. A tool skips its contract only through `exclusions` (reason
// and issue each); a skipped tool runs under `withKnownIssue`, so an exclusion fails once its tool passes.
// Every app in GestureApp needs an adapter here, or `everyAppHasAnAdapter` fails. Nested in BodyCountSuites:
// it reads process-wide counters. macOS debug builds only (the counters are debug-only).
#if canImport(AppKit) && DEBUG
import AppKit
import DesignModel
import FlareModel
import HaloModel
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import FlareApp
@testable import HaloApp
@testable import PhotoApp

/// Every app with a canvas.
enum GestureApp: String, CaseIterable { case photo, design, flare, halo, library }

extension BodyCountSuites {
    @MainActor @Suite struct GestureContractTests {
        static let samples = 60

        /// Tools that skip their class's contract, keyed `<app>.<tool>`: why, and the issue that tracks the fix.
        static let exclusions: [String: (reason: String, issue: Int)] = [:]

        /// Apps the cross-app run covers; each iterates its own tool enum's `allCases`.
        static let adapters: [GestureApp: [(tool: String, gesture: ToolGesture)]] = [
            .photo: PhotoTool.allCases.map { ($0.rawValue, $0.gesture) },
            .design: DesignTool.allCases.map { ($0.rawValue, $0.gesture) },
            .flare: FlareTool.allCases.map { ($0.rawValue, $0.gesture) },
            .halo: HaloTool.allCases.map { ($0.rawValue, $0.gesture) },
        ]

        /// The most root bodies a class may run while the pointer is down.
        static func bodyBound(_ gesture: ToolGesture) -> Int {
            switch gesture {
            case .movesContent, .selects, .inspects, .none: 1
            case .paints, .editsPoints, .creates: 3
            }
        }

        @Test func everyAppHasAnAdapter() {
            for app in GestureApp.allCases where Self.adapters[app] == nil {
                Self.contract("\(app.rawValue).*") {
                    Issue.record("\(app.rawValue) has no gesture adapter: its canvas tools owe no contract")
                }
            }
        }

        @Test(.timeLimit(.minutes(10)), arguments: PhotoTool.allCases) func photo(_ tool: PhotoTool) async throws {
            var model = try PhotoWorkspace.fixture(.large)
            model.selectTool(tool)
            let w = RenderBudgetWindow(PhotoWindow(model: model).allowsWindowActivationEvents())
            defer { w.close() }
            _ = try #require(await w.first(PhotoWindowEditedView.self))
            try await w.settle(untilStable: PhotoWindowStrokeTests.editorBodies)
            let pixels = {
                PhotoRenderCount.regions.withLock { $0 } + PhotoRenderCount.layerComposites.withLock { $0 }
                    + PhotoRenderCount.resamples.withLock { $0 }
            }
            try await Self.run(.photo, tool.rawValue, tool.gesture, w, bodies: PhotoWindowStrokeTests.editorBodies, pixels: pixels)
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
        }

        @Test(.timeLimit(.minutes(5)), arguments: DesignTool.allCases) func design(_ tool: DesignTool) async throws {
            var seed = DesignShapeSeed.star
            seed.selectTool(tool)
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()).allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(800)
            try await w.settle(untilStable: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
            try await Self.run(.design, tool.rawValue, tool.gesture, w, bodies: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
        }

        @Test(.timeLimit(.minutes(5)), arguments: FlareTool.allCases) func flare(_ tool: FlareTool) async throws {
            var model = FlareWorkspace(services: .built)
            model.newSampleAnimation()
            model.selectTool(tool)
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            try await w.settle(500)
            try await w.settle(untilStable: { FlareWindow.bodyRuns })
            try await Self.run(.flare, tool.rawValue, tool.gesture, w, bodies: { FlareWindow.bodyRuns })
        }

        @Test(.timeLimit(.minutes(5)), arguments: HaloTool.allCases) func halo(_ tool: HaloTool) async throws {
            let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let shapes = HaloShapeDrawing(tool: ShapeSpec(kind: .star, points: 6, innerRatio: 0.5))
            shapes.isOn = tool == .shape
            let w = RenderBudgetWindow(HaloWindow(model: project, shapes: shapes).environment(\.haloViewerTakesActivationClicks, true))
            defer { w.close() }
            try await w.settle(500)
            try await w.settle(untilStable: { HaloWindow.bodyRuns })
            try await Self.run(.halo, tool.rawValue, tool.gesture, w, bodies: { HaloWindow.bodyRuns })
        }

        /// One press, `samples` drag samples and a release from the canvas's middle; checks `gesture`'s contract on
        /// what ran while the pointer was down and prints the tool's row.
        static func run<V: View>(
            _ app: GestureApp, _ tool: String, _ gesture: ToolGesture, _ w: RenderBudgetWindow<V>,
            bodies: @escaping () -> Int?, pixels: (() -> Int)? = nil
        ) async throws {
            var canvas = await w.element("suite.canvas.artboard")
            if canvas == nil { canvas = await w.element("halo.viewer.canvas") }
            let start = canvas.map { CGPoint(x: $0.midX, y: $0.midY) } ?? CGPoint(x: 640, y: 410)
            let point = { (i: Int) in CGPoint(x: start.x + Double(i) * 2, y: start.y - Double(i)) }
            let (bodies0, pixels0) = (bodies() ?? 0, pixels?() ?? 0)
            var (bodiesDown, pixelsDown) = (0, 0)
            let step = try await w.measure("gesture \(app.rawValue).\(tool)", bodies: bodies) {
                w.timed { w.send(.leftMouseDown, at: start) }
                try await w.ticks(samples) { w.send(.leftMouseDragged, at: point($0)) }
                try await w.settle(200)
                (bodiesDown, pixelsDown) = ((bodies() ?? 0) - bodies0, (pixels?() ?? 0) - pixels0)
                w.timed { w.send(.leftMouseUp, at: point(samples)) }
            }
            try await w.settle(200)
            print("GESTURE-CONTRACT | \(app.rawValue) | \(tool) | \(gesture) | bodies down \(bodiesDown)"
                + " | pixel work down \(pixels == nil ? "n/a" : "\(pixelsDown)") | p95 \(step.p95) ms | \(step)")
            contract("\(app.rawValue).\(tool)") {
                #expect(bodiesDown <= bodyBound(gesture), "\(app.rawValue) \(tool) (\(gesture)): \(bodiesDown) root bodies with the pointer down")
                if pixels != nil, gesture == .movesContent || gesture == .selects {
                    #expect(pixelsDown == 0, "\(app.rawValue) \(tool) (\(gesture)): \(pixelsDown) pixel renders with the pointer down")
                }
            }
        }

        /// Runs `body` as a known issue when `key` is excluded, so an exclusion fails once its tool passes.
        static func contract(_ key: String, _ body: () -> Void) {
            guard let excluded = exclusions[key] else { return body() }
            withKnownIssue("\(key): \(excluded.reason) (#\(excluded.issue))") { body() }
        }
    }
}
#endif
