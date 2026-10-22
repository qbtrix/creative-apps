// MediaContractTests.swift: shell-media SM-1 (MJ-SM0). `SuiteServices.fake().media`
// records a 3-frame movie in order and a still, an unavailable fake throws its
// reason, `MediaFrame` refuses a byte count other than width x height x 4, and
// `pending["media"]` names why the media service isn't live.
import Foundation
import SuiteModel
import Testing

@Suite struct MediaContractTests {
    static func frame(_ value: UInt8, width: Int = 2, height: Int = 2) throws -> MediaFrame {
        try MediaFrame(width: width, height: height, rgba: Array(repeating: value, count: width * height * 4))
    }

    static let settings = MovieSettings(width: 2, height: 2, fps: 24, codec: .h264, quality: 0.8)

    @Test func fakeRecordsInOrder() async throws {
        let media = FakeMedia()
        let sink = try media.movie(at: "/out/a.mov", Self.settings)
        let frames = try [Self.frame(10), Self.frame(20), Self.frame(30)]
        for f in frames { try sink.append(f) }
        try await sink.finish()
        #expect(media.movies["/out/a.mov"] == frames)
        #expect(media.settings["/out/a.mov"] == Self.settings)
        let info = try await media.info(ofMovieAt: "/out/a.mov")
        #expect(info.frameCount == 3 && info.width == 2 && info.fps == 24 && info.codec == "h264")
        #expect(try await media.frame(ofMovieAt: "/out/a.mov", seconds: 1.0 / 24, longestSide: nil) == frames[1])
    }

    @Test func aStillIsRecorded() throws {
        let media = SuiteServices.fake().media
        let still = try Self.frame(200)
        let data = try media.still(still, as: .png, quality: 1)
        #expect(!data.isEmpty)
        let fake = try #require(media as? FakeMedia)
        #expect(fake.stills.count == 1)
        #expect(fake.stills.first?.format == .png && fake.stills.first?.frame == still)
    }

    @Test func cancelledMovieIsNotRecorded() async throws {
        let media = FakeMedia()
        let sink = try media.animatedImage(at: "/out/a.gif",
                                           AnimatedImageSettings(width: 2, height: 2, fps: 25, format: .gif, loopCount: 0))
        try sink.append(Self.frame(1))
        sink.cancel()
        #expect(media.movies["/out/a.gif"] == nil)
        #expect(media.cancelled == ["/out/a.gif"])
    }

    @Test func sinkRefusesAFrameOfTheWrongSize() throws {
        let sink = try FakeMedia().movie(at: "/out/b.mov", Self.settings)
        #expect(throws: SuiteError.self) { try sink.append(Self.frame(1, width: 4, height: 2)) }
    }

    @Test func unavailableThrowsItsReason() async throws {
        let reason = "Movie and image export isn't available yet."
        let media = FakeMedia(unavailable: reason)
        #expect(media.movieCodecs.isEmpty)
        #expect(throws: SuiteError.notAvailable(reason)) { _ = try media.movie(at: "/out/a.mov", Self.settings) }
        #expect(throws: SuiteError.notAvailable(reason)) { _ = try media.still(Self.frame(1), as: .jpeg, quality: 0.9) }
        #expect(throws: SuiteError.notAvailable(reason)) { _ = try media.still(Data([1, 2]), longestSide: nil) }
        await #expect(throws: SuiteError.notAvailable(reason)) { _ = try await media.info(ofMovieAt: "/a.mov") }
    }

    @Test func refusesWrongByteCount() throws {
        #expect(throws: SuiteError.self) { _ = try MediaFrame(width: 2, height: 2, rgba: Array(repeating: 0, count: 15)) }
        #expect(throws: SuiteError.self) { _ = try MediaFrame(width: 2, height: 2, rgba: Array(repeating: 0, count: 17)) }
        #expect(throws: SuiteError.self) { _ = try MediaFrame(width: 0, height: 2, rgba: []) }
        #expect(throws: SuiteError.self) { _ = try MediaFrame(width: Int.max, height: 2, rgba: []) }
        let ok = try MediaFrame(width: 2, height: 2, rgba: Array(repeating: 0, count: 16))
        #expect(ok.width == 2 && ok.height == 2 && ok.rgba.count == 16)
    }

    @Test func codecsSayWhatTheyKeep() {
        #expect(MovieCodec.allCases.filter(\.keepsAlpha) == [.hevcAlpha, .prores4444])
        #expect(MovieCodec.allCases.filter(\.needsEvenSize) == [.h264, .hevc, .hevcAlpha])
        #expect(StillFormat.allCases.map(\.rawValue) == ["png", "jpeg", "heic", "tiff"])
        #expect(AnimatedImageFormat.allCases.map(\.rawValue) == ["gif", "apng"])
    }

    @Test func fakeServicesNameTheMediaReason() {
        let s = SuiteServices.fake()
        #expect(s.pending["media"] == "Movie and image export isn't available yet.")
        #expect(s.pending["media"] == SuiteServices.notConnected("media"))
        #expect(s.media is FakeMedia)
        #expect(s.media.movieCodecs == MovieCodec.allCases)
    }
}
