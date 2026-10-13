// FlareEllipseScaleFuzzTests.swift: the Ellipse minimum is monotonic in the
// stage scale over the whole Double range, not just a sweep (#496). Seeded
// fuzz over random bit patterns, and the exact ulps around the scale where
// 1 / scale overflows. Runs on Linux and macOS.
import FlareModel
import Testing

private func minimum(_ scale: Double) -> Double {
    FlareWorkspace.minimumEllipseExtent(atStageScale: scale)
}

/// A deterministic generator (SplitMix64), so a failure reproduces.
private struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Test func randomBitPatternScalesNeverGiveASmallerMinimumForASmallerScale() {
    var rng = SplitMix(state: 496)
    for _ in 0..<20_000 {
        let a = Double(bitPattern: rng.next()), b = Double(bitPattern: rng.next())
        guard !a.isNaN, !b.isNaN else { continue }
        let (low, high) = a < b ? (a, b) : (b, a)
        #expect(minimum(low) >= minimum(high), "scales \(low) < \(high)")
        #expect(minimum(a).isFinite && minimum(a) > 0, "scale \(a)")
    }
}

@Test func theUlpsAroundTheOverflowScaleStayOrdered() {
    // The largest scale whose 1 / scale overflows, found by bisecting bits.
    var lo = Double.leastNonzeroMagnitude.bitPattern, hi = 1.0.bitPattern
    while hi - lo > 1 {
        let mid = lo + (hi - lo) / 2
        if (1 / Double(bitPattern: mid)).isFinite { hi = mid } else { lo = mid }
    }
    var scale = Double(bitPattern: lo)
    for _ in 0..<8 { scale = scale.nextDown }
    var previous = minimum(scale)
    for _ in 0..<16 {
        scale = scale.nextUp
        let current = minimum(scale)
        #expect(current <= previous && current.isFinite && current >= 1, "scale \(scale)")
        previous = current
    }
}
