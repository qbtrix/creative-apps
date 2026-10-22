// MediaEncoding.swift: shell-media's writing half (SM-1). Frames in, movie,
// animated image or still out. Live: SuiteShell's Media/ (SM-5, SM-6), which
// takes over Halo's movie writer and Photo's image encoder. Foundation only
// for `Data`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A file being written a frame at a time.
public protocol FrameSink: AnyObject, Sendable {
    /// Adds the next frame; frames go in order, and one of another size throws.
    func append(_ frame: MediaFrame) throws(SuiteError)
    /// Closes the file once every frame is in.
    func finish() async throws(SuiteError)
    /// Stops writing and deletes the partial file.
    func cancel()
}

/// Writes movies, animated images and stills.
public protocol MediaEncoding: Sendable {
    /// The movie codecs this Mac can write.
    var movieCodecs: [MovieCodec] { get }
    func movie(at path: String, _ settings: MovieSettings) throws(SuiteError) -> any FrameSink
    func animatedImage(at path: String, _ settings: AnimatedImageSettings) throws(SuiteError) -> any FrameSink
    /// `frame` as a file in `format`; `quality` (0...1) for JPEG and HEIC.
    func still(_ frame: MediaFrame, as format: StillFormat, quality: Double) throws(SuiteError) -> Data
}
