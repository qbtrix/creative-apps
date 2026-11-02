// ExportContracts.swift: export options, results and the frame rasterizer (docs/blueprints/flare.md, 6.2).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel
import SuiteModel

/// mp4 and gif are export-pack's (FV-1), planned by FV-3 (`FlareVideoPlan`) and written by FV-4's `writeVideo`.
public enum ExportFormat: String, CaseIterable, Hashable, Sendable { case svgFrame, lottie, pngSequence, mp4, gif }

public struct ExportOptions: Hashable, Sendable {
    public var format: ExportFormat
    public var sceneID: String
    public var frames: ClosedRange<Int>          // svgFrame uses lowerBound
    public var step: Int
    public var scale: Double                     // 1 or 2
    public var transparentBackground: Bool
    public var size: SuiteExportSize             // mp4 and gif: the shared Size row
    public var fps: Int?                         // mp4 and gif: nil is the scene's rate
    public var loop: Bool                        // gif only: forever by default
    public init(format: ExportFormat, sceneID: String, frames: ClosedRange<Int>, step: Int = 1,
                scale: Double = 1, transparentBackground: Bool = false,
                size: SuiteExportSize = .scale(1), fps: Int? = nil, loop: Bool = true) {
        self.format = format; self.sceneID = sceneID; self.frames = frames; self.step = step
        self.scale = scale; self.transparentBackground = transparentBackground
        self.size = size; self.fps = fps; self.loop = loop
    }
}

public struct ExportFile: Equatable, Sendable {
    public var name: String
    public var data: Data
    public init(name: String, data: Data) { self.name = name; self.data = data }
}
public struct ExportResult: Equatable, Sendable {
    public var files: [ExportFile]
    public var warnings: [String]                // "Text isn't exported yet (1 layer)."
    public init(files: [ExportFile], warnings: [String]) { self.files = files; self.warnings = warnings }
}

/// Implemented in FlareApp with CoreGraphics; the fake returns a fixed tiny PNG.
public protocol FrameRasterizing: Sendable {
    func png(_ list: StageDrawList, scale: Double, transparent: Bool) throws -> Data
    /// `list` drawn to fill exactly `width` × `height` pixels, for a movie or GIF frame (export-pack FV-4).
    func frame(_ list: StageDrawList, width: Int, height: Int, transparent: Bool) throws -> MediaFrame
}

extension FrameRasterizing {
    /// For a rasterizer that draws no movie frames (StageRasterizer draws them since export-pack's FV-7).
    public func frame(_: StageDrawList, width _: Int, height _: Int, transparent _: Bool) throws -> MediaFrame {
        throw NotBuilt(reason: "This rasterizer can't draw movie frames yet.")
    }
}

public protocol Exporting: Sendable {
    /// The warnings this export will carry, from a scan of the document (shown before Export).
    func warnings(_ document: Document, options: ExportOptions) -> [String]
    /// Checks `Task.isCancelled` between frames and throws `CancellationError`, writing nothing.
    func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                progress: @Sendable (Double) -> Void) async throws -> ExportResult
    /// MP4 or GIF (export-pack FV-4): `plan`'s frames of `sceneID`, each rasterized at the plan's size and appended in
    /// order to the one sink `media` opens at `path`, then finished; returns `path`. A cancel or a failure cancels the
    /// sink (which deletes the partial file) and throws, so no file comes back.
    func writeVideo(_ document: Document, sceneID: String, plan: FlareVideoPlan, to path: String,
                    media: any MediaEncoding, rasterizer: any FrameRasterizing,
                    progress: @Sendable (Double) -> Void) async throws -> String
    /// Why this exporter can't write MP4 or GIF yet; nil once it can. `exportProblem` refuses Export with it.
    var videoUnbuiltReason: String? { get }
}

extension Exporting {
    public var videoUnbuiltReason: String? { nil }
}
