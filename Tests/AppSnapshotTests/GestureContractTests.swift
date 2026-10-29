// GestureContractTests.swift: the behaviour half of the canonical guard (docs/factory/lead.md, rule 20).
// `scripts/check-dup-logic` matches file and type names, so two behaviours for one gesture pass it (lesson 358:
// Photo's Free Transform drag rode the compositor's live layer while the Move tool's drag rewrote layer offsets
// on every sample). Here every tool of every app, through its PaletteTool `gesture` class (SuiteUI's
// ToolGesture), runs the same drag on its app's real window (RenderBudgetHarness.swift) and owes its class's
// contract:
//   movesContent  no pixel work past `pixelNoise` and at most 1 root body while the pointer is down (the move rides a live copy)
//   selects       no pixel work past `pixelNoise` while the pointer is down
//   every class   root bodies while the pointer is down within `bodyBound`, set at today's best path
// A movesContent or selects row presses at the centre of an existing layer or object, read from the app's
// model, and must change something at the release (the moved thing by the drag's delta, or the selection);
// one that changes nothing fails "drag hit nothing", which no exclusion covers. Pixel work is Photo's PhotoRenderCount (regions, layer composites, resamples); the other apps have no pixel
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
        static let exclusions: [String: (reason: String, issue: Int)] = [
            "photo.move": ("rewrites layer offsets every sample: 63 bodies, 2019 renders down", 6019),
            "photo.marquee": ("re-runs the editor body and re-renders every sample", 6020),
            "photo.ellipse": ("re-runs the editor body and re-renders every sample", 6020),
            "photo.lasso": ("re-runs the editor body and re-renders every sample", 6020),
            "photo.polygon": ("re-runs the editor body and re-renders every sample", 6020),
            "photo.wand": ("re-runs the editor body and re-renders every sample", 6020),
            "photo.crop": ("re-runs the editor body and re-renders every sample", 6020),
            "design.move": ("2 root bodies with the pointer down", 6021),
            "library.*": ("no canvas tool enum, so no adapter", 6022),
        ]

        /// Pixel renders a drag that changes nothing costs on Photo's window (eyedropper 101, pen 85 on
        /// 2026-10-29): the canvas's own region renders, which PhotoRenderCount counts with the tool's.
        // ponytail: a noise floor, not 0; gate 0 once the counter splits the tool's work from the canvas's.
        static let pixelNoise = 150

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
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            let size = CGSize(width: 4000, height: 3000)  // the large fixture: every layer fills it
            let zoom = board.width / size.width
            let layer = try #require(model.selectedLayer)
            let target = Self.aims(tool.gesture) ? w.point(CGPoint(x: 2000, y: 1500), on: size, in: board) : nil
            try await Self.run(.photo, tool.rawValue, tool.gesture, w, at: target, bodies: PhotoWindowStrokeTests.editorBodies,
                pixels: pixels, effect: {
                guard let after = edited.workspace else { return "no workspace after the release" }
                if tool.gesture == .selects { return after == model ? "the selection didn't change" : nil }
                let moved = after.layers.first { $0.id == layer.id }
                let got = CGVector(dx: Double((moved?.offsetX ?? 0) - layer.offsetX), dy: Double((moved?.offsetY ?? 0) - layer.offsetY))
                return Self.near(got, Self.delta(zoom), "layer \(layer.name) offset")
            })
            try await RenderBudgetPhotoLiveTransformTests.idle(w)
        }

        @Test(.timeLimit(.minutes(5)), arguments: DesignTool.allCases) func design(_ tool: DesignTool) async throws {
            var seed = DesignShapeSeed.star
            seed.selectTool(tool)
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()).allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(800)
            try await w.settle(untilStable: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
            let page = try #require(seed.selectedPage), frame = try #require(seed.selectedNode?.frame)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            let size = CGSize(width: page.frameWidth, height: page.frameHeight)
            let target = Self.aims(tool.gesture)
                ? w.point(CGPoint(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2), on: size, in: board) : nil
            let corner = await w.element("suite.handles.bottomRight")
            try await Self.run(.design, tool.rawValue, tool.gesture, w, at: target, bodies: { DesignWindow.bodyRuns + DesignEditor.bodyRuns }, effect: {
                // The selected node's handle rides it, in window points.
                guard let corner, let after = await w.element("suite.handles.bottomRight") else { return "no handles on the star" }
                return Self.near(CGVector(dx: after.midX - corner.midX, dy: corner.midY - after.midY), Self.delta(1), "the star's corner")
            })
        }

        @Test(.timeLimit(.minutes(5)), arguments: FlareTool.allCases) func flare(_ tool: FlareTool) async throws {
            var model = FlareWorkspace(services: .built)
            model.newSampleAnimation()
            model.selectTool(tool)
            if let first = model.selectedScene?.layers.first { model.selectLayer(first.id) }
            let box = model.selectionBounds
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            try await w.settle(500)
            try await w.settle(untilStable: { FlareWindow.bodyRuns })
            let scene = try #require(model.selectedScene)
            let board = await w.element("suite.canvas.artboard")
            let size = CGSize(width: scene.width, height: scene.height)
            var target: CGPoint?
            if Self.aims(tool.gesture) {
                let box = try #require(box, "the sample's first layer has no bounds")
                let board = try #require(board, "no artboard")
                target = w.point(CGPoint(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2), on: size, in: board)
            }
            try await Self.run(.flare, tool.rawValue, tool.gesture, w, at: target, bodies: { FlareWindow.bodyRuns }, effect: {
                guard let box, let board, let after = FlareWindow.shownModel?.selectionBounds else { return "nothing selected after the release" }
                return Self.near(CGVector(dx: after.minX - box.minX, dy: after.minY - box.minY), Self.delta(board.width / size.width), "the layer's box")
            })
        }

        @Test(.timeLimit(.minutes(5)), arguments: HaloTool.allCases) func halo(_ tool: HaloTool) async throws {
            let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let shapes = HaloShapeDrawing(tool: ShapeSpec(kind: .star, points: 6, innerRatio: 0.5))
            shapes.isOn = tool == .shape
            let w = RenderBudgetWindow(HaloWindow(model: project, shapes: shapes).environment(\.haloViewerTakesActivationClicks, true))
            defer { w.close() }
            try await w.settle(500)
            try await w.settle(untilStable: { HaloWindow.bodyRuns })
            let canvas = try #require(await w.element("halo.viewer.canvas"), "no halo.viewer.canvas")
            // Composition (960, 980): the middle of Floor's band, under nothing else at frame 0 (HaloWindowLiveDragTests).
            let floor = "comp-1-layer-1"
            let start = CGPoint(x: canvas.midX, y: canvas.minY + canvas.height * (100.0 / 1080.0))
            try await Self.run(.halo, tool.rawValue, tool.gesture, w, at: Self.aims(tool.gesture) ? start : nil,
                bodies: { HaloWindow.bodyRuns }, effect: {
                guard let after = HaloWindow.shownProject else { return "no project after the release" }
                var expected = project
                let end = CGPoint(x: start.x + Double(2 * Self.samples), y: start.y - Double(Self.samples))
                let map = { (p: CGPoint) in
                    expected.compositionPoint(x: p.x - canvas.minX, y: canvas.maxY - p.y,
                        artboardWidth: canvas.width, artboardHeight: canvas.height)
                }
                guard let from = map(start), let to = map(end) else { return "the press is off the composition" }
                expected.beginViewerDrag(at: from)
                expected.moveViewerDrag(to: to)
                expected.endViewerDrag()
                guard let want = expected.viewerDrawList?.worldBox(of: floor), let got = after.viewerDrawList?.worldBox(of: floor),
                    let was = project.viewerDrawList?.worldBox(of: floor) else { return "no Floor in the draw list" }
                if got.x == was.x && got.y == was.y { return "Floor didn't move" }
                return abs(got.x - want.x) < 0.5 && abs(got.y - want.y) < 0.5 ? nil : "Floor at \(got.x),\(got.y), want \(want.x),\(want.y)"
            })
        }

        /// One press, `samples` drag samples and a release from the canvas's middle; checks `gesture`'s contract on
        /// what ran while the pointer was down and prints the tool's row.
        static func run<V: View>(
            _ app: GestureApp, _ tool: String, _ gesture: ToolGesture, _ w: RenderBudgetWindow<V>,
            at target: CGPoint? = nil, bodies: @escaping () -> Int?, pixels: (() -> Int)? = nil,
            effect: () async -> String? = { nil }
        ) async throws {
            var canvas = await w.element("suite.canvas.artboard")
            if canvas == nil { canvas = await w.element("halo.viewer.canvas") }
            if aims(gesture) { #expect(target != nil, "\(app.rawValue) \(tool): no layer to press on") }
            let start = target ?? canvas.map { CGPoint(x: $0.midX, y: $0.midY) } ?? CGPoint(x: 640, y: 410)
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
            try await w.settle(400)
            let missed = aims(gesture) ? await effect() : nil
            if let missed { Issue.record("\(app.rawValue) \(tool) (\(gesture)): drag hit nothing: \(missed)") }
            print("GESTURE-CONTRACT | \(app.rawValue) | \(tool) | \(gesture) | bodies down \(bodiesDown)"
                + " | hit \(aims(gesture) ? (missed == nil ? "yes" : "NO") : "-")" + " | pixel work down \(pixels == nil ? "n/a" : "\(pixelsDown)") | p95 \(step.p95) ms | \(step)")
            contract("\(app.rawValue).\(tool)") {
                #expect(bodiesDown <= bodyBound(gesture), "\(app.rawValue) \(tool) (\(gesture)): \(bodiesDown) root bodies with the pointer down")
                if pixels != nil, gesture == .movesContent || gesture == .selects {
                    #expect(pixelsDown <= pixelNoise, "\(app.rawValue) \(tool) (\(gesture)): \(pixelsDown) pixel renders with the pointer down")
                }
            }
        }

        /// Whether `gesture`'s row presses on a layer and must change something.
        static func aims(_ gesture: ToolGesture) -> Bool { gesture == .movesContent || gesture == .selects }

        /// The drag's delta in document units at `zoom` window points per unit, y down.
        static func delta(_ zoom: Double) -> CGVector { CGVector(dx: Double(2 * samples) / zoom, dy: Double(samples) / zoom) }

        /// nil when `got` is within 5% (and 3 units) of `want`, else what moved where.
        static func near(_ got: CGVector, _ want: CGVector, _ what: String) -> String? {
            let slack = { (v: Double) in max(3, abs(v) * 0.05) }
            if got.dx == 0 && got.dy == 0 { return "\(what) didn't move" }
            return abs(got.dx - want.dx) <= slack(want.dx) && abs(got.dy - want.dy) <= slack(want.dy)
                ? nil : "\(what) moved \(got), want \(want)"
        }

        /// Runs `body` as a known issue when `key` is excluded, so an exclusion fails once its tool passes.
        static func contract(_ key: String, _ body: () -> Void) {
            guard let excluded = exclusions[key] else { return body() }
            withKnownIssue("\(key): \(excluded.reason) (#\(excluded.issue))") { body() }
        }
    }
}
#endif
