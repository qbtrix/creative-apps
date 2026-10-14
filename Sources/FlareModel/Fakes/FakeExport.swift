// FakeExport.swift: Exporting over FlareCore's real exporters (docs/blueprints/flare.md, 6.3), on a copy without text
// (they throw on it), every result carrying `ExportScan`'s warnings. SVG writes the range's first frame, Lottie the
// scene, PNG each `PNGExportPlan` frame from `FakeStage` through the rasterizer with a 20 ms pause so Cancel is
// reachable; a cancel throws between frames, so no files come back. `unavailable` scans nothing and throws itself.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

public struct FakeExport: Exporting {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    /// The pause after each PNG frame; `.zero` runs straight through (the budget tests).
    public var frameDelay: Duration

    public init(unavailable: String? = nil, frameDelay: Duration = .milliseconds(20)) {
        self.unavailable = unavailable; self.frameDelay = frameDelay
    }

    public func warnings(_ document: Document, options: ExportOptions) -> [String] {
        unavailable == nil ? ExportScan.warnings(document, options: options) : []
    }

    public func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                       progress: @Sendable (Double) -> Void) async throws -> ExportResult {
        if let unavailable { throw NotBuilt(reason: unavailable) }
        let clean = ExportScan.withoutText(document)
        guard var scene = clean.scenes.first(where: { $0.id == options.sceneID }) else {
            throw CommandError.sceneNotFound(options.sceneID)
        }
        var files: [ExportFile] = []
        switch options.format {
        case .svgFrame:
            if options.transparentBackground { scene.background.a = 0 }
            let svg = try SVGExporter.export(scene: scene, frame: Double(options.frames.lowerBound), symbols: clean.symbols)
            files = [ExportFile(name: "\(scene.id).svg", data: Data(svg.utf8))]
        case .lottie:
            files = [ExportFile(name: "\(scene.id).json", data: try LottieExporter.export(scene: scene, symbols: clean.symbols))]
        case .pngSequence:
            let plan = try PNGExportPlan.plan(scene: scene, frames: options.frames, scale: options.scale, step: options.step)
            for (i, frame) in plan.enumerated() {
                try Task.checkCancellation()
                let list = FakeStage().drawList(clean, sceneID: scene.id, frame: frame.frame, editing: nil)
                files.append(ExportFile(name: frame.fileName, data: try rasterizer.png(
                    list, scale: options.scale, transparent: options.transparentBackground)))
                progress(Double(i + 1) / Double(plan.count))
                if frameDelay > .zero { try await Task.sleep(for: frameDelay) }
            }
        }
        try Task.checkCancellation()
        if options.format != .pngSequence { progress(1) }
        return ExportResult(files: files, warnings: ExportScan.warnings(document, options: options))
    }
}
