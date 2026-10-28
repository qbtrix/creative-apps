// LibraryDevelopLatencyTests.swift: how long one develop step on an 8K photo (7680 x 4320) takes from the
// slider value changing to the loupe's pixels and histogram holding the new picture (suite-imaging IM-9
// writes it, IM-11 turns it on). Each step moves Exposure by 0.01 stop on the settings the loupe holds and
// takes the GPU route the loupe takes (IM-11): the photo uploaded once and resident, each step its
// `LiveDevelop.steps` written through `ImagingGPU.display` into an 8K texture like the canvas host's resident
// one, plus the histogram of the 512 px preview developed on the CPU. Waits (bounded) for the display
// pipelines to compile; without a GPU it skips. Warms with one untimed step, then times `events` steps. The
// budget is p95 <= 30 ms per step in release, the target 16 ms (one display frame). Report-only
// (Tests/perf-suites.txt, line `library AppSnapshotTests.LibraryDevelopLatencyTests`): the DEVELOP-STEP-8K
// line in .build/snapshots/library-develop-latency.txt. Read release numbers: a debug build is 20x slower.
// macOS only.
#if canImport(Metal)
import CoreRaster
import CoreRender
import Foundation
import Metal
import SuiteImaging
import Testing

@testable import LibraryModel

@Suite(.serialized, .disabled("waits on its Tests/perf-suites.txt line")) struct LibraryDevelopLatencyTests {
    static let config = _isDebugAssertConfiguration() ? "debug" : "release"
    static let events = config == "release" ? 30 : 3
    static let width = 7680, height = 4320
    /// One display frame at 60 Hz.
    static let target = 16.0
    /// The p95 budget per step in release.
    static let budget = 30.0

    /// An 8K gradient in sRGB bytes: red across, green down, blue fixed, opaque.
    static func photo() throws -> PixelBuffer {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i] = UInt8(x * 255 / (width - 1))
                bytes[i + 1] = UInt8(y * 255 / (height - 1))
                bytes[i + 2] = 128
            }
        }
        return try PixelBuffer(rgba8: bytes, width: width, height: height)
    }

    /// The loupe's GPU route: the photo resident on `gpu`, the texture it writes, the 512 px preview.
    struct Route {
        let gpu: ImagingGPU.Backend
        let surface: ImagingGPU.Surface
        let texture: any MTLTexture
        let preview: PixelBuffer
        let develop = LiveDevelop()
    }

    /// Milliseconds for one step: the settings changed, the loupe's pixels written and its histogram made.
    static func step(_ i: Int, on route: Route) throws -> Double {
        let settings = DevelopSettings.neutral.setting(.exposure, to: 0.5 + Double(i) * 0.01)
        let clock = ContinuousClock()
        let start = clock.now
        let steps = try #require(LiveDevelop.steps(for: settings))
        try ImagingGPU.display(route.surface, into: route.texture, program: steps.map(ToneProgram.Operation.adjustment),
                               displaySteps: ImagingColor.displaySteps(to: .sRGB))
        _ = try route.develop.histogram(of: route.develop.render(route.preview, settings: settings))
        let elapsed = clock.now - start
        return Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
    }

    /// The route on the system GPU once its display pipelines compile (at most 30 s); nil without a GPU.
    static func route() async throws -> Route? {
        guard let gpu = ImagingGPU.systemBackend() else { return nil }
        for _ in 0..<300 where !gpu.isReady { try await Task.sleep(for: .milliseconds(100)) }
        try #require(gpu.isReady, "the display pipelines didn't compile in 30 s")
        let photo = try Self.photo()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = try #require(gpu.device.makeTexture(descriptor: descriptor))
        return Route(gpu: gpu, surface: try gpu.upload(photo), texture: texture,
                     preview: try photo.resized(width: 512, height: 288, filter: .bilinear))
    }

    @Test func oneDevelopStepAt8K() async throws {
        guard let route = try await Self.route() else { return }
        _ = try Self.step(0, on: route)
        let times = try (1...Self.events).map { try Self.step($0, on: route) }.sorted()
        let p95 = times[min(times.count - 1, Int((Double(times.count) * 0.95).rounded(.up)) - 1)]
        let p50 = times[times.count / 2]
        let line = String(format: "DEVELOP-STEP-8K %@ gpu p50 %.1f ms p95 %.1f ms (target %.0f, budget %.0f)",
                          Self.config, p50, p95, Self.target, Self.budget)
        let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data((line + "\n").utf8).write(to: folder.appendingPathComponent("library-develop-latency.txt"))
        print(line)
        if Self.config == "release" { #expect(p95 <= Self.budget, "\(line)") }
    }
}
#endif
