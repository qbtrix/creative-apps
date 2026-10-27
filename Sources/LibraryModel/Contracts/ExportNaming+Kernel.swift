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
        Self.stem(for: photo, index: index, digits: String(max(count, 1)).count, pieces: pieces)
    }

    /// The stems of `photos` in order, the template parsed once (LG-4).
    public func stems(for photos: [PhotoItem]) -> [String] {
        let pieces = pieces, digits = String(max(photos.count, 1)).count
        return photos.enumerated().map { Self.stem(for: $1, index: $0, digits: digits, pieces: pieces) }
    }

    private static func stem(for photo: PhotoItem, index: Int, digits: Int, pieces: [Piece]) -> String {
        let filled = pieces.map { piece -> String in
            switch piece {
            case .text(let text): return text
            case .token("name"): return photo.name
            case .token("date"): return LibraryCatalog.dayText(photo.captureDate, utcOffset: 0)
            case .token("seq"): return LibraryFixtures.padded(index + 1, to: digits)
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
    /// Names compare lowercased (UniqueFileNames' rule). One pass: `taken` holds lowercased
    /// stems and grows per photo, so a plan of n photos never rescans the names before it (LG-4).
    public static func unique(stems: [String], format: ExportFormat, sidecar: Bool,
                              existing: Set<String>) -> [String] {
        let image = "." + format.fileExtension
        let suffixes = sidecar ? [image, ".xmp"] : [image]
        var taken = Set(existing.compactMap { name in
            suffixes.first { name.lowercased().hasSuffix($0) }.map { String(name.dropLast($0.count)).lowercased() }
        })
        return stems.map { stem in
            let base = UniqueFileNames.name(stem, extension: "", among: [])
            var name = base, number = 2
            while taken.contains(name.lowercased()) {
                name = "\(base) \(number)"
                number += 1
            }
            let picked = name.lowercased()
            taken.insert(picked)
            return name + image
        }
    }
}
