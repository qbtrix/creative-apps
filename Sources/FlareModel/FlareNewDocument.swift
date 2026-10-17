// FlareNewDocument.swift: layers-files LF-3, what the New Animation sheet asks for: a preset or Custom, size, rate,
// length and background, with `problem` saying why Create can't run. `newDocument(_:)` builds through
// `services.scenes.newDocument` in a fresh engine (no undo history, not dirty) or refuses a spec with a problem. The
// spec travels as the `.file(.create)` intent's fields, the background as "#RRGGBB". Linux-safe.
import FlareCore

/// The New Animation sheet's choices.
public struct NewDocumentSpec: Sendable, Equatable {
    /// The largest canvas side the format holds, in points.
    public static let maxSide: Double = 16_384
    /// The sheet's frame rates.
    public static let frameRates = [12, 24, 25, 30, 60]
    public static let fpsRange = 1...240
    public static let durationRange = 1...100_000

    /// The preset the values came from; nil is Custom.
    public var preset: CanvasPreset?
    public var width: Double, height: Double, fps: Int, durationFrames: Int, background: FlareColor

    public init(preset: CanvasPreset) {
        self.preset = preset
        (width, height, fps, durationFrames) = (preset.width, preset.height, preset.fps, preset.durationFrames)
        background = .white
    }

    /// The spec a `.file(.create)` intent carries; nil for any other intent or a background that isn't "#RRGGBB".
    public init?(_ intent: FlareIntent.File) {
        guard case .create(let name, let width, let height, let fps, let frames, let hex) = intent,
            let background = Self.color(hex: hex)
        else { return nil }
        preset = CanvasPreset.all.first { $0.name == name }
        (self.width, self.height, self.fps, durationFrames, self.background) = (width, height, fps, frames, background)
    }

    /// Why Create can't make a document from this spec; nil when it can.
    public var problem: String? {
        let sides = 1...Self.maxSide, side = "1 to \(Int(Self.maxSide)) px."
        if !sides.contains(width) { return "Width must be \(side)" }
        if !sides.contains(height) { return "Height must be \(side)" }
        if !Self.fpsRange.contains(fps) {
            return "Frame rate must be \(Self.fpsRange.lowerBound) to \(Self.fpsRange.upperBound) fps."
        }
        if !Self.durationRange.contains(durationFrames) {
            return "Duration must be \(Self.durationRange.lowerBound) to \(Self.durationRange.upperBound) frames."
        }
        if !background.isInRange { return "Pick a valid background color." }
        return nil
    }

    /// Takes a preset's values; nil switches to Custom and keeps the values.
    public mutating func pick(_ preset: CanvasPreset?) {
        self.preset = preset
        guard let preset else { return }
        (width, height, fps, durationFrames) = (preset.width, preset.height, preset.fps, preset.durationFrames)
    }

    /// A typed size is Custom.
    public mutating func setSize(width: Double, height: Double) {
        (self.width, self.height, preset) = (width, height, nil)
    }

    /// The intent that makes this document.
    public var intent: FlareIntent.File {
        .create(preset: preset?.name, width: width, height: height, fps: fps, durationFrames: durationFrames,
                backgroundHex: Self.hex(background))
    }

    /// "#RRGGBB" for a color, channels clamped to 0...1.
    public static func hex(_ color: FlareColor) -> String {
        "#" + [color.r, color.g, color.b].map { value in
            let byte = Int((min(max(value.isFinite ? value : 0, 0), 1) * 255).rounded())
            return String(byte >> 4, radix: 16, uppercase: true) + String(byte & 15, radix: 16, uppercase: true)
        }.joined()
    }

    /// The opaque color "#RRGGBB" (or "RRGGBB") names; nil when it names none.
    public static func color(hex: String) -> FlareColor? {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = Int(digits, radix: 16) else { return nil }
        let channel = { (shift: Int) in Double(value >> shift & 0xFF) / 255 }
        return FlareColor(r: channel(16), g: channel(8), b: channel(0))
    }

    /// The canvas preset the scene service builds from.
    var canvas: CanvasPreset {
        CanvasPreset(name: preset?.name ?? "Custom", width: width, height: height, fps: fps,
                     durationFrames: durationFrames)
    }
}

extension FlareWorkspace {
    /// Replaces the open document with one scene made from `spec`, in a fresh engine (no undo history, not dirty).
    /// A spec with a problem changes nothing but `layerError`.
    public mutating func newDocument(_ spec: NewDocumentSpec) {
        if let problem = spec.problem { return refuse(.refused(problem)) }
        var document = services.scenes.newDocument(spec.canvas)
        for i in document.scenes.indices { document.scenes[i].background = spec.background }
        load(document)
    }
}
