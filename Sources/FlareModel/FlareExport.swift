// FlareExport.swift: the export sheet's options and readouts (docs/blueprints/flare.md, sections 2 and 3.3): default
// options and the scan's warnings before Export, the option setters, and the sentences a failed run carries. The run
// itself is the kernel's `ExportRun` (FlareExport+Kernel.swift); the window runs the exporter and reports to it.
// FX-2a (docs/blueprints/flare/features/flare-export.md, Contract slice) declares the sheet's readouts and option
// setters as stubs that report nothing and change nothing; FX-11 fills them without changing a signature.
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

    /// Nil when Export can start; otherwise why not, in the sheet's words. Stub (FX-11): nil.
    public var exportProblem: String? { nil }

    /// How many files Export writes: 1 for SVG and Lottie, the plan's count for PNG, 0 with a problem. Stub (FX-11): 0.
    public var exportFileCount: Int { 0 }

    /// The finished run's line ("Exported scene-1.svg." or "Exported 7 files."); nil otherwise. Stub (FX-11): nil.
    public var exportSummary: String? { nil }

    /// The editing run's format, keeping the other options. Stub (FX-11): changes nothing.
    public mutating func setExportFormat(_ format: ExportFormat) {}

    /// The editing run's frames, stored as given and judged by `exportProblem`. Stub (FX-11): changes nothing.
    public mutating func setExportFrames(_ frames: ClosedRange<Int>) {}

    /// The editing run's PNG frame step. Stub (FX-11): changes nothing.
    public mutating func setExportStep(_ step: Int) {}

    /// The editing run's scale, 1x or 2x. Stub (FX-11): changes nothing.
    public mutating func setExportScale(_ scale: Double) {}

    /// Whether the editing run drops the background. Stub (FX-11): changes nothing.
    public mutating func setExportTransparent(_ on: Bool) {}

    /// A failed export as a sentence for the sheet's error row.
    static func exportMessage(_ error: any Error) -> String {
        switch error {
        case let e as NotBuilt: e.reason
        case CommandError.sceneNotFound: "The scene to export is gone."
        case PNGExportError.frameOutOfRange(let r): "Frames \(r.lowerBound)–\(r.upperBound) aren't all in the scene."
        case PNGExportError.invalidStep: "The frame step must be 1 or more."
        case PNGExportError.invalidScale, PNGExportError.invalidSize: "That scale makes frames too small or too large to write."
        default: "The export couldn't be written."
        }
    }
}
