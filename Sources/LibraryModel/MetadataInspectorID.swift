// MetadataInspectorID.swift: the accessibility identifiers of the metadata
// inspector's controls, so the UI journeys and the app audit find them
// whatever their state (#262). Each one is stable across ratings, flags and
// labels, and no two controls share one.
public enum MetadataInspectorID {
    /// The Flag menu.
    public static let flag = "library.metadata.flag"

    /// The star that rates a photo `star` (1 to 5).
    public static func star(_ star: Int) -> String {
        "library.metadata.star.\(star)"
    }

    /// The dot that sets `label`; nil is the No Label dot.
    public static func label(_ label: PhotoLabel?) -> String {
        "library.metadata.label.\(label?.rawValue.lowercased() ?? "none")"
    }
}
