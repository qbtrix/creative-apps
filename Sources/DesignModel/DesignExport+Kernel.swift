// DesignExport+Kernel.swift: Design's half of File > Export, the adapter onto the
// shared export run (SuiteKernel's ExportRun; the run, the sheet and the unique
// name rule are not Design's). The scope and options the sheet edits, the live
// export slot (LiveExport: the plan and the SVG text; `.fake` uses the same type,
// since planning is pure), and the workspace readouts the sheet and the run read:
// the ids a scope names, the plan, its help, the SVG of one item, and the
// remembered options. Those options are not document state: remembering them
// is never a history step and undo never touches them. Linux-safe.

/// What one export writes: the selected layers, the frame around them, or the page.
public enum DesignExportScope: String, CaseIterable, Hashable, Sendable { case selection, frame, page }

/// The run's payload: format, scale (1, 2, 3; PNG only) and scope.
public struct DesignExportOptions: Hashable, Sendable {
    public var format: DesignExportFormat = .png
    public var scale: Int = 1
    public var scope: DesignExportScope = .frame

    public init(format: DesignExportFormat = .png, scale: Int = 1, scope: DesignExportScope = .frame) {
        (self.format, self.scale, self.scope) = (format, scale, scope)
    }
}

// DesignExportRun: DE-2b, once SuiteKernel is linked.

/// The live export slot: the plan and the SVG text. `.fake` uses the same type (planning is pure;
/// what differs on the fakes is that the App writes nothing).
public struct LiveExport: ExportPlanning {
    public init() {}

    /// nil when `plan` at PNG 1x succeeds, else the refusal's help.
    public func exportHelp(_ ids: [String], on page: DesignPage) -> String? {
        do { _ = try plan(ids, on: page, format: .png, scale: 1, existing: []); return nil } catch { return error.help }
    }

    public func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
                     existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem] {
        // DE-3: names through UniqueFileNames against existing, hidden layers dropped, scale clamped 1...3.
        let nodes = ids.isEmpty ? page.nodes.filter { $0.kind == .frame } : fakeFind(ids, page)
        guard !nodes.isEmpty else { throw ids.isEmpty ? .nothingToExport : .nothingSelected }
        return nodes.map { exportItem($0.id, $0.name, $0.frame.width, $0.frame.height, format, scale) }
    }

    public func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String {
        guard let node = page.nodes.node(id) else { throw .unknownID(id) }
        return DesignSVG.document([node], box: node.frame, clip: node.kind == .frame)
    }
}

/// One planned file: "<name>.<format>", `width` × `height` points, and the pixels at whole points
/// times the scale (PNG only; at least 1). A non-finite side counts as 0 pixels rather than crash.
func exportItem(_ id: String, _ name: String, _ width: Double, _ height: Double,
                _ format: DesignExportFormat, _ scale: Int) -> DesignExportItem {
    let k = format == .png ? Swift.max(scale, 1) : 1
    func whole(_ value: Double) -> Int { value.isFinite ? Int(Swift.max(Swift.min(value, 1e9), -1e9).rounded()) : 0 }
    return DesignExportItem(nodeID: id, fileName: "\(name).\(format.rawValue)", width: width, height: height,
                            pixelWidth: whole(width) * k, pixelHeight: whole(height) * k)
}

extension DesignWorkspace {
    /// The ids `scope` names on the selected page: the selection; the top-level frame holding the
    /// primary selection, or every top-level frame with nothing selected (or a top-level shape
    /// selected); or `[page.id]` for the page. Hidden layers are dropped. No page: `[]`.
    public func exportTargetIDs(_ scope: DesignExportScope) -> [String] {
        guard let page = selectedPage else { return [] }
        switch scope {
        case .selection:
            return selectedNodeIDs.filter { !isHiddenInTree($0) }
        case .frame:
            // The top-level node around the primary selection: its outermost ancestor, or itself.
            let top = selectedNodeID.map { page.nodes.ancestors(of: $0)?.first ?? $0 }
            if let top, page.nodes.node(top)?.kind == .frame { return [top] }
            return page.nodes.filter { $0.kind == .frame && !$0.isHidden }.map(\.id)
        case .page:
            return [page.id]
        }
    }

    /// nil when Export can run; else the reason the sheet's Export button shows.
    public func exportHelp(_ options: DesignExportOptions) -> String? {
        do { _ = try exportPlan(options, existing: []); return nil } catch { return error.help }
    }

    /// The files one run writes, names unique against `existing` (the folder's listing). The page
    /// is one item the page's size; the other scopes go through the export slot's plan.
    public func exportPlan(_ options: DesignExportOptions, existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem] {
        guard let page = selectedPage else { throw .nothingToExport }
        if options.scope == .page {
            return [exportItem(page.id, page.name, page.frameWidth, page.frameHeight, options.format, options.scale)]
        }
        let ids = exportTargetIDs(options.scope)
        // An empty selection is its own refusal; the slot reads empty ids as "every top-level frame".
        if options.scope == .selection, ids.isEmpty { throw .nothingSelected }
        return try services.export.plan(ids, on: page, format: options.format, scale: options.scale, existing: existing)
    }

    /// The SVG document of one planned item (a layer, or the page when `item.nodeID` is the page's id).
    public func exportSVG(_ item: DesignExportItem) throws(DesignRefusal) -> String {
        guard let page = selectedPage else { throw .nothingToExport }
        if item.nodeID == page.id {
            let box = DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight)
            return DesignSVG.document(page.nodes, box: box, clip: true)
        }
        return try services.export.svg(for: item.nodeID, on: page)
    }

    /// The options the sheet opens with: the last run's, else PNG 1x Frame.
    public var exportDefaults: DesignExportOptions { exportOptions }

    /// Keeps a run's options for the next sheet. Not a history step: the document is unchanged.
    public mutating func rememberExport(_ options: DesignExportOptions) {
        exportOptions = options
    }
}
