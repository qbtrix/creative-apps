// HaloViewerState.swift: what the viewer and the selected layer's header
// show, as Model values: the draw list at the playhead (with a viewer drag's
// preview offset), the artboard's text value ("Frame 30: Background, Badge,
// Title: Hello Halo") and the layer header (name, kind, frames, parent).
// Linux-safe: no UI imports. Drawing never fails; on `.live` the W0 stub draws
// nothing and the summary still lists the layers.

/// The selected layer's header in the inspector.
public struct HaloLayerHeader: Sendable, Hashable {
    /// The layer's name ("Title").
    public let name: String
    /// The layer's kind as menus show it ("Text").
    public let kind: String
    /// The frames the layer shows, both ends included ("Frames 24–71"); the
    /// out point is exclusive, so this ends one frame before it.
    public let frames: String
    /// The name of the layer it follows; nil for none.
    public let parent: String?

    public init(name: String, kind: String, frames: String, parent: String?) {
        self.name = name; self.kind = kind; self.frames = frames; self.parent = parent
    }
}

extension HaloProject {
    /// The selected composition drawn at its playhead by `services.drawing`,
    /// the dragged layer moved by `viewerDrag`'s delta; nil with no composition.
    public var viewerDrawList: HaloDrawList? {
        guard let comp = selectedComposition else { return nil }
        let list = services.drawing.drawList(comp, at: comp.playheadFrame)
        guard let drag = viewerDrag else { return list }
        return list.offsetting(drag.layerID, by: drag.delta)
    }

    /// The artboard's value: the frame, then the layers showing there, bottom
    /// first by name, a text layer as "<name>: <string>". Nulls and layers out
    /// of their span are left out; nothing showing reads "no layers".
    public var viewerSummary: String {
        guard let comp = selectedComposition else { return "No composition" }
        let frame = comp.playheadFrame
        let names = comp.layers.reversed()
            .filter { $0.kind != .null && $0.isVisible(at: frame) }
            .map { $0.kind == .text ? "\($0.name): \($0.text?.string ?? "Text")" : $0.name }
        return "Frame \(frame): " + (names.isEmpty ? "no layers" : names.joined(separator: ", "))
    }

    /// The selected layer's header; nil with no layer selected.
    public var selectedLayerHeader: HaloLayerHeader? {
        guard let layer = selectedLayer else { return nil }
        let last = max(layer.inFrame, layer.outFrame - 1)
        let parent = layer.parentID.flatMap { id in selectedComposition?.layers.first { $0.id == id }?.name }
        return HaloLayerHeader(
            name: layer.name, kind: layer.kind.title, frames: "Frames \(layer.inFrame)–\(last)", parent: parent)
    }
}
