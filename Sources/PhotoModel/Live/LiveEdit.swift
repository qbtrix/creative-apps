// Live/LiveEdit.swift: the live edit use cases. PV-2 (photo-edit) replaces
// these NotBuilt stand-ins with the real clipboard and Merge Down / Flatten.
// Linux-safe.
enum LiveEdit {
    static func clipboard() -> any PixelClipboard { NotBuiltClipboard() }
    static func merging() -> any LayerMerging { NotBuiltMerging() }
}
