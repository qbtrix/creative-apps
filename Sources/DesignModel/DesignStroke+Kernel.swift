// DesignStroke+Kernel.swift (stroke-style DK-1 stubs, DK-6 bodies): Design's stroke is the kernel's `VectorStroke`
// (DK-5), and the workspace is SuiteKernel's `StrokeTarget`, so the nine stroke commands (`StrokeCommands.specs`, in
// the catalog) set a stroke on every selected unlocked layer as one undo step, a scrub under one drag token as one.
// `strokeChange` turns the stroke editor's intents into the inspector's `.stroke` style change by running the same
// kernel command on a probe, so the editor and the catalog never disagree. Trim never runs in Design. Linux-safe.
import SuiteKernel

extension DesignNode {
    /// This layer's stroke as the kernel's; nil when it has none.
    public var vectorStroke: VectorStroke? { stroke }
}

/// Design's one adapter between its 0...255 colour and the kernel's 0...1 `FillColor`; the fill and the stroke
/// both go through it.
extension DesignColor {
    /// The kernel's colour as Design's, its opacity dropped; each part is `SampleRules.byte`, so out-of-range
    /// parts clamp and NaN is 0.
    public init(kernel color: FillColor) {
        func byte(_ part: Double) -> UInt8 { UInt8(clamping: SampleRules.byte(part)) }
        self.init(byte(color.r), byte(color.g), byte(color.b))
    }

    /// This opaque colour as the kernel's.
    var kernelColor: FillColor {
        FillColor(r: Double(red) / 255, g: Double(green) / 255, b: Double(blue) / 255)
    }
}

extension DesignWorkspace: StrokeTarget {
    /// Why trim never runs in Design.
    public static let trimPathsHelp = "Trim paths are for animation, in Flare and Halo."

    /// "Open a design first." with no file; else the primary layer's reason (nothing selected, editing text,
    /// locked); else "Show A to change it." for the first hidden layer a stroke would reach. Other locked layers in
    /// the selection don't refuse: both edit paths skip them (`strokeIDs`).
    public var strokeHelp: String? {
        guard isOpen else { return "Open a design first." }
        guard let node = selectedNode, editingTextID == nil else { return styleHelp(.stroke) }
        if let why = lockHelp(node.id) { return why }
        guard let hidden = strokeIDs.first(where: isHiddenInTree) else { return nil }
        return DesignRefusal.hidden(findNode(hidden)?.name ?? hidden).help
    }

    /// The selected layers a stroke edit sets, from the catalog or the inspector: every one not locked in the tree.
    var strokeIDs: [String] { selectedNodeIDs.filter { !isLockedInTree($0) } }

    /// The inspector's stroke edit (`setStyle(.stroke)`) on `strokeIDs`, so it skips a locked layer as `setStroke`
    /// does; the selection stays whole. With none to set, the whole selection, so the refusal names the lock.
    func strokeEdit(_ stroke: DesignStroke?, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let ids = strokeIDs.isEmpty ? selectedNodeIDs : strokeIDs
        var edit = try services.styling.setStroke(stroke, ids, on: page)
        edit.selection = selectedNodeIDs
        return edit
    }

    public var trimHelp: String? { Self.trimPathsHelp }

    /// The primary selected layer's stroke.
    public var selectedStroke: VectorStroke? { selectedNode?.vectorStroke }

    /// Nil: every Dash chip runs `stroke.dash`.
    public var strokeDashHelp: String? { nil }

    /// Nil: every Join and Cap chip runs its command.
    public var strokeStyleHelp: String? { nil }

    /// Sets (nil removes) the stroke of every selected unlocked layer as one step named `name`; steps under one
    /// `drag` on the same layers fold into one. A stroke that changes nothing refuses with `.unchanged`,
    /// except a drag's sample, which is a quiet no-op.
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        if let why = strokeHelp { throw CatalogError.failed(id: "stroke", message: why) }
        guard gesture == nil else { throw CatalogError.failed(id: "stroke", message: "Finish the drag first.") }
        let ids = strokeIDs
        let before = snapshot
        for id in ids { _ = pages.update(id) { $0.stroke = stroke } }
        guard snapshot != before else { if drag != nil { return }; throw DesignRefusal.unchanged }
        record(name, before: before, coalescing: drag.map { DesignEdit.runKey("stroke-" + $0, ids) })
    }

    /// The editor's `intent` as the inspector's style change on the selection, and whether it is a scrub's sample
    /// (preview it, land it at the end) rather than a whole edit: the intent's kernel command run on a probe of the
    /// primary stroke. Nil when the command refuses (no stroke to change, trim).
    public func strokeChange(_ intent: StrokeIntent) -> (change: DesignStyleChange, scrub: Bool)? {
        var probe = StrokeProbe(strokeHelp: strokeHelp, trimHelp: trimHelp, selectedStroke: selectedStroke)
        let clamped = if case .width(let width, let drag) = intent { StrokeIntent.width(StrokeRules.clampedWidth(width), drag: drag) } else { intent }
        let (id, params) = clamped.command
        guard (try? StrokeProbe.catalog.run(id, params: params, on: &probe)) != nil, let set = probe.set else { return nil }
        switch intent {
        case .color(_, let drag), .width(_, let drag): return (.stroke(set), drag != nil)
        default: return (.stroke(set), false)
        }
    }
}

/// A stand-in `StrokeTarget` that keeps the stroke a command sets, so `strokeChange` reads what the kernel would do.
private struct StrokeProbe: StrokeTarget {
    var strokeHelp: String?, trimHelp: String?, selectedStroke: VectorStroke?
    /// The stroke the command set; nil until one ran.
    var set: VectorStroke??

    mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws { set = .some(stroke) }

    static let catalog = (try? CommandCatalog(app: "design-stroke", StrokeCommands.specs(StrokeProbe.self),
                                              history: { _ in History<Int>() })) ?? .empty(app: "design-stroke")
}
