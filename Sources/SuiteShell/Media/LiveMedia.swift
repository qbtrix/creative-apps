// LiveMedia.swift: shell-media's live MediaCoding (SM-9), the `media` member
// of SuiteServices.live. It holds no state of its own: each call goes to one
// of the four coders in Media/. Movies are MovieWriter's (its codec list is
// this Mac's), animated images AnimatedImageWriter's, stills StillEncoder's
// and StillDecoder's, and movie info and frames FootageReader's. Each sink is
// a new writer for one file; errors are the coders' own SuiteErrors.
import Foundation
import SuiteModel

public struct LiveMedia: MediaCoding {
    private let encoder = StillEncoder()
    private let decoder = StillDecoder()
    private let footage = FootageReader()

    public init() {}

    // MARK: MediaEncoding

    public var movieCodecs: [MovieCodec] { MovieWriter.codecs }

    public func movie(at path: String, _ settings: MovieSettings) throws(SuiteError) -> any FrameSink {
        try MovieWriter(path: path, settings)
    }

    public func animatedImage(at path: String, _ settings: AnimatedImageSettings) throws(SuiteError) -> any FrameSink {
        try AnimatedImageWriter(path: path, settings)
    }

    public func still(_ frame: MediaFrame, as format: StillFormat, quality: Double) throws(SuiteError) -> Data {
        try encoder.still(frame, as: format, quality: quality)
    }

    // MARK: MediaDecoding

    public func still(_ data: Data, longestSide: Int?) throws(SuiteError) -> MediaFrame {
        try decoder.still(data, longestSide: longestSide)
    }

    public func info(ofMovieAt path: String) async throws(SuiteError) -> MediaInfo {
        try await footage.info(ofMovieAt: path)
    }

    public func frame(ofMovieAt path: String, seconds: Double, longestSide: Int?) async throws(SuiteError) -> MediaFrame {
        try await footage.frame(ofMovieAt: path, seconds: seconds, longestSide: longestSide)
    }
}
