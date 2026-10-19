// Contracts/ExportNaming+Kernel.swift: export names, the adapter onto SuiteModel's UniqueFileNames.
import SuiteModel

/// A name template; `{name}` is the photo's name.
public struct ExportNaming: Hashable, Sendable, Codable {
    public var template: String
    public static let original = ExportNaming(template: "{name}")
    public init(template: String) { self.template = template }
    /// The file stem for `photo`, the `index`-th (0-based) of `count`. Slot: the photo's name.
    public func stem(for photo: PhotoItem, index: Int, count: Int) -> String { photo.name }
    /// Why the template can't name files; nil when it can. Slot: only `.original` can.
    public var help: String? {
        self == .original ? nil : "Name templates aren't built yet (export naming)."
    }
}

/// The final naming rule every exporter plans with.
public enum ExportNames {
    /// `<stem>.<ext>`, then `<stem> 2.<ext>`, `<stem> 3.<ext>` … skipping `existing`
    /// and names earlier in the list; with `sidecar`, `<chosen stem>.xmp` must be free too.
    public static func unique(stems: [String], format: ExportFormat, sidecar: Bool,
                              existing: Set<String>) -> [String] {
        let image = "." + format.fileExtension
        let suffixes = sidecar ? [image, ".xmp"] : [image]
        var taken = Set(existing.compactMap { name in
            suffixes.first { name.lowercased().hasSuffix($0) }.map { String(name.dropLast($0.count)) }
        })
        return stems.map { stem in
            let picked = UniqueFileNames.name(stem, extension: "", among: taken)
            taken.insert(picked)
            return picked + image
        }
    }
}
