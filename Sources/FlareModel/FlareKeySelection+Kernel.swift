// FlareKeySelection+Kernel.swift: Select All Keys (key-select-all KS-1). The pick runs on SuiteKernel's `Selection`:
// it starts from `selectedKeys`, takes every summary key (property nil) of the edited owner's layers, hidden and
// locked ones too, and writes `ordered` back, so `selectedKeys` stays the store the timeline reads. The edited owner
// is the symbol being edited in place, else the selected scene. A pick is never an edit: no undo step. Linux-safe.
import FlareCore
import SuiteKernel

extension FlareWorkspace {
    /// What Select All Keys says when the edited owner has no keys.
    public static let noKeysToSelect = "There are no keys to select."

    /// Why Select All Keys can't act now: no document, or no key on any layer of the edited owner; nil when it can.
    public var selectAllKeysHelp: String? {
        guard document != nil, propertyOwner != nil else { return FlareLayerError.noDocument.message }
        return everySummaryKey.isEmpty ? Self.noKeysToSelect : nil
    }

    /// Picks every summary key of every layer of the edited owner, in the timeline's row and frame order.
    public mutating func selectAllKeys() {
        if let help = selectAllKeysHelp { return timelineError = help }
        var selection = SuiteKernel.Selection(selectedKeys)
        selection.selectAll(everySummaryKey)
        selectedKeys = selection.ordered
        timelineError = nil
    }

    /// The edited owner's summary keys: each layer's row, in the owner's order, then its key frames.
    private var everySummaryKey: [KeyRef] {
        guard let document, let owner = propertyOwner else { return [] }
        let rows = services.keyframes.rows(document, owner: owner)
        return rows.flatMap { row in row.keyFrames.map { KeyRef(layerID: row.layerID, property: nil, frame: $0) } }
    }
}
