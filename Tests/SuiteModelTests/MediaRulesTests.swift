// MediaRulesTests.swift: shell-media SM-3's settings rules (MJ-SM1), written
// first by SM-2 and turned on by SM-3's `validated()`. Sizes 16...8192;
// H.264 and HEVC (4:2:0) refuse odd sizes, ProRes 4444 takes them; fps
// 1...120 for movies and APNG, 1...50 for GIF; quality 0...1; loop count
// 0...65,535. Every refusal is `notAvailable` with a sentence a person can act on.
import SuiteModel
import Testing

@Suite struct MediaRulesTests {
    static func checked(_ settings: MovieSettings) throws(SuiteError) -> MovieSettings { try settings.validated() }
    static func checked(_ settings: AnimatedImageSettings) throws(SuiteError) -> AnimatedImageSettings {
        try settings.validated()
    }

    static func movie(_ width: Int, _ height: Int, fps: Int = 24, _ codec: MovieCodec = .h264,
                      quality: Double = 0.8) -> MovieSettings {
        MovieSettings(width: width, height: height, fps: fps, codec: codec, quality: quality)
    }

    static func animated(_ width: Int = 320, _ height: Int = 240, fps: Int = 25, _ format: AnimatedImageFormat = .gif,
                         loop: Int = 0) -> AnimatedImageSettings {
        AnimatedImageSettings(width: width, height: height, fps: fps, format: format, loopCount: loop)
    }

    /// The error `body` throws, or nil when it returns.
    static func refusal(_ body: () throws(SuiteError) -> Void) -> SuiteError? {
        do { try body(); return nil } catch { return error }
    }

    @Test func oddH264IsRefusedWithTheEvenSentence() {
        #expect(throws: SuiteError.notAvailable("Width and height must be even for H.264.")) {
            try Self.checked(Self.movie(1281, 720))
        }
        #expect(throws: SuiteError.self) { try Self.checked(Self.movie(1280, 721, .hevc)) }
    }

    @Test func proResTakesOddSizes() throws {
        let odd = Self.movie(1281, 721, .prores4444)
        #expect(try Self.checked(odd) == odd)
    }

    @Test func sizesOutsideSixteenToEightKAreRefused() {
        for codec in MovieCodec.allCases {
            #expect(throws: SuiteError.self) { try Self.checked(Self.movie(15, 15, codec)) }
            #expect(throws: SuiteError.self) { try Self.checked(Self.movie(8193, 720, codec)) }
        }
        #expect(throws: SuiteError.self) { try Self.checked(Self.animated(15, 240)) }
        #expect(throws: SuiteError.self) { try Self.checked(Self.animated(320, 8193, .apng)) }
    }

    @Test func eightKAccepted() throws {
        for codec in MovieCodec.allCases {
            let edge = Self.movie(8192, 16, codec)
            #expect(try Self.checked(edge) == edge)
        }
        let animated = Self.animated(16, 8192, .apng)
        #expect(try Self.checked(animated) == animated)
    }

    @Test func gifCapsAtFifty() throws {
        #expect(throws: SuiteError.self) { try Self.checked(Self.animated(fps: 60)) }
        #expect(try Self.checked(Self.animated(fps: 50)) == Self.animated(fps: 50))
        #expect(try Self.checked(Self.animated(fps: 60, .apng)) == Self.animated(fps: 60, .apng))
        #expect(throws: SuiteError.self) { try Self.checked(Self.animated(fps: 121, .apng)) }
        #expect(throws: SuiteError.self) { try Self.checked(Self.animated(fps: 0)) }
    }

    @Test func movieRatesRunOneToOneTwenty() throws {
        #expect(try Self.checked(Self.movie(1280, 720, fps: 120)) == Self.movie(1280, 720, fps: 120))
        #expect(try Self.checked(Self.movie(1280, 720, fps: 1)) == Self.movie(1280, 720, fps: 1))
        #expect(throws: SuiteError.self) { try Self.checked(Self.movie(1280, 720, fps: 121)) }
        #expect(throws: SuiteError.self) { try Self.checked(Self.movie(1280, 720, fps: 0)) }
    }

    @Test func qualityRunsZeroToOne() throws {
        #expect(throws: SuiteError.self) { try Self.checked(Self.movie(1280, 720, quality: 1.2)) }
        #expect(throws: SuiteError.self) { try Self.checked(Self.movie(1280, 720, quality: -0.1)) }
        #expect(try Self.checked(Self.movie(1280, 720, quality: 0)).quality == 0)
        #expect(try Self.checked(Self.movie(1280, 720, quality: 1)).quality == 1)
    }

    @Test func loopCountRunsZeroToSixtyFiveThousand() throws {
        #expect(throws: SuiteError.self) { try Self.checked(Self.animated(loop: 70_000)) }
        #expect(throws: SuiteError.self) { try Self.checked(Self.animated(loop: -1)) }
        #expect(try Self.checked(Self.animated(loop: 65_535)).loopCount == 65_535)
        #expect(try Self.checked(Self.animated(loop: 0)).loopCount == 0)
    }

    @Test func everyRefusalIsASentence() throws {
        let movies = [Self.movie(1281, 720), Self.movie(15, 15, .prores4444), Self.movie(1280, 720, fps: 0),
                      Self.movie(1280, 720, quality: 1.2)]
        let animated = [Self.animated(fps: 60), Self.animated(loop: 70_000), Self.animated(8193, 240, .apng)]
        let refusals = movies.map { m in Self.refusal { () throws(SuiteError) in _ = try Self.checked(m) } }
            + animated.map { a in Self.refusal { () throws(SuiteError) in _ = try Self.checked(a) } }
        for refusal in refusals {
            guard case .notAvailable(let sentence) = try #require(refusal) else {
                Issue.record("\(String(describing: refusal)) is not notAvailable"); continue
            }
            #expect(sentence.first?.isUppercase == true && sentence.hasSuffix("."), "\(sentence)")
        }
    }
}
