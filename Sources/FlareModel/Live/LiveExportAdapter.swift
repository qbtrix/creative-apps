// LiveExportAdapter.swift: the live `Exporting` (docs/blueprints/flare/features/flare-export.md, FX-6): FlareCore's
// exporters over any `StageRendering`, on a copy of the document without text (the exporters throw on it), every
// result carrying `ExportScan`'s warnings. SVG writes the range's first frame (a transparent export clears the
// background's alpha), Lottie the scene, PNG each `PNGExportPlan` frame from `stage` through the rasterizer, with a
// `frameDelay` pause after each so Cancel is reachable; a cancel throws between frames, so no files come back.
// MP4 and GIF (export-pack FV-4) don't come back as data: `writeVideo` streams each `FlareVideoPlan` frame of the
// plan's scene into the shell-media sink (rule 20: the writers are SuiteModel's), finishes it last, and cancels it,
// deleting the partial file, on a cancel or a failure.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel
import SuiteModel

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
        case .mp4, .gif:
            throw ExportOptionRefusal.invalid("MP4 and GIF write their file through writeVideo.")
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

    public func writeVideo(_ document: Document, sceneID: String, plan: FlareVideoPlan, to path: String,
                           media: any MediaEncoding, rasterizer: any FrameRasterizing,
                           progress: @Sendable (Double) -> Void) async throws -> String {
        var clean = ExportScan.withoutText(document)
        guard let at = clean.scenes.firstIndex(where: { $0.id == sceneID }) else { throw CommandError.sceneNotFound(sceneID) }
        clean.scenes[at] = plan.scene(clean.scenes[at])
        let sink: any FrameSink
        if let movie = plan.movie { sink = try media.movie(at: path, movie) }
        else if let image = plan.animatedImage { sink = try media.animatedImage(at: path, image) }
        else { throw ExportOptionRefusal.invalid("Only MP4 and GIF write frames.") }
        do {
            for frame in plan.frames {
                try Task.checkCancellation()
                let list = stage.drawList(clean, sceneID: sceneID, frame: Int(frame.sceneFrame.rounded(.down)), editing: nil)
                try sink.append(rasterizer.frame(list, width: plan.width, height: plan.height, transparent: !plan.fillsBackground))
                progress(Double(frame.index + 1) / Double(max(plan.frames.count, 1)))
                if frameDelay > .zero { try await Task.sleep(for: frameDelay) }
            }
            try Task.checkCancellation()
            try await sink.finish()
        } catch {
            sink.cancel()
            throw error
        }
        return path
    }
}
