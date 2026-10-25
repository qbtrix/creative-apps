// LibraryDevelopLatencyTests.swift: how long one develop step on an 8K photo (7680 x 4320) takes from the
// slider value changing to the loupe's pixels and histogram holding the new picture (suite-imaging IM-9
// writes it, IM-11 turns it on). Each step moves Exposure by 0.01 stop on the settings the loupe holds and
// renders them; IM-11 swaps the render for the GPU route (the photo resident in a LiveToneSurface, the step
// written into the loupe's resident texture). Warms with one untimed step, then times `events` steps. The
// budget is p95 <= 30 ms per step in release, the target 16 ms (one display frame). Report-only
// (Tests/perf-suites.txt, line `library AppSnapshotTests.LibraryDevelopLatencyTests`): the DEVELOP-STEP-8K
// line in .build/snapshots/library-develop-latency.txt. Read release numbers: a debug build is 20x slower.
// macOS only.
import CoreRaster
import Foundation
import Testing

@testable import LibraryModel

@Suite(.serialized, .disabled("waits on IM-11")) struct LibraryDevelopLatencyTests {
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

    /// Milliseconds for one step: the settings changed, the loupe's pixels and histogram rendered.
    static func step(_ i: Int, photo: PixelBuffer, develop: LiveDevelop) throws -> Double {
        let settings = DevelopSettings.neutral.setting(.exposure, to: 0.5 + Double(i) * 0.01)
        let clock = ContinuousClock()
        let start = clock.now
        let rendered = try develop.render(photo, settings: settings)
        _ = try develop.histogram(of: rendered)
        let elapsed = clock.now - start
        return Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
    }

    @Test func oneDevelopStepAt8K() throws {
        let photo = try Self.photo(), develop = LiveDevelop()
        _ = try Self.step(0, photo: photo, develop: develop)
        let times = try (1...Self.events).map { try Self.step($0, photo: photo, develop: develop) }.sorted()
        let p95 = times[min(times.count - 1, Int((Double(times.count) * 0.95).rounded(.up)) - 1)]
        let p50 = times[times.count / 2]
        let line = String(format: "DEVELOP-STEP-8K %@ p50 %.1f ms p95 %.1f ms (target %.0f, budget %.0f)",
                          Self.config, p50, p95, Self.target, Self.budget)
        let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data((line + "\n").utf8).write(to: folder.appendingPathComponent("library-develop-latency.txt"))
        print(line)
        if Self.config == "release" { #expect(p95 <= Self.budget, "\(line)") }
    }
}
