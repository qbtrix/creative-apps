// DesignExportSheet+Kernel.swift: what File > Export…'s sheet reads (design-export DE-6):
// the scope chips' titles, the options it opens with (Selection falls back to Frame when nothing
// exportable is selected), a whole 1x to 3x scale (PNG only; `scaleHelp` says why it's off), the run's options until idle, and the file
// list: the plan's files, then (Selection) each hidden selected layer, skipped. Linux-safe.
import SuiteKernel

/// One line of the sheet's file list: a planned file, or a selected layer the run skips.
public struct DesignExportRow: Hashable, Sendable, Identifiable {
    /// The layer's id (the page's id for the page).
    public var id: String
    public var text: String
    /// Why the run leaves this layer out; nil for a file it writes.
    public var skipped: String?

    public init(id: String, text: String, skipped: String?) {
        (self.id, self.text, self.skipped) = (id, text, skipped)
    }
}

extension DesignExportScope {
    /// The chip's title.
    public var title: String {
        switch self {
        case .selection: "Selection"
        case .frame: "Frame"
        case .page: "Page"
        }
    }
}

extension DesignExportOptions {
    /// These options at `value` rounded to a whole 1...3; a non-finite value keeps the scale.
    public func scaled(_ value: Double) -> DesignExportOptions {
        guard value.isFinite else { return self }
        var options = self
        options.scale = Int(Swift.min(Swift.max(value.rounded(), 1), 3))
        return options
    }

    /// Why the Scale chips are off: SVG and PDF are vectors, written at 1x whatever the scale.
    public var scaleHelp: String? {
        format == .png ? nil : "SVG and PDF are vectors, so they don't take a scale."
    }
}

extension ExportRun where Options == DesignExportOptions {
    /// The options the sheet shows: the run's in every state but idle.
    public var shownOptions: DesignExportOptions? {
        switch self {
        case .idle: nil
        case .editing(let options), .running(let options, _, _), .finished(let options, _), .failed(let options, _): options
        }
    }
}

extension DesignWorkspace {
    /// The options the sheet opens with: `exportDefaults`, with Selection read as Frame when
    /// nothing exportable is selected.
    public var exportSheetDefaults: DesignExportOptions {
        var options = exportDefaults
        if options.scope == .selection, exportTargetIDs(.selection).isEmpty { options.scope = .frame }
        return options
    }

    /// The sheet's file list for `options`: the plan's files, then (Selection only) each selected
    /// layer hidden in the tree, skipped. Empty when the plan is refused.
    public func exportRows(_ options: DesignExportOptions) -> [DesignExportRow] {
        guard let plan = try? exportPlan(options, existing: []) else { return [] }
        let files = plan.map { item in
            let size = "\(Self.whole(item.width)) × \(Self.whole(item.height))"
            let text = options.format == .png
                ? "\(item.fileName) \(size), \(exportFactor(options.format, options.scale))x, \(item.pixelWidth) × \(item.pixelHeight) px"
                : "\(item.fileName) \(size) pt"
            return DesignExportRow(id: item.nodeID, text: text, skipped: nil)
        }
        guard options.scope == .selection, let page = selectedPage else { return files }
        let hidden = selectedNodeIDs.filter { isHiddenInTree($0) }.compactMap { id in
            page.nodes.node(id).map { DesignExportRow(id: id, text: $0.name, skipped: "Hidden layers aren't exported") }
        }
        return files + hidden
    }

    /// A side in whole points; a non-finite one reads 0.
    private static func whole(_ value: Double) -> Int {
        value.isFinite ? Int(Swift.max(Swift.min(value, 1e9), -1e9).rounded()) : 0
    }
}
