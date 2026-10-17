// LiveExportTests.swift: MJ-FX2's adapter half (docs/blueprints/flare/features/flare-export.md, FX-6).
// `LiveExportAdapter` over `LiveStage` writes `bounce`'s PNG plan name for name with progress ending at 1, a cancel
// between frames throws `CancellationError` and hands back no result, text never reaches the exporters (they throw on
// it) yet is named in the warnings, a transparent SVG drops the background, and the SVG and Lottie bytes equal
// `FakeExport`'s on both stages, as do the warnings `ExportScan` gives.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import FlareModel
import Synchronization
import Testing

@Suite struct LiveExportTests {
    private let live = LiveExportAdapter(stage: LiveStage())
    private let scene = "scene-1"

    private func options(_ format: ExportFormat, _ frames: ClosedRange<Int> = 0...0, step: Int = 1,
                         transparent: Bool = false) -> ExportOptions {
        ExportOptions(format: format, sceneID: scene, frames: frames, step: step, transparentBackground: transparent)
    }

    private func export(_ adapter: any Exporting, _ document: Document, _ options: ExportOptions,
                        progress: @Sendable (Double) -> Void = { _ in }) async throws -> ExportResult {
        try await adapter.export(document, options: options, rasterizer: FakeRasterizer(), progress: progress)
    }

    @Test func pngNamesFollowThePlan() async throws {
        let bounce = try #require(FlareFixtures.named("bounce"))
        let o = options(.pngSequence, 0...47, step: 2)
        let plan = try PNGExportPlan.plan(scene: bounce.scenes[0], frames: o.frames, scale: o.scale, step: o.step)
        #expect(plan.count == 24)
        let fractions = Mutex<[Double]>([])
        let result = try await export(live, bounce, o) { p in fractions.withLock { $0.append(p) } }
        #expect(result.files.count == plan.count)
        #expect(result.files.map(\.name) == plan.map(\.fileName))
        #expect(result.files.allSatisfy { $0.data == FakeRasterizer.png })
        let seen = fractions.withLock { $0 }
        #expect(seen.count == plan.count && seen.last == 1 && seen == seen.sorted())
        #expect(result.warnings.isEmpty)
    }

    /// Cancelled from inside the first progress callback (the export's own task), so the cancel lands between
    /// frames: with a pause, `Task.sleep` throws; straight through, the check before the next frame does. Either
    /// way the loop stops at one frame and no `ExportResult` comes back.
    @Test(arguments: [Duration.milliseconds(20), .zero])
    func cancelLeavesNoFiles(frameDelay: Duration) async throws {
        let bounce = try #require(FlareFixtures.named("bounce"))
        let adapter = LiveExportAdapter(stage: LiveStage(), frameDelay: frameDelay)
        let calls = Mutex(0)
        let task = Task {
            try await export(adapter, bounce, options(.pngSequence, 0...47)) { _ in
                calls.withLock { $0 += 1 }
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(calls.withLock { $0 } == 1)
    }

    @Test func aCancelBeforeTheFirstFrameWritesNothing() async throws {
        let bounce = try #require(FlareFixtures.named("bounce"))
        let calls = Mutex(0)
        let task = Task { try await export(live, bounce, options(.pngSequence, 0...47)) { _ in calls.withLock { $0 += 1 } } }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(calls.withLock { $0 } == 0)
    }

    @Test func textNeverReachesTheExporters() async throws {
        let showcase = try #require(FlareFixtures.named("showcase"))
        #expect(showcase.scenes[0].layers.contains { !$0.texts.isEmpty })
        for format in ExportFormat.allCases {
            let o = options(format, 0...4, step: 2)
            let result = try await export(live, showcase, o)
            #expect(!result.files.isEmpty, "\(format)")
            #expect(result.warnings.contains("Text isn't exported yet (1 layer)."), "\(format)")
            #expect(result.warnings == ExportScan.warnings(showcase, options: o), "\(format)")
        }
    }

    @Test func svgTransparentDropsTheBackground() async throws {
        let bounce = try #require(FlareFixtures.named("bounce"))
        let opaque = try await export(live, bounce, options(.svgFrame, 12...12))
        let transparent = try await export(live, bounce, options(.svgFrame, 12...12, transparent: true))
        #expect(opaque.files.map(\.name) == ["scene-1.svg"] && transparent.files.map(\.name) == ["scene-1.svg"])
        let opaqueSVG = String(decoding: opaque.files[0].data, as: UTF8.self)
        let transparentSVG = String(decoding: transparent.files[0].data, as: UTF8.self)
        #expect(opaque.files[0].data != transparent.files[0].data)
        // The exporter's first element is the background rect, filled with the scene's color as #rrggbb.
        let scene = bounce.scenes[0]
        let rect = "<rect width=\"\(Int(scene.width))\" height=\"\(Int(scene.height))\" fill=\"\(hex(scene.background))\"/>"
        #expect(opaqueSVG.contains(rect), "opaque SVG fills the background: \(rect)")
        #expect(!transparentSVG.contains(rect), "transparent SVG has no opaque background fill")
        #expect(transparentSVG.contains("fill-opacity=\"0\""))
        #expect(transparentSVG.hasPrefix("<svg") && opaqueSVG.hasPrefix("<svg"))
    }

    /// `color` as SVG writes it, "#rrggbb".
    private func hex(_ color: FlareColor) -> String {
        "#" + [color.r, color.g, color.b].map { channel in
            let byte = Int((min(max(channel, 0), 1) * 255).rounded())
            let digits = String(byte, radix: 16)
            return digits.count == 1 ? "0" + digits : digits
        }.joined()
    }

    @Test func svgAndLottieBytesEqualFakeExportsOnBothStages() async throws {
        let fake = FakeExport(frameDelay: .zero)
        let adapters: [any Exporting] = [live, LiveExportAdapter(stage: FakeStage())]
        for name in ["bounce", "showcase", "character"] {
            let document = try #require(FlareFixtures.named(name))
            for o in [options(.svgFrame, 7...7), options(.svgFrame, 0...47, transparent: true), options(.lottie, 0...47),
                      options(.lottie, 0...47, transparent: true)] {
                let want = try await export(fake, document, o)
                for adapter in adapters {
                    let got = try await export(adapter, document, o)
                    #expect(got == want, "\(name) \(o.format) transparent \(o.transparentBackground)")
                }
            }
        }
    }

    @Test func warningsAreTheScans() throws {
        for (name, document) in FlareFixtures.all {
            for format in ExportFormat.allCases {
                for transparent in [false, true] {
                    let o = options(format, 0...0, transparent: transparent)
                    #expect(live.warnings(document, options: o) == ExportScan.warnings(document, options: o), "\(name) \(format)")
                }
            }
        }
        let gone = ExportOptions(format: .lottie, sceneID: "gone", frames: 0...0)
        #expect(live.warnings(FlareFixtures.bounce, options: gone).isEmpty)
    }

    @Test func aMissingSceneIsRefused() async {
        let gone = ExportOptions(format: .svgFrame, sceneID: "gone", frames: 0...0)
        await #expect(throws: CommandError.sceneNotFound("gone")) {
            try await export(live, FlareFixtures.bounce, gone)
        }
    }
}
