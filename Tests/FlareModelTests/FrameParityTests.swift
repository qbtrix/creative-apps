// FrameParityTests.swift (lottie-player-check LP-3, #3792): the reference player's frame matches the stage's when at
// most 2% of the pixels differ by more than 8 levels in a channel, and a loop's last frame is not frame 0 again.
import FlareModel
import Testing

@Suite struct FrameParityTests {
    static let (w, h) = (100, 100)

    /// A mid-grey opaque frame.
    static func frame() -> [UInt8] { [UInt8](repeating: 128, count: w * h * 4) }

    /// `frame()` with the first `pixels` pixels' `channel` raised by `levels`.
    static func off(_ pixels: Int, by levels: UInt8, channel: Int = 0) -> [UInt8] {
        var bytes = frame()
        for p in 0..<pixels { bytes[p * 4 + channel] = 128 + levels }
        return bytes
    }

    @Test func onePercentOffByTwentyPasses() {
        let a = Self.frame(), b = Self.off(100, by: 20)
        #expect(FrameParity.mismatch(a, b, width: Self.w, height: Self.h) == 0.01)
        #expect(FrameParity.matches(a, b, width: Self.w, height: Self.h))
    }

    @Test func exactlyTwoPercentPasses() {
        #expect(FrameParity.matches(Self.frame(), Self.off(200, by: 20), width: Self.w, height: Self.h))
        #expect(!FrameParity.matches(Self.frame(), Self.off(201, by: 20), width: Self.w, height: Self.h))
    }

    @Test func threePercentOffByTwentyFails() {
        let a = Self.frame(), b = Self.off(300, by: 20)
        #expect(FrameParity.mismatch(a, b, width: Self.w, height: Self.h) == 0.03)
        #expect(!FrameParity.matches(a, b, width: Self.w, height: Self.h))
    }

    @Test func fivePercentOffBySixPasses() {
        let b = Self.off(500, by: 6)
        #expect(FrameParity.mismatch(Self.frame(), b, width: Self.w, height: Self.h) == 0)
        #expect(FrameParity.matches(Self.frame(), b, width: Self.w, height: Self.h))
    }

    @Test func exactlyEightLevelsOffIsNotADifference() {
        let b = Self.off(500, by: 8)
        #expect(FrameParity.mismatch(Self.frame(), b, width: Self.w, height: Self.h) == 0)
        #expect(FrameParity.matches(Self.frame(), b, width: Self.w, height: Self.h))
        #expect(!FrameParity.matches(Self.frame(), Self.off(500, by: 9), width: Self.w, height: Self.h))
    }

    @Test(arguments: [1, 2, 3])
    func everyChannelCounts(_ channel: Int) {
        let b = Self.off(300, by: 20, channel: channel)
        #expect(!FrameParity.matches(Self.frame(), b, width: Self.w, height: Self.h))
    }

    @Test func aLoopEndingOnFrameZeroFails() {
        let first = Self.off(400, by: 40)
        #expect(!FrameParity.loopIsClean(first: first, last: first, width: Self.w, height: Self.h))
        #expect(FrameParity.loopIsClean(first: first, last: Self.frame(), width: Self.w, height: Self.h))
    }

    @Test func mismatchedBuffersFailWithoutCrashing() {
        let short = [UInt8](repeating: 128, count: 10)
        #expect(FrameParity.mismatch(Self.frame(), short, width: Self.w, height: Self.h) == 1)
        #expect(!FrameParity.matches(Self.frame(), short, width: Self.w, height: Self.h))
        #expect(!FrameParity.matches(Self.frame(), Self.frame(), width: Self.w, height: Self.h + 1))
        #expect(!FrameParity.loopIsClean(first: Self.frame(), last: short, width: Self.w, height: Self.h))
    }

    @Test func aZeroSizeFrameFailsWithoutDividingByZero() {
        #expect(FrameParity.mismatch([], [], width: 0, height: 0) == 1)
        #expect(!FrameParity.matches([], [], width: 0, height: 10))
        #expect(!FrameParity.matches([], [], width: -2, height: -2))
        #expect(!FrameParity.loopIsClean(first: [], last: [], width: 0, height: 0))
        #expect(!FrameParity.matches([], [], width: Int.max, height: 2))
    }
}
