// HomeLayout.swift: column math for the home's tile row and recents grid
// (blueprint section 7.3). Foundation free, Linux-safe.

/// Widths are whole multiples of 4 pt, so every origin sits on the 4 pt grid.
public enum HomeLayout {
    public static let sidebar = 200.0, margin = 24.0, gap = 16.0, cardMin = 168.0, cardMax = 240.0
    public static let tileMax = 240.0
    /// A tile's presets sit in ChoiceChips' three columns, 4 pt apart. A chip's
    /// label is the 10 pt semibold caption, at most `chipGlyph` per character,
    /// inside `chipInset` of padding; `chipLabelMin` fits a six-letter title.
    public static let chipColumns = 3.0, chipSpacing = 4.0, chipGlyph = 6.5, chipInset = 16.0, chipLabelMin = 64.0
    /// The narrowest tile whose chips can hold any label at all.
    public static let tileChipsMin = chipColumns * chipLabelMin + (chipColumns - 1) * chipSpacing

    static func content(_ windowWidth: Double) -> Double { max(windowWidth - sidebar - 2 * margin, cardMin) }
    static func four(_ v: Double) -> Double { (v / 4).rounded(.down) * 4 }

    public static func columns(windowWidth: Double) -> Int {
        max(1, Int((content(windowWidth) + gap) / (cardMin + gap)))
    }

    public static func cardWidth(windowWidth: Double) -> Double {
        let n = Double(columns(windowWidth: windowWidth))
        return min(cardMax, four((content(windowWidth) - gap * (n - 1)) / n))
    }

    /// Five tiles in one row.
    public static func tileWidth(windowWidth: Double) -> Double {
        min(tileMax, four((content(windowWidth) - 4 * gap) / 5))
    }

    /// Below `tileChipsMin` a tile shows its presets as a menu, not chips.
    public static func tileShowsChips(windowWidth: Double) -> Bool { tileWidth(windowWidth: windowWidth) >= tileChipsMin }

    /// One chip's width in a tile at this window width.
    public static func chipWidth(windowWidth: Double) -> Double {
        (tileWidth(windowWidth: windowWidth) - (chipColumns - 1) * chipSpacing) / chipColumns
    }

    /// The width a chip needs to show `title` untruncated (an upper estimate).
    public static func chipLabelWidth(_ title: String) -> Double { Double(title.count) * chipGlyph + chipInset }

    /// Chips only when the tile has a row of presets and every title fits a chip
    /// untruncated (#1753); otherwise the Presets menu.
    public static func tileShowsChips(windowWidth: Double, presets: [NewDocumentPreset]) -> Bool {
        let chip = chipWidth(windowWidth: windowWidth)
        return presets.count > 1 && tileShowsChips(windowWidth: windowWidth)
            && presets.prefix(Int(chipColumns)).allSatisfy { chipLabelWidth($0.title) <= chip }
    }

    /// A tile's click already creates its first preset, so a single preset gets no row of its own.
    public static func showsPresets(_ tile: NewTile) -> Bool { tile.presets.count > 1 }

    /// A preset control's help: what it creates and its size or formats.
    public static func presetHelp(_ preset: NewDocumentPreset) -> String { "\(preset.title): \(preset.detail)" }

    /// The help for a row of presets, one line per preset.
    public static func presetsHelp(_ presets: [NewDocumentPreset]) -> String {
        presets.map(presetHelp).joined(separator: "\n")
    }
}
