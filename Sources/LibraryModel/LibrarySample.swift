// LibrarySample.swift: 60 seeded sample photos for File > Load Sample Photos
// until import lands (L2). The same seed always gives the same items.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor

public enum LibrarySample {
    public static let defaultSeed: UInt64 = 2026

    /// 60 items from `seed`. Dates fall at whole minutes in 2026.
    public static func items(seed: UInt64 = defaultSeed) -> [PhotoItem] {
        var random = SplitMix64(seed: seed)
        let start = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01 00:00 UTC
        let minutesInYear: UInt64 = 365 * 24 * 60
        let labels: [PhotoLabel?] = [nil, nil, nil] + PhotoLabel.allCases.map(Optional.some)
        return (0..<60).map { index in
            let minute = random.next() % minutesInYear
            let color = Color3(random.unit(), random.unit(), random.unit())
            let rating = Int(random.next() % 6)
            let isFlagged = random.next() % 4 == 0
            let label = labels[Int(random.next() % UInt64(labels.count))]
            let number = String(index + 1)
            return PhotoItem(
                name: "IMG_" + String(repeating: "0", count: max(4 - number.count, 0)) + number,
                captureDate: start.addingTimeInterval(Double(minute) * 60),
                color: color, rating: rating, isFlagged: isFlagged, label: label)
        }
    }
}

/// SplitMix64, a public-domain seedable generator.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
}
