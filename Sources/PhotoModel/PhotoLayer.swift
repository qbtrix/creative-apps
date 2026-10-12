// PhotoLayer.swift: one layer in Photo's layer stack: its name, whether it
// shows, its opacity (0...1) and how it blends with the layers under it.
// `blendMode` is CoreRaster's BlendMode, never a mirror of it. Layers hold no
// pixels yet; the canvas is still PhotoWorkspace's one PixelBuffer. Linux-safe.
import CoreRaster

public struct PhotoLayer: Identifiable, Sendable, Hashable {
    public let id: String
    public internal(set) var name: String
    public internal(set) var isVisible: Bool
    /// 0 (transparent) to 1 (opaque). PhotoWorkspace clamps every change.
    public internal(set) var opacity: Double
    public internal(set) var blendMode: BlendMode

    public init(id: String, name: String, isVisible: Bool = true, opacity: Double = 1, blendMode: BlendMode = .normal) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
    }

    /// Opacity as the inspector shows it, 0 to 100.
    public var opacityPercent: Double { opacity * 100 }
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
