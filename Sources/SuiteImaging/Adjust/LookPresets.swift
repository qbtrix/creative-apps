// LookPresets.swift (adjust-everywhere AJ-2 data, AJ-6 apply): a look is a
// whole adjustment saved under a name, tone, AdjustSettings and kinds, that
// `look.apply` sets on a picture in one step. BuiltInLooks are the six every
// app ships; saved looks live in the suite's PresetStore as kind `look`.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

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

/// A look's place in the suite's preset store, and the lookups the look commands share.
extension LookPreset {
    /// This look as a store record of kind `look`, its values encoded as JSON.
    public func record() throws -> PresetRecord {
        PresetRecord(id: id, name: name, kind: Self.recordKind, payload: try JSONEncoder().encode(self))
    }

    /// The look `r` holds, named and identified by the record; nil when it isn't a readable look.
    public init?(record r: PresetRecord) {
        guard r.kind == Self.recordKind, var look = try? JSONDecoder().decode(LookPreset.self, from: r.payload) else { return nil }
        (look.id, look.name, look.builtIn) = (r.id, r.name, false)
        self = look
    }

    /// The built-in looks, then the readable saved ones in `store`.
    public static func all(in store: any PresetStoring) -> [LookPreset] {
        BuiltInLooks.all + store.list(kind: recordKind).compactMap(LookPreset.init(record:))
    }

    /// The built-in or saved look with `id`, or nil.
    public static func find(_ id: String, in store: any PresetStoring) -> LookPreset? {
        all(in: store).first { $0.id == id }
    }

    /// True when a built-in or saved look is already called `name`, ignoring case.
    public static func nameTaken(_ name: String, in store: any PresetStoring) -> Bool {
        all(in: store).contains { $0.name.lowercased() == name.lowercased() }
    }

    /// A new id for a look called `name`: its lowercase words joined by dashes, numbered past any id in use.
    public static func newID(_ name: String, in store: any PresetStoring) -> String {
        let words = name.lowercased().split { !($0.isLetter || $0.isNumber) }.joined(separator: "-")
        let base = words.isEmpty ? recordKind : words
        let used = Set(all(in: store).map(\.id))
        var id = base, n = 1
        while used.contains(id) { n += 1; id = "\(base)-\(n)" }
        return id
    }
}
