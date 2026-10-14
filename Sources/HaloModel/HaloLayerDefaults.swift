// HaloLayerDefaults.swift (W0): a layer's own box and the value each
// property has with no track, shared by the fakes and the live types so
// they agree. The defaults put the anchor and the position at the box's
// center, so an unkeyed layer's world matrix is the identity. Linux-safe.

extension HaloLayer {
    /// The layer's box in layer space (composition pixels, top-left origin).
    /// A text layer's box is its measured line box (`HaloTextContent.width`
    /// and `height`), centered.
    public func bounds(in composition: HaloComposition) -> HaloLayerRect {
        let w = Double(composition.width), h = Double(composition.height)
        switch kind {
        case .solid: return rect ?? HaloLayerRect(x: 0, y: 0, width: w, height: h)
        case .shape: return rect ?? HaloLayerRect(x: w / 2 - 100, y: h / 2 - 100, width: 200, height: 200)
        case .text:
            let content = text ?? HaloTextContent()
            return HaloLayerRect(
                x: w / 2 - content.width / 2, y: h / 2 - content.height / 2, width: content.width, height: content.height)
        case .null: return HaloLayerRect(x: w / 2, y: h / 2, width: 0, height: 0)
        }
    }

    /// The value `property` has when the layer has no track for it.
    public func defaultValue(_ property: HaloProperty, in composition: HaloComposition) -> Double {
        let box = bounds(in: composition)
        switch property {
        case .x, .anchorX: return box.x + box.width / 2
        case .y, .anchorY: return box.y + box.height / 2
        case .scaleX, .scaleY: return 1
        case .rotation: return 0
        case .opacity: return opacity
        }
    }
}
