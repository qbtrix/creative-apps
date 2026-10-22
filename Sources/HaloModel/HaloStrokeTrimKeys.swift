// HaloStrokeTrimKeys.swift: the key diamonds on STROKE's trim rows
// (stroke-style HK-3). A shape layer with a stroke lists Trim Start, Trim End
// and Trim Offset in that order, each with its track's key state at the
// playhead (`HaloKeyRules.keyState`, the kernel's KeyRules, never a second
// store) and why it can't act: the stroke's reason first, then the property's
// own keying reason (HK-5's `HaloProperty.trims`; HK-7 dropped the not-built
// reason those replaced). A key without a reason maps to the property's
// `toggleKey` (the diamond) or `toggleAnimation` (the stopwatch). Linux-safe.

/// One trim row's stopwatch and diamond: its track, title, key state at the playhead and reason.
public struct HaloTrimKey: Sendable, Hashable, Identifiable {
    /// The track's key in `HaloLayer.tracks`: trimStart, trimEnd or trimOffset.
    public let raw: String
    public let title: String
    public let keyState: HaloKeyState
    /// Why the pair can't act; nil while it can.
    public let help: String?
    public var id: String { raw }

    public init(raw: String, title: String, keyState: HaloKeyState, help: String?) {
        self.raw = raw
        self.title = title
        self.keyState = keyState
        self.help = help
    }
}

extension HaloProject {
    /// The selected layer's trim keys at the playhead; [] without a stroked shape layer.
    public var trimKeys: [HaloTrimKey] {
        let stroke = strokeHelp
        return Self.trimKeys(of: selectedLayer, at: selectedComposition?.playheadFrame ?? 0) { p in
            Self.trimKeyHelp(p, strokeHelp: stroke) { unavailableHelp(for: .toggleAnimation($0)) }
        }
    }

    /// `layer`'s trim keys at `frame` in `HaloProperty.trims` order, each with `help(p)`; [] unless
    /// `layer` is a shape with a stroke.
    static func trimKeys(of layer: HaloLayer?, at frame: Int, help: (HaloProperty) -> String?) -> [HaloTrimKey] {
        guard let layer, layer.kind == .shape, layer.stroke != nil else { return [] }
        return HaloProperty.trims.map { p in
            HaloTrimKey(
                raw: p.rawValue, title: p.title,
                keyState: HaloKeyRules.keyState(layer.tracks[p.rawValue] ?? [], at: frame), help: help(p))
        }
    }

    /// Why trim property `p` can't be keyed: `strokeHelp`, else the property's own reason.
    static func trimKeyHelp(
        _ p: HaloProperty, strokeHelp: String?, propertyHelp: (HaloProperty) -> String?
    ) -> String? {
        if let strokeHelp { return strokeHelp }
        return propertyHelp(p)
    }

    /// The command a click on `key` sends: `toggleKey` for the diamond, `toggleAnimation` for the
    /// stopwatch; nil while the key has a reason or no property.
    public static func trimKeyCommand(_ key: HaloTrimKey, diamond: Bool) -> HaloCommand? {
        guard key.help == nil, let property = HaloProperty(rawValue: key.raw) else { return nil }
        return diamond ? .toggleKey(property) : .toggleAnimation(property)
    }
}
