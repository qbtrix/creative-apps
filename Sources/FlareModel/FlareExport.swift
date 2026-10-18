// FlareExport.swift: the export sheet's options and readouts (docs/blueprints/flare.md, sections 2 and 3.3): default
// options and the scan's warnings before Export, the option setters, and the sentences a failed run carries. The run
// itself is the kernel's `ExportRun` (FlareExport+Kernel.swift); the window runs the exporter and reports to it.
// The setters change only an editing run, through the kernel's `begin` (rule 20: the run is the kernel's, never
// app-local state); options are stored as given and `exportProblem` judges them, so Export is disabled with a reason.
import FlareCore

/// What the app's writer refused; the Model turns each into the sheet's sentence.
public enum ExportWriteRefusal: Error, Equatable, Sendable {
    /// "scene-1.svg is already in Exports. Choose another folder."
    case alreadyThere(name: String, folder: String)
    /// "Flare can't write to Locked."
    case cantWrite(folder: String)
}

/// A failed run's sentence, handed to the run's end so the failed state carries it: `description` is the sentence.
struct ExportRefusal: Error, CustomStringConvertible, Sendable {
    let description: String
}

extension FlareWorkspace {
    /// The sheet's starting options: the selected scene, its whole range, 1x, opaque. Nil with no scene.
    public func exportOptions(_ format: ExportFormat) -> ExportOptions? {
        selectedScene.map { ExportOptions(format: format, sceneID: $0.id, frames: 0...max($0.durationFrames - 1, 0)) }
    }

    /// What this export can't write, listed before Export; empty with no document.
    public func exportWarnings(_ options: ExportOptions) -> [String] {
        document.map { services.export.warnings($0, options: options) } ?? []
    }

    /// Nil when Export can start; otherwise why not, in the sheet's words: no document, a scene that's gone, frames
    /// outside the scene, a step under 1, a scale other than 1x or 2x (in that order). Nil while idle with a document.
    public var exportProblem: String? {
        guard document != nil else { return "Open or create an animation first." }
        guard let o = exportingOptions else { return nil }
        guard let scene = scenes.first(where: { $0.id == o.sceneID }) else { return "The scene to export is gone." }
        if o.frames.lowerBound < 0 || o.frames.upperBound >= scene.durationFrames {
            return Self.exportMessage(PNGExportError.frameOutOfRange(o.frames))
        }
        if o.step < 1 { return Self.exportMessage(PNGExportError.invalidStep(o.step)) }
        if o.scale != 1, o.scale != 2 { return "Scale must be 1x or 2x." }
        return nil
    }

    /// How many files Export writes: 1 for SVG and Lottie, the plan's count for PNG, 0 while idle or with a problem.
    public var exportFileCount: Int {
        guard exportProblem == nil, let o = exportingOptions else { return 0 }
        switch o.format {
        case .svgFrame, .lottie: return 1
        case .pngSequence:
            guard let scene = scenes.first(where: { $0.id == o.sceneID }) else { return 0 }
            return (try? PNGExportPlan.plan(scene: scene, frames: o.frames, scale: o.scale, step: o.step))?.count ?? 0
        }
    }

    /// The finished run's line ("Exported scene-1.svg." or "Exported 7 files."); nil otherwise.
    public var exportSummary: String? {
        guard case .finished(_, let names) = exportState else { return nil }
        if names.count == 1, let only = names.first { return "Exported \(only)." }
        return "Exported \(names.count) files."
    }

    /// The editing run's format, keeping the other options.
    public mutating func setExportFormat(_ format: ExportFormat) { editExport { $0.format = format } }

    /// The editing run's frames, stored as given and judged by `exportProblem`.
    public mutating func setExportFrames(_ frames: ClosedRange<Int>) { editExport { $0.frames = frames } }

    /// The editing run's PNG frame step, stored as given and judged by `exportProblem`.
    public mutating func setExportStep(_ step: Int) { editExport { $0.step = step } }

    /// The editing run's scale, stored as given; `exportProblem` accepts 1x or 2x.
    public mutating func setExportScale(_ scale: Double) { editExport { $0.scale = scale } }

    /// Whether the editing run drops the background.
    public mutating func setExportTransparent(_ on: Bool) { editExport { $0.transparentBackground = on } }

    /// Changes the editing run's options through the kernel's `begin`; every other state stays.
    private mutating func editExport(_ change: (inout ExportOptions) -> Void) {
        guard case .editing(var o) = exportState else { return }
        change(&o)
        _ = exportState.begin(o)
    }

    /// A failed export as a sentence for the sheet's error row.
    static func exportMessage(_ error: any Error) -> String {
        switch error {
        case let e as NotBuilt: e.reason
        case ExportWriteRefusal.alreadyThere(let name, let folder): "\(name) is already in \(folder). Choose another folder."
        case ExportWriteRefusal.cantWrite(let folder): "Flare can't write to \(folder)."
        case CommandError.sceneNotFound: "The scene to export is gone."
        case PNGExportError.frameOutOfRange(let r): "Frames \(r.lowerBound)–\(r.upperBound) aren't all in the scene."
        case PNGExportError.invalidStep: "The frame step must be 1 or more."
        case PNGExportError.invalidScale, PNGExportError.invalidSize: "That scale makes frames too small or too large to write."
        default: "The export couldn't be written."
        }
    }
}
