// HomeLayout.swift: column math for the home's tile row and recents grid
// (blueprint section 7.3). Foundation free, Linux-safe.

/// Widths are whole multiples of 4 pt, so every origin sits on the 4 pt grid.
public enum HomeLayout {
    public static let sidebar = 200.0, margin = 24.0, gap = 16.0, cardMin = 168.0, cardMax = 240.0
    public static let tileMax = 240.0, tileChipsMin = 160.0

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

    /// Below this width a tile shows its presets as a menu, not chips.
    public static func tileShowsChips(windowWidth: Double) -> Bool { tileWidth(windowWidth: windowWidth) >= tileChipsMin }
}
