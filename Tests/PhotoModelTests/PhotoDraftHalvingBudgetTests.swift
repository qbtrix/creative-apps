// PhotoDraftHalvingBudgetTests.swift: the wall-clock budget of a shrinking Free Transform draft's one-time
// halving of a 24 MP layer (`PhotoWorkspace.halvedAcrossCores`, PhotoRenderRoute.swift). The drag frame that
// first needs a level waits on it, under the draft cache's lock, so it is the frame's hitch (#6206). An optimized
// build (`swift build -c release --target PhotoModelTests -Xswiftc -enable-testing`) times 20 runs and gates the
// p95; a debug build runs it twice and checks only the size. It reads the wall clock, so it stays disabled until
// Tests/perf-suites.txt lists it (perf-nightly runs it, never CI). Runs on Linux and macOS.
import CoreRaster
import Testing

@testable import PhotoModel

@Suite struct PhotoDraftHalvingBudgetTests {
    /// The 24 MP halving's p95 in an optimized build, in ms: measured p95 254 ms (p50 184) at load 15 on this Mac,
    /// against 1.5 s for CoreRaster's one-core call. The GPU halving that would take it under a frame is core#837.
    static let budget = 400.0

    @Test(.disabled("reads the wall clock: waits on a Tests/perf-suites.txt line (#6410)"))
    func a24MegapixelHalvingFitsItsBudget() throws {
        let source = try PixelBuffer(width: 6000, height: 4000, fill: RGBA(r: 0.2, g: 0.4, b: 0.6, a: 1))
        let optimized = !_isDebugAssertConfiguration()
        var times: [Double] = []
        for _ in 0..<(optimized ? 20 : 2) {
            let start = ContinuousClock.now
            let half = try PhotoWorkspace.halvedAcrossCores(source)
            let took = start.duration(to: .now)
            times.append(Double(took.components.seconds) * 1000 + Double(took.components.attoseconds) / 1e15)
            #expect(half.width == 3000 && half.height == 2000)
        }
        times.sort()
        let p95 = times[min(times.count - 1, times.count * 95 / 100)]
        print("PhotoDraftHalvingBudgetTests 24 MP halving: p50 \(times[times.count / 2]) ms, p95 \(p95) ms")
        if optimized { #expect(p95 <= Self.budget, "24 MP halving p95 \(p95) ms, over \(Self.budget) ms") }
    }
}
