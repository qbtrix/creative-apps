// FrameClockTests.swift: shell-media SM-4's frame clock (MJ-SM1), written
// first by SM-2 and disabled until SM-4 adds `FrameClock`. Frame n shows at
// n / fps; GIF delays carry their rounding, round(100 (n + 1) / fps) -
// round(100 n / fps) centiseconds, so n frames always sum to round(100 n / fps):
// 30 fps runs 3, 4, 3 and 30 frames make exactly 100; 25 fps is all 4.
import SuiteModel
import Testing

/// What these tests use of SM-4's `FrameClock`; SM-4 adds
/// `extension FrameClock: FrameClockUnderTest {}` here.
protocol FrameClockUnderTest {
    func seconds(of frame: Int) -> Double
    mutating func nextGIFDelay() -> Int
}

@Suite struct FrameClockTests {
    /// SM-4 makes this `try FrameClock(fps: fps)`; nil until FrameClock exists.
    static func clock(fps: Int) throws(SuiteError) -> (any FrameClockUnderTest)? { nil }

    /// The first `count` GIF delays at `fps`, in centiseconds.
    static func delays(fps: Int, count: Int) throws -> [Int] {
        var clock = try #require(try Self.clock(fps: fps))
        var out: [Int] = []
        for _ in 0..<count { out.append(clock.nextGIFDelay()) }
        return out
    }

    @Test(.disabled("waits on SM-4")) func twentyFourFpsFrameFortyEightIsTwoSeconds() throws {
        let clock = try #require(try Self.clock(fps: 24))
        #expect(clock.seconds(of: 48) == 2.0)
        #expect(clock.seconds(of: 24) == 1.0)
        #expect(clock.seconds(of: 0) == 0)
        let ntsc = try #require(try Self.clock(fps: 30))
        #expect(ntsc.seconds(of: 1) == 1.0 / 30)
    }

    @Test(.disabled("waits on SM-4")) func thirtyFpsSumsToOneSecond() throws {
        #expect(try Self.delays(fps: 30, count: 30).reduce(0, +) == 100)
    }

    @Test(.disabled("waits on SM-4")) func firstDelayIsThree() throws {
        let delays = try Self.delays(fps: 30, count: 6)
        #expect(delays == [3, 4, 3, 3, 4, 3])
    }

    @Test(.disabled("waits on SM-4")) func twentyFiveFpsIsAllFour() throws {
        #expect(try Self.delays(fps: 25, count: 25) == Array(repeating: 4, count: 25))
    }

    @Test(.disabled("waits on SM-4")) func delaysNeverDrift() throws {
        for fps in [1, 7, 12, 15, 24, 29, 30, 33, 48, 50] {
            let delays = try Self.delays(fps: fps, count: fps * 3)
            var sum = 0
            for (i, delay) in delays.enumerated() {
                sum += delay
                let n = Double(i + 1)
                #expect(sum == Int((100 * n / Double(fps)).rounded()), "fps \(fps), frame \(i + 1)")
            }
        }
    }

    @Test(.disabled("waits on SM-4")) func aRateBelowOneThrows() {
        #expect(throws: SuiteError.self) { try Self.clock(fps: 0) }
        #expect(throws: SuiteError.self) { try Self.clock(fps: -24) }
    }
}
