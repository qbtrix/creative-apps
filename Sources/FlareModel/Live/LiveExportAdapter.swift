// LiveExportAdapter.swift: the live `Exporting` (docs/blueprints/flare/features/flare-export.md, FX-6): FlareCore's
// exporters over any `StageRendering`, on a copy of the document without text (the exporters throw on it), every
// result carrying `ExportScan`'s warnings. SVG writes the range's first frame (a transparent export clears the
// background's alpha), Lottie the scene, PNG each `PNGExportPlan` frame from `stage` through the rasterizer, with a
// `frameDelay` pause after each so Cancel is reachable; a cancel throws between frames, so no files come back.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

public struct LiveExportAdapter: Exporting {
    /// The stage whose draw lists the PNG frames rasterize.
    public var stage: any StageRendering
    /// The pause after each PNG frame; `.zero` runs straight through.
    public var frameDelay: Duration

    public init(stage: any StageRendering, frameDelay: Duration = .zero) {
        self.stage = stage; self.frameDelay = frameDelay
    }

    public func warnings(_ document: Document, options: ExportOptions) -> [String] {
        ExportScan.warnings(document, options: options)
    }

    public func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                       progress: @Sendable (Double) -> Void) async throws -> ExportResult {
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
                let list = stage.drawList(clean, sceneID: scene.id, frame: frame.frame, editing: nil)
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
