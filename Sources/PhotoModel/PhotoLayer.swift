// PhotoLayer.swift: one layer in Photo's layer stack: its name, whether it
// shows, its opacity (0...1), how it blends with the layers under it, and
// where its pixels sit on the canvas (a whole-pixel offset, so moving is
// non-destructive). `blendMode` is CoreRaster's BlendMode, never a mirror of
// it. The pixels themselves live in PhotoWorkspace.pixels under the layer's
// id, so a layer stays a small Hashable value. A layer is pixels or an
// adjustment applied to the layers below (`kind`, PV-6), and may have a mask
// in PhotoWorkspace.masks (`hasMask`, PV-5). Linux-safe.
import CoreRaster

public struct PhotoLayer: Identifiable, Sendable, Hashable {
    public let id: String
    public internal(set) var name: String
    public internal(set) var isVisible: Bool
    /// 0 (transparent) to 1 (opaque). PhotoWorkspace clamps every change.
    public internal(set) var opacity: Double
    public internal(set) var blendMode: BlendMode
    /// Where the layer's top-left pixel sits on the canvas.
    public internal(set) var offsetX = 0
    public internal(set) var offsetY = 0
    /// Pixels, or an adjustment applied to the layers below (PV-6).
    public internal(set) var kind = PhotoLayerKind.pixels
    /// Whether the layer has a mask in `PhotoWorkspace.masks` (PV-5).
    public internal(set) var hasMask = false
    /// A disabled mask is kept but not applied (Shift-click its badge).
    public internal(set) var isMaskEnabled = true

    /// Clamps `opacity` to 0...1; a NaN opacity falls back to 1, the default.
    public init(id: String, name: String, isVisible: Bool = true, opacity: Double = 1, blendMode: BlendMode = .normal) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.opacity = opacity.isNaN ? 1 : min(max(opacity, 0), 1)
        self.blendMode = blendMode
    }

    /// Opacity as the inspector shows it, 0 to 100.
    public var opacityPercent: Double { opacity * 100 }
}

/// What a layer holds.
public enum PhotoLayerKind: Hashable, Sendable {
    case pixels
    case adjustment(AdjustmentSettings)
}

extension BlendMode {
    /// The mode's name as menus show it: "colorDodge" reads "Color Dodge".
    public var title: String {
        var words = ""
        for character in rawValue {
            if character.isUppercase { words.append(" ") }
            words.append(character)
        }
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
