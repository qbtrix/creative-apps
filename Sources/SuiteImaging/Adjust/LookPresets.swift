// LookPresets.swift (adjust-everywhere AJ-2 data, AJ-6 apply): a look is a
// whole adjustment saved under a name, tone, AdjustSettings and kinds, that
// `look.apply` sets on a picture in one step. BuiltInLooks are the six every
// app ships; saved looks live in the suite's PresetStore as kind `look`.
// Linux-safe.

/// A named adjustment: tone, adjust and kinds.
public struct LookPreset: Hashable, Codable, Sendable, Identifiable {
    /// "bw" for a built-in; a saved look's store id.
    public var id: String
    /// "Black & White": the grid's label.
    public var name: String
    /// True for the six shipped looks, which can't be deleted.
    public var builtIn: Bool
    public var tone: ToneSettings
    public var adjust: AdjustSettings
    public var kinds: [ImagingKind]

    /// The record kind a look is saved under.
    public static let recordKind = "look"

    public init(id: String, name: String, builtIn: Bool = false, tone: ToneSettings = .neutral,
                adjust: AdjustSettings = .neutral, kinds: [ImagingKind] = []) {
        (self.id, self.name, self.builtIn) = (id, name, builtIn)
        (self.tone, self.adjust, self.kinds) = (tone, adjust, kinds)
    }
}

/// The six looks every app ships, in grid order.
public enum BuiltInLooks {
    public static let all: [LookPreset] = [
        LookPreset(id: "bw", name: "Black & White", builtIn: true, kinds: [.blackAndWhite(.neutral)]),
        LookPreset(id: "bw-high-contrast", name: "High Contrast B&W", builtIn: true,
                   tone: tone([.contrast: 40, .whites: 20, .blacks: -20]), kinds: [.blackAndWhite(.neutral)]),
        LookPreset(id: "warm", name: "Warm", builtIn: true, tone: tone([.temperature: 25, .tint: 5])),
        LookPreset(id: "cool", name: "Cool", builtIn: true, tone: tone([.temperature: -25, .tint: -5])),
        LookPreset(id: "fade", name: "Fade", builtIn: true, tone: tone([.contrast: -15]),
                   adjust: AdjustSettings(levels: AdjustLevels(inputBlack: 0, inputWhite: 1, gamma: 1, outputBlack: 0.08, outputWhite: 0.94))),
        LookPreset(id: "vivid", name: "Vivid", builtIn: true, tone: tone([.contrast: 15, .saturation: 30])),
    ]

    /// The built-in look with `id`, or nil.
    public static func look(_ id: String) -> LookPreset? { all.first { $0.id == id } }

    /// Neutral tone with `values` set.
    static func tone(_ values: KeyValuePairs<ToneSlider, Double>) -> ToneSettings {
        values.reduce(ToneSettings.neutral) { $0.setting($1.key, to: $1.value) }
    }
}
