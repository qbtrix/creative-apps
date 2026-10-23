// DesignOpacityKeys+Kernel.swift (brush-keys BK-10): the workspace as SuiteKernel's BrushKeyTarget, so the canvas's
// digit keys (ToolKeys.brushAction over BrushKeys' rule) and the catalog's `layer.set-opacity` set the selected
// layers' opacity the same way. Design has no brush: a digit is `.layerOpacity`, 5 is 50%, 0 is 100%, and two digits
// within OpacityDigits.window are the exact percent. A key goes through the inspector's opacity row (`setStyle`), so
// a pair's second digit joins the first's step; a digit that starts a pair ends the run first, so it is a new step.
// The catalog's run is one "Layer Opacity" step of its own. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// One opacity key: the opacity it sets (0 to 1) and whether it starts a new undo step.
public struct DesignOpacityKey: Hashable, Sendable {
    public var opacity: Double
    public var startsStep: Bool

    public init(opacity: Double, startsStep: Bool) { (self.opacity, self.startsStep) = (opacity, startsStep) }
}

extension DesignWorkspace: BrushKeyTarget {
    /// Design has no brush tool.
    public var activeBrush: BrushSettings? { nil }

    /// The inspector opacity row's reason: nothing selected, a locked layer, mid text edit.
    public var layerOpacityHelp: String? { styleHelp(.opacity) }

    /// Refuses: Design has no brush to set.
    public mutating func setActiveBrush(_ s: BrushSettings) throws {
        throw CatalogError.failed(id: "brush.set-opacity", message: BrushKeyCommands.noBrushHelp)
    }

    /// Every selected layer's opacity at `percent`, one "Layer Opacity" step that joins no other.
    public mutating func setSelectedOpacity(_ percent: Double) throws {
        let ids = selectedNodeIDs
        guard let page = selectedPage, !ids.isEmpty else { throw DesignRefusal.nothingSelected }
        guard editingTextID == nil, gesture == nil else { throw DesignRefusal.unchanged }
        var edit = try services.styling.setOpacity(Self.keyOpacity(percent), ids, on: page)
        (edit.name, edit.coalescingKey) = ("Layer Opacity", nil)
        endEditRun()
        apply(edit)
    }

    /// A percent (0 to 100) as a layer's opacity (0 to 1).
    public static func keyOpacity(_ percent: Double) -> Double {
        min(max(percent, 0), 100) / 100
    }

    /// The opacity key `action` is, `digits` being the buffer after it at `now`; nil for any other key.
    public static func opacityKey(_ action: BrushKeyAction?, after digits: OpacityDigits, at now: Double) -> DesignOpacityKey? {
        guard case .layerOpacity(let percent) = action else { return nil }
        // A buffer still open holds this key as a pair's first digit: a 0 typed now would not read 100.
        var probe = digits
        return DesignOpacityKey(opacity: keyOpacity(percent), startsStep: probe.type(0, at: now) != 100)
    }

    /// What the canvas does with `key`: ends the run when it starts a step, then sets the opacity row.
    public mutating func applyOpacityKey(_ key: DesignOpacityKey) throws(DesignRefusal) {
        if key.startsStep { endEditRun() }
        try setStyle(.opacity(key.opacity))
    }
}
