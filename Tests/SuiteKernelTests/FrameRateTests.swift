// FrameRateTests.swift (frame-rates FR-2 written, FR-3 turned on): the one rate list as exact rationals, the
// one rounding rule from seconds to frames, and the three shapes a stored rate decodes from.
import Foundation
import Testing
import SuiteKernel

@Suite struct FrameRateTests {
    static let ntsc = FrameRate(numerator: 30000, denominator: 1001)
    static func decode(_ json: String) throws -> FrameRate { try JSONDecoder().decode(FrameRate.self, from: Data(json.utf8)) }

    /// The nine rates in order, the three NTSC ones exact (mutation `.ntscExact`).
    @Test func commonIsTheNineInOrder() {
        let pairs = FrameRate.common.map { [$0.numerator, $0.denominator] }
        #expect(pairs == [[12, 1], [24000, 1001], [24, 1], [25, 1], [30000, 1001], [30, 1], [50, 1], [60000, 1001], [60, 1]])
        #expect(FrameRate.common.filter(\.isWhole).count == 6)
        #expect(FrameRate.common.filter(\.isDropFrame) == [Self.ntsc, FrameRate(numerator: 60000, denominator: 1001)])
    }

    /// A rate is stored reduced, with a positive denominator.
    @Test func initReduces() {
        let rate = FrameRate(numerator: 60, denominator: 2)
        #expect(rate.numerator == 30 && rate.denominator == 1 && rate == FrameRate(whole: 30))
        #expect(FrameRate(numerator: 60000, denominator: 2002) == FrameRate(numerator: 30000, denominator: 1001))
        #expect(FrameRate(numerator: 24, denominator: 1).isWhole && !FrameRate(numerator: 24000, denominator: 1001).isDropFrame)
    }

    /// Timecode counts nominal frames: 30 at 29.97, 24 at 23.976, 60 at 59.94.
    @Test func nominalIsTheRoundedRate() {
        #expect(Self.ntsc.nominal == 30 && FrameRate(numerator: 24000, denominator: 1001).nominal == 24)
        #expect(FrameRate(numerator: 60000, denominator: 1001).nominal == 60 && FrameRate(whole: 25).nominal == 25)
    }

    /// 10 s at 29.97 is 300 frames and 1 s at 23.976 is 24, both by rounding half up (mutation `.durationRounds`).
    @Test func durationRoundsToWholeFrames() {
        #expect(Self.ntsc.frames(forDuration: 10) == 300)
        #expect(FrameRate(numerator: 24000, denominator: 1001).frames(forDuration: 1) == 24)
        #expect(FrameRate(whole: 24).frames(forDuration: 2.5) == 60 && FrameRate(whole: 2).frames(forDuration: 0.25) == 1)
    }

    /// Frame 299 at 29.97 is 299 × 1001 / 30000 s, and the nearest frame to a time rounds ties up.
    @Test func secondsAndFrameAreExact() {
        #expect(abs(Self.ntsc.seconds(ofFrame: 299) - 299.0 * 1001 / 30000) < 1e-6)
        #expect(Self.ntsc.frame(atSeconds: Self.ntsc.seconds(ofFrame: 1800)) == 1800)
        #expect(FrameRate(whole: 2).frame(atSeconds: 0.25) == 1 && FrameRate(whole: 2).frame(atSeconds: 0.24) == 0)
    }

    /// `{num, den}`, a legacy `Int` and a decimal from `common` decode; a decimal outside it throws.
    @Test func decodesThreeShapes() throws {
        #expect(try Self.decode(#"{"num":30000,"den":1001}"#) == Self.ntsc)
        #expect(try Self.decode("30") == FrameRate(whole: 30))
        #expect(try Self.decode("29.97") == Self.ntsc)
        #expect(try Self.decode("23.976") == FrameRate(numerator: 24000, denominator: 1001))
        #expect(try Self.decode("59.94") == FrameRate(numerator: 60000, denominator: 1001))
        #expect(throws: (any Error).self) { try Self.decode("29.5") }
        #expect(throws: (any Error).self) { try Self.decode(#"{"num":30,"den":0}"#) }
    }

    /// A rate encodes as `{num, den}` and decodes back to itself.
    @Test func roundTripsAsNumAndDen() throws {
        for rate in FrameRate.common {
            let data = try JSONEncoder().encode(rate)
            #expect(try JSONDecoder().decode(FrameRate.self, from: data) == rate)
            #expect(String(decoding: data, as: UTF8.self).contains(#""num":\#(rate.numerator)"#))
        }
        #expect(Self.ntsc.description == "29.97 fps" && FrameRate(whole: 24).description == "24 fps")
    }
}
