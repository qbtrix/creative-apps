// MediaDecoding.swift: shell-media's reading half (SM-1). Images and footage
// in, frames out. Live: SuiteShell's Media/ (SM-7, SM-8), which takes over
// Photo's image decoder. Foundation only for `Data`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Reads stills and movies into frames.
public protocol MediaDecoding: Sendable {
    /// The image in `data`, upright, no longer on its longest side than `longestSide` when given.
    func still(_ data: Data, longestSide: Int?) throws(SuiteError) -> MediaFrame
    /// The size, length, rate and tracks of the movie at `path`.
    func info(ofMovieAt path: String) async throws(SuiteError) -> MediaInfo
    /// The exact frame shown at `seconds`, shrunk to `longestSide` when given.
    func frame(ofMovieAt path: String, seconds: Double, longestSide: Int?) async throws(SuiteError) -> MediaFrame
}

/// The whole media service: `SuiteServices.media`.
public typealias MediaCoding = MediaEncoding & MediaDecoding
