// Budget+HandOff.swift: QB-SM4, `HandOffCodec` encode and decode of one
// hand-off (blueprint 7.1): ≤ 0.2 ms on device, ≤ 2 ms in debug (the gate).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct HandOffBudgetTests {
    @Test func encodeAndDecodeOneHandOff() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let preset = NewDocumentPreset(id: "flare.hd", app: .flare, title: "HD", detail: "1920 × 1080, 24 fps")
        let handOff = HandOff(id: HandOff.newID(), from: .launcher, to: .flare, verb: .new,
                              preset: preset, createdAt: now)
        let budget = suiteBudget(device: 0.2)
        let clock = ContinuousClock()
        var costs: [Duration] = []
        for _ in 0..<30 {
            let start = clock.now
            let data = try HandOffCodec.encode(handOff)
            _ = try HandOffCodec.decode(data)
            costs.append(clock.now - start)
        }
        print("SuiteBudget QB-SM4 handoff encode+decode p50 \(suiteMedian(costs)) budget \(budget)")
        #expect(suiteMedian(costs) <= budget)
    }
}
