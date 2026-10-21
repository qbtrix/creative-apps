// FakeMedia.swift: the in-memory MediaCoding (shell-media SM-1). A finished
// movie or animated image is recorded under its path with its frames in
// order; a cancelled one is not. Stills are recorded with their format.
// Reading returns the recorded frames, or a fixture frame for a path never
// written. With `unavailable:` set, every call throws `.notAvailable(that
// sentence)`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

public final class FakeMedia: MediaCoding {
    struct Log {
        var movies: [String: [MediaFrame]] = [:]
        var settings: [String: MovieSettings] = [:]
        var stills: [(format: StillFormat, frame: MediaFrame)] = []
        var cancelled: [String] = []
    }

    private let log = Mutex(Log())
    let unavailable: String?

    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// Each finished file's frames, in the order they were appended.
    public var movies: [String: [MediaFrame]] { log.withLock { $0.movies } }
    /// Each finished movie's settings.
    public var settings: [String: MovieSettings] { log.withLock { $0.settings } }
    /// Every encoded still, in order.
    public var stills: [(format: StillFormat, frame: MediaFrame)] { log.withLock { $0.stills } }
    /// Paths whose writing was cancelled, in order.
    public var cancelled: [String] { log.withLock { $0.cancelled } }

    public var movieCodecs: [MovieCodec] { unavailable == nil ? MovieCodec.allCases : [] }

    public func movie(at path: String, _ settings: MovieSettings) throws(SuiteError) -> any FrameSink {
        if let unavailable { throw .notAvailable(unavailable) }
        return FakeFrameSink(owner: self, path: path, width: settings.width, height: settings.height, movie: settings)
    }

    public func animatedImage(at path: String, _ settings: AnimatedImageSettings) throws(SuiteError) -> any FrameSink {
        if let unavailable { throw .notAvailable(unavailable) }
        return FakeFrameSink(owner: self, path: path, width: settings.width, height: settings.height, movie: nil)
    }

    public func still(_ frame: MediaFrame, as format: StillFormat, quality: Double) throws(SuiteError) -> Data {
        if let unavailable { throw .notAvailable(unavailable) }
        log.withLock { $0.stills.append((format, frame)) }
        return Data(format.rawValue.utf8) + Data(frame.rgba)
    }

    public func still(_ data: Data, longestSide: Int?) throws(SuiteError) -> MediaFrame {
        if let unavailable { throw .notAvailable(unavailable) }
        let side = max(1, min(8, longestSide ?? 8))
        return try MediaFrame(width: side, height: side, rgba: Array(repeating: 255, count: side * side * 4))
    }

    public func info(ofMovieAt path: String) async throws(SuiteError) -> MediaInfo {
        if let unavailable { throw .notAvailable(unavailable) }
        let (frames, s) = log.withLock { ($0.movies[path], $0.settings[path]) }
        guard let frames, let first = frames.first else { throw .fileMissing(name: path) }
        let fps = s?.fps ?? 24
        return MediaInfo(width: first.width, height: first.height, seconds: Double(frames.count) / Double(fps),
                         fps: Double(fps), frameCount: frames.count, hasAlpha: s?.codec.keepsAlpha ?? true,
                         hasAudio: false, codec: s?.codec.rawValue ?? "fake")
    }

    public func frame(ofMovieAt path: String, seconds: Double, longestSide: Int?) async throws(SuiteError) -> MediaFrame {
        let info = try await info(ofMovieAt: path)
        let frames = log.withLock { $0.movies[path] ?? [] }
        let index = min(max(0, Int((seconds * info.fps).rounded())), frames.count - 1)
        guard frames.indices.contains(index) else { throw .fileMissing(name: path) }
        return frames[index]
    }

    func record(_ path: String, frames: [MediaFrame], settings: MovieSettings?) {
        log.withLock {
            $0.movies[path] = frames
            $0.settings[path] = settings
        }
    }

    func recordCancel(_ path: String) { log.withLock { $0.cancelled.append(path) } }
}

/// A fake file being written: keeps its frames until `finish` records them.
final class FakeFrameSink: FrameSink {
    let owner: FakeMedia, path: String, width: Int, height: Int, movie: MovieSettings?
    private let frames = Mutex([MediaFrame]())

    init(owner: FakeMedia, path: String, width: Int, height: Int, movie: MovieSettings?) {
        self.owner = owner; self.path = path; self.width = width; self.height = height; self.movie = movie
    }

    func append(_ frame: MediaFrame) throws(SuiteError) {
        guard frame.width == width, frame.height == height else {
            throw .notAvailable("This file is \(width) by \(height); a \(frame.width) by \(frame.height) frame doesn't fit.")
        }
        frames.withLock { $0.append(frame) }
    }

    func finish() async throws(SuiteError) {
        let written = frames.withLock { $0 }
        owner.record(path, frames: written, settings: movie)
    }

    func cancel() {
        frames.withLock { $0.removeAll() }
        owner.recordCancel(path)
    }
}
