// FakeExport.swift: the fakes' `Exporting` (docs/blueprints/flare.md, 6.3; flare-export FX-8): `LiveExportAdapter`
// over `FakeStage`, so the SVG and Lottie bytes are FlareCore's real exports and each PNG frame comes from the fake
// stage through the rasterizer, with a 20 ms pause after it by default so Cancel is reachable. `unavailable` scans
// nothing and throws itself. MP4 and GIF stream into whatever `MediaEncoding` the caller hands in; `FakeVideoMedia`
// (export-pack FV-4) logs each sink's open, appends, finish and cancel over SuiteModel's `FakeMedia`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteModel
import Synchronization

public struct FakeExport: Exporting {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    /// The pause after each PNG frame; `.zero` runs straight through (the budget tests).
    public var frameDelay: Duration

    public init(unavailable: String? = nil, frameDelay: Duration = .milliseconds(20)) {
        self.unavailable = unavailable; self.frameDelay = frameDelay
    }

    private var adapter: LiveExportAdapter { LiveExportAdapter(stage: FakeStage(), frameDelay: frameDelay) }

    public func warnings(_ document: Document, options: ExportOptions) -> [String] {
        unavailable == nil ? adapter.warnings(document, options: options) : []
    }

    public func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                       progress: @Sendable (Double) -> Void) async throws -> ExportResult {
        if let unavailable { throw NotBuilt(reason: unavailable) }
        return try await adapter.export(document, options: options, rasterizer: rasterizer, progress: progress)
    }

    public func writeVideo(_ document: Document, sceneID: String, plan: FlareVideoPlan, to path: String,
                           media: any MediaEncoding, rasterizer: any FrameRasterizing,
                           progress: @Sendable (Double) -> Void) async throws -> String {
        if let unavailable { throw NotBuilt(reason: unavailable) }
        return try await adapter.writeVideo(document, sceneID: sceneID, plan: plan, to: path, media: media,
                                            rasterizer: rasterizer, progress: progress)
    }
}

/// One call a `FakeVideoMedia` sink took, in the order it came.
public enum FakeSinkEvent: Equatable, Sendable { case open(String), append(MediaFrame), finish, cancel }

/// `FakeMedia` with a log of every sink call; FakeMedia itself keeps the finished files and the cancelled paths.
public final class FakeVideoMedia: MediaEncoding {
    public let media: FakeMedia
    private let log = Mutex<[FakeSinkEvent]>([])

    public init(media: FakeMedia = FakeMedia()) { self.media = media }

    /// Every sink call so far, oldest first; an append is logged once the sink took it.
    public var events: [FakeSinkEvent] { log.withLock { $0 } }
    public var movieCodecs: [MovieCodec] { media.movieCodecs }

    public func movie(at path: String, _ settings: MovieSettings) throws(SuiteError) -> any FrameSink {
        opened(path, try media.movie(at: path, settings))
    }

    public func animatedImage(at path: String, _ settings: AnimatedImageSettings) throws(SuiteError) -> any FrameSink {
        opened(path, try media.animatedImage(at: path, settings))
    }

    public func still(_ frame: MediaFrame, as format: StillFormat, quality: Double) throws(SuiteError) -> Data {
        try media.still(frame, as: format, quality: quality)
    }

    fileprivate func note(_ event: FakeSinkEvent) { log.withLock { $0.append(event) } }

    private func opened(_ path: String, _ inner: any FrameSink) -> any FrameSink {
        note(.open(path))
        return LoggedSink(owner: self, inner: inner)
    }
}

private final class LoggedSink: FrameSink {
    let owner: FakeVideoMedia, inner: any FrameSink
    init(owner: FakeVideoMedia, inner: any FrameSink) { self.owner = owner; self.inner = inner }

    func append(_ frame: MediaFrame) throws(SuiteError) { try inner.append(frame); owner.note(.append(frame)) }
    func finish() async throws(SuiteError) { owner.note(.finish); try await inner.finish() }
    func cancel() { owner.note(.cancel); inner.cancel() }
}
