// Contracts/ExportNaming+Kernel.swift: export names, the adapter onto SuiteModel's UniqueFileNames.
import SuiteModel

/// A name template: `{name}`, `{date}` (capture day, yyyy-MM-dd UTC), `{seq}` (1-based,
/// zero-padded to the count's digits) and `{rating}` (0–5); any other text is kept.
public struct ExportNaming: Hashable, Sendable, Codable {
    public var template: String
    public static let original = ExportNaming(template: "{name}")
    public static let tokens = ["name", "date", "seq", "rating"]
    public init(template: String) { self.template = template }

    /// The file stem for `photo`, the `index`-th (0-based) of `count`: the template filled,
    /// `/` and `:` made "-" (SuiteModel's rule), leading dots dropped; the photo's name when
    /// that leaves nothing.
    public func stem(for photo: PhotoItem, index: Int, count: Int) -> String {
        let filled = pieces.map { piece -> String in
            switch piece {
            case .text(let text): return text
            case .token("name"): return photo.name
            case .token("date"): return LibraryCatalog.dayText(photo.captureDate, utcOffset: 0)
            case .token("seq"): return LibraryFixtures.padded(index + 1, to: String(max(count, 1)).count)
            case .token("rating"): return String(min(max(photo.rating, 0), 5))
            case .token(let other): return "{\(other)}"
            }
        }.joined()
        guard !filled.allSatisfy(\.isWhitespace) else { return photo.name }
        let stem = String(UniqueFileNames.name(filled, extension: "", among: []).drop { $0 == "." })
        return stem.isEmpty ? photo.name : stem
    }

    /// "Unknown token {x}." for the first token that isn't one of `tokens`; nil when the
    /// template can name files.
    public var help: String? {
        for case .token(let name) in pieces where !Self.tokens.contains(name) { return "Unknown token {\(name)}." }
        return nil
    }

    private enum Piece: Equatable { case text(String), token(String) }

    /// The template split into literal text and `{token}`s; a `{` with no `}` is text.
    private var pieces: [Piece] {
        var pieces: [Piece] = [], rest = Substring(template)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            if open > rest.startIndex { pieces.append(.text(String(rest[..<open]))) }
            pieces.append(.token(String(rest[rest.index(after: open)..<close])))
            rest = rest[rest.index(after: close)...]
        }
        if !rest.isEmpty { pieces.append(.text(String(rest))) }
        return pieces
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
