// DesignIDMintTests.swift: DesignIDMint hands out "node-N" ids that skip the
// file's taken ids, never repeat, and are recorded in order in `minted`; a
// negative starting counter starts at 0. Runs on Linux and macOS.
import DesignModel
import Testing

@Suite struct DesignIDMintTests {
    @Test func skipsTakenIdsAndRecordsWhatItMints() {
        var mint = DesignIDMint(taken: ["node-1", "node-3"], after: 0)
        let ids = [mint.nextNodeID(), mint.nextNodeID(), mint.nextNodeID()]
        #expect(ids == ["node-2", "node-4", "node-5"])
        #expect(mint.minted == ["node-2", "node-4", "node-5"])
        #expect(mint.counter == 5)
    }

    @Test func aNegativeCounterStartsAtZero() {
        var mint = DesignIDMint(taken: [], after: -7)
        #expect(mint.counter == 0)
        #expect(mint.nextNodeID() == "node-1")
    }

    @Test func aThousandCallsNeverRepeatOrHitTaken() {
        let taken = Set(stride(from: 2, through: 2_000, by: 2).map { "node-\($0)" })
        var mint = DesignIDMint(taken: taken, after: 0)
        let ids = (0..<1_000).map { _ in mint.nextNodeID() }
        #expect(Set(ids).count == 1_000)
        #expect(Set(ids).isDisjoint(with: taken))
        #expect(mint.minted == ids)
    }
}
