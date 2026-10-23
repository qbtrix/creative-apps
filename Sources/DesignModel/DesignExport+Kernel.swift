// DesignExport+Kernel.swift: Design's half of File > Export, the adapter onto the
// shared export run (SuiteKernel's ExportRun; the run, the sheet and the unique
// name rule are not Design's). The scope and options the sheet edits, the live
// export slot (LiveExport: the plan and the SVG text; `.fake` uses the same type,
// since planning is pure), and the workspace readouts the sheet and the run read:
// the ids a scope names, the plan, its help, the SVG of one item, and the
// remembered options. The options hold a SuiteExportSize; the plan sizes every still
// file to its exact pixels through the kernel's ExportRules (vectors take a scale only),
// and a format without alpha (JPEG) flattens onto the frame's fill, white with no frame.
// Those options are not document state: remembering
// them is never a history step and undo never touches them. Linux-safe.
import SuiteKernel
import SuiteModel

/// What one export writes: the selected layers, the frame around them, or the page.
public enum DesignExportScope: String, CaseIterable, Hashable, Sendable { case selection, frame, page }

/// The run's payload: format, size (the suite's SuiteExportSize, `.scale(1)` by default) and scope.
/// A scale is whole and clamped to 1...3 for PNG and JPEG; Pixels and Long edge are exact (`exportSized`).
public struct DesignExportOptions: Hashable, Sendable {
    public var format: DesignExportFormat = .png
    public var size: SuiteExportSize = .scale(1)
    public var scope: DesignExportScope = .frame

    public init(format: DesignExportFormat = .png, size: SuiteExportSize, scope: DesignExportScope = .frame) {
        (self.format, self.size, self.scope) = (format, size, scope)
    }

    /// The old whole-scale init: `size` is `.scale(Double(scale))`.
    public init(format: DesignExportFormat = .png, scale: Int = 1, scope: DesignExportScope = .frame) {
        self.init(format: format, size: .scale(Double(scale)), scope: scope)
    }

    /// The size as a whole scale: a `.scale` rounded (non-finite reads 1), 1 for Pixels and Long
    /// edge. Setting it makes the size `.scale`.
    public var scale: Int {
        get {
            guard case .scale(let value) = size, value.isFinite else { return 1 }
            return Int(Swift.max(Swift.min(value, 1e6), -1e6).rounded())
        }
        set { size = .scale(Double(newValue)) }
    }
}

extension DesignExportFormat {
    /// The kernel's spec of this format: extension, alpha, still or vector.
    var spec: ExportFormatSpec? { ExportFormats.spec(rawValue) }
    /// The file extension the export writes: "jpg" for JPEG, else the raw value.
    public var fileExtension: String { spec?.fileExtension ?? rawValue }
}

/// Design's export run is the kernel's; the sheet reads it, DesignExport+Kernel (App) drives it.
public typealias DesignExportRun = ExportRun<DesignExportOptions>

/// The live export slot: the plan and the SVG text. `.fake` uses the same type (planning is pure;
/// what differs on the fakes is that the App writes nothing).
public struct LiveExport: ExportPlanning {
    public init() {}

    /// nil when `plan` at PNG 1x succeeds, else the refusal's help.
    public func exportHelp(_ ids: [String], on page: DesignPage) -> String? {
        do { _ = try plan(ids, on: page, format: .png, scale: 1, existing: []); return nil } catch { return error.help }
    }

    /// The files for `ids` (every visible top-level frame when empty): hidden layers dropped,
    /// locked ones kept, names unique against `existing` and each other, pixels at whole points
    /// times the scale (PNG and JPEG: 1...3; SVG and PDF: 1). Nothing left: `.nothingToExport` for no
    /// ids, `.nothingSelected` for named ids that are all hidden or unknown.
    public func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
                     existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem] {
        let found = ids.isEmpty ? page.nodes.filter { $0.kind == .frame } : fakeFind(ids, page)
        let nodes = found.filter { !page.isHiddenInTree($0.id) }
        guard !nodes.isEmpty else { throw ids.isEmpty ? .nothingToExport : .nothingSelected }
        let names = UniqueFileNames.names(nodes.map(\.name), extension: format.fileExtension, among: existing)
        return zip(nodes, names).map { node, name in
            exportItem(node.id, name, node.frame.width, node.frame.height, format, scale)
        }
    }

    public func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String {
        guard let node = page.nodes.node(id) else { throw .unknownID(id) }
        return DesignSVG.document([node], box: node.frame, clip: node.kind == .frame)
    }
}

/// The pixel factor: the scale clamped to 1...3 for PNG and JPEG, 1 for SVG and PDF (vector, in points).
func exportFactor(_ format: DesignExportFormat, _ scale: Int) -> Int {
    [.png, .jpeg].contains(format) ? Swift.min(Swift.max(scale, 1), 3) : 1
}

/// A side in whole points; a non-finite side counts as 0 rather than crash.
func wholePixels(_ value: Double) -> Int { value.isFinite ? Int(Swift.max(Swift.min(value, 1e9), -1e9).rounded()) : 0 }

/// One planned file: `fileName`, `width` × `height` points, and the pixels at whole points times
/// the factor. A non-finite side counts as 0 pixels rather than crash.
func exportItem(_ id: String, _ fileName: String, _ width: Double, _ height: Double,
                _ format: DesignExportFormat, _ scale: Int) -> DesignExportItem {
    let k = exportFactor(format, scale)
    return DesignExportItem(nodeID: id, fileName: fileName, width: width, height: height,
                            pixelWidth: wholePixels(width) * k, pixelHeight: wholePixels(height) * k)
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

    /// The files one run writes, names unique against `existing` (the folder's listing), each sized
    /// by `exportSized`. The page is one item the page's size; the other scopes go through the
    /// export slot's plan.
    public func exportPlan(_ options: DesignExportOptions, existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem] {
        guard let page = selectedPage else { throw .nothingToExport }
        if options.scope == .page {
            let name = UniqueFileNames.name(page.name, extension: options.format.fileExtension, among: existing)
            return [try exportSized(exportItem(page.id, name, page.frameWidth, page.frameHeight, options.format, options.scale), options, page)]
        }
        let ids = exportTargetIDs(options.scope)
        // An empty selection is its own refusal; the slot reads empty ids as "every top-level frame".
        if options.scope == .selection, ids.isEmpty { throw .nothingSelected }
        let plan = try services.export.plan(ids, on: page, format: options.format, scale: options.scale, existing: existing)
        var sized: [DesignExportItem] = []
        for item in plan { sized.append(try exportSized(item, options, page)) }
        return sized
    }

    /// `item` at its exact pixels for `options.size`, through the kernel's ExportRules: a scale is
    /// whole and clamped (`exportFactor`), Pixels and Long edge exact, never a scale on top. SVG and
    /// PDF take a scale only (in points). A format without alpha flattens onto `exportBackground`.
    func exportSized(_ item: DesignExportItem, _ options: DesignExportOptions,
                     _ page: DesignPage) throws(DesignRefusal) -> DesignExportItem {
        guard let spec = options.format.spec, spec.kind == .still else {
            if case .scale = options.size { return item }
            throw .cantExport("SVG and PDF are vectors, so they export at their size in points. Choose a scale.")
        }
        let size: SuiteExportSize
        if case .scale = options.size { size = .scale(Double(exportFactor(options.format, options.scale))) } else { size = options.size }
        let source = (width: wholePixels(item.width), height: wholePixels(item.height))
        let kernel = SuiteExportOptions(format: spec.id, size: size, alpha: spec.keepsAlpha)
        if let why = ExportRules.refusal(kernel, source: source, formats: ExportFormats.all) { throw .cantExport(why) }
        guard let pixels = try? ExportRules.pixels(of: source, size, evenSize: spec.needsEvenSize) else { return item }
        var sized = item
        (sized.pixelWidth, sized.pixelHeight) = pixels
        sized.background = spec.keepsAlpha ? nil : exportBackground(item.nodeID, page)
        return sized
    }

    /// The color an item flattens onto: the fill of the frame it is or sits in (its outermost
    /// ancestor), white when that is no frame, has a gradient, or the item is the page.
    func exportBackground(_ id: String, _ page: DesignPage) -> DesignColor {
        let top = page.nodes.ancestors(of: id)?.first ?? id
        let frame = [id, top].lazy.compactMap { page.nodes.node($0) }.first { $0.kind == .frame }
        guard let frame, frame.gradient == nil else { return .white }
        return frame.fill
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
