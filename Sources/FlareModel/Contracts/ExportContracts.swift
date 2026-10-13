// ExportContracts.swift: export options, results and the frame rasterizer (docs/blueprints/flare.md, 6.2).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

public enum ExportFormat: String, CaseIterable, Hashable, Sendable { case svgFrame, lottie, pngSequence }

public struct ExportOptions: Hashable, Sendable {
    public var format: ExportFormat
    public var sceneID: String
    public var frames: ClosedRange<Int>          // svgFrame uses lowerBound
    public var step: Int
    public var scale: Double                     // 1 or 2
    public var transparentBackground: Bool
    public init(format: ExportFormat, sceneID: String, frames: ClosedRange<Int>, step: Int = 1,
                scale: Double = 1, transparentBackground: Bool = false) {
        self.format = format; self.sceneID = sceneID; self.frames = frames; self.step = step
        self.scale = scale; self.transparentBackground = transparentBackground
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
}

public protocol Exporting: Sendable {
    /// The warnings this export will carry, from a scan of the document (shown before Export).
    func warnings(_ document: Document, options: ExportOptions) -> [String]
    /// Checks `Task.isCancelled` between frames and throws `CancellationError`, writing nothing.
    func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                progress: @Sendable (Double) -> Void) async throws -> ExportResult
}
