// PhotoWindowLiveEditTests.swift: what a live edit costs the real Photo window's main thread on an 8K
// document (PhotoRenderBudgetTests' three layers) on the GPU route, at fit and at 100 % zoom: 30 Levels gamma
// steps, 30 Hue/Saturation steps and 30 Move tool samples on the top layer, each sent the way the window sends
// it, at 120 Hz. Main stall is how late a main-queue heartbeat was (PhotoZoomBudgetTests.stalls): the longest
// single stall and the total. A step that makes Core Animation draw an artboard-sized offscreen surface on the
// main thread shows here as a stall per step. Report-only (Tests/perf-suites.txt): PHOTO-LIVE-EDIT-8K lines in
// .build/snapshots/photo-live-edit.txt. macOS only.
import AppKit
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite(.serialized) struct PhotoWindowLiveEditTests {
        @Test(.timeLimit(.minutes(20))) func eightKLevelsHueSatAndMoveOnTheGPU() async throws {
            var lines: [String] = []
            let env = ProcessInfo.processInfo.environment
            let zooms: [Double?] = env["PHOTO_LIVE_AT"].map { [Double($0)] } ?? [nil, 1]
            for zoom in zooms { lines += try await Self.measure(zoom: zoom) }
            let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n").write(
                to: folder.appendingPathComponent("photo-live-edit.txt"), atomically: true, encoding: .utf8)
        }

        /// The window at `zoom` (nil: fit) on the GPU: each edit's main stall.
        static func measure(zoom: Double?) async throws -> [String] {
            let rendering = PhotoRendering(preference: FakeRenderingPreference(choice: .gpu))
            let model = try PhotoRenderBudgetTests.document()
            let w = RenderBudgetWindow(PhotoWindow(model: model, zoom: zoom ?? 1).environment(\.photoRendering, rendering))
            defer { w.close() }
            if ProcessInfo.processInfo.environment["PHOTO_LIVE_ONSCREEN"] == "1" {
                // On screen, nearly transparent and click-through: an off-screen window may skip drawing.
                w.window.ignoresMouseEvents = true
                w.window.alphaValue = 0.02
                w.window.setFrameOrigin(NSPoint(x: 40, y: 40))
            }
            let canvas = try #require(await w.first(CanvasHostView.self))
            for _ in 0..<600 where !BodyCountSuites.PhotoZoomBudgetTests.shows(canvas) { try await Task.sleep(for: .milliseconds(50)) }
            try await w.settle(1000)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            if zoom == nil {
                send(.fit)
                try await w.settle(1000)
            }
            let label = zoom.map { "\(Int($0 * 100))%" } ?? "fit"
            let rounds = Int(ProcessInfo.processInfo.environment["PHOTO_LIVE_ROUNDS"] ?? "1") ?? 1
            var lines: [String] = []
            func report(_ kind: String, _ stall: (longest: Double, total: Double)) {
                let line = String(format: "PHOTO-LIVE-EDIT-8K %@ GPU %@ %@: main stall longest %.1f ms, total %.0f ms over 30 steps",
                                  kind, label, PhotoRenderBudgetTests.config, stall.longest, stall.total)
                print(line)
                lines.append(line)
            }
            for _ in 0..<rounds {
                report("levels", try await BodyCountSuites.PhotoZoomBudgetTests.stalls(w, 30) { i in
                    send(.adjust(.gamma(1 + Float(i) / 50)))
                })
                send(.endAdjust)
                report("hue-sat", try await BodyCountSuites.PhotoZoomBudgetTests.stalls(w, 30) { i in
                    send(.adjust(.saturation(Double(i) * 2)))
                })
                send(.endAdjust)
                send(.tool(.move))
                report("move", try await BodyCountSuites.PhotoZoomBudgetTests.stalls(w, 30) { i in
                    send(.drag(CGPoint(x: 2000, y: 2000), CGPoint(x: 2000 + Double(i * 3), y: 2000 + Double(i))))
                })
                send(.endDrag)
            }
            return lines
        }
    }
}
