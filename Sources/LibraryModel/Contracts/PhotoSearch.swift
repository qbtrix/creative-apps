// Contracts/PhotoSearch.swift (metadata-more MD-4 slot, filled by MD-20): the
// window's search field as a value. The text splits into tokens on spaces
// outside double quotes, and a photo matches when every token does. A token
// `field:value` narrows to keyword, title, caption, camera, lens, iso, f or mm;
// iso, f and mm compare numbers (`>n`, `<n`, `>=n`, `<=n` or `n`). An unknown
// field or a bad number makes the token plain text, which matches the name, a
// keyword, the title, the caption, the camera or the lens, in any case. The
// catalog's stored search (`search`, `setSearch(_:)`) is MD-21's. Linux-safe.

/// What the search field holds, and which photos it lets through.
public struct PhotoSearch: Hashable, Sendable {
    /// The field's text, as typed.
    public var text: String {
        didSet { terms = Self.terms(in: text) }
    }

    /// The parsed tokens; every one must match.
    private var terms: [SearchTerm]

    public init(_ text: String) {
        self.text = text
        self.terms = Self.terms(in: text)
    }

    /// Nothing but spaces: the search shows every photo.
    public var isEmpty: Bool {
        text.allSatisfy(\.isWhitespace)
    }

    /// Whether `photo` matches every token.
    public func matches(_ photo: PhotoItem) -> Bool {
        terms.allSatisfy { $0.matches(photo) }
    }

    /// The tokens of `text`: split on spaces outside double quotes, the
    /// quotes dropped, a field split off at the first unquoted colon.
    static func terms(in text: String) -> [SearchTerm] {
        var terms: [SearchTerm] = []
        var field: String?
        var value = ""
        var quoted = false
        func flush() {
            if let term = SearchTerm(field: field, value: value) { terms.append(term) }
            field = nil
            value = ""
        }
        for character in text {
            if character == "\"" {
                quoted.toggle()
            } else if character.isWhitespace && !quoted {
                flush()
            } else if character == ":" && !quoted && field == nil && !value.isEmpty {
                field = value
                value = ""
            } else {
                value.append(character)
            }
        }
        flush()
        return terms
    }
}

/// A field `field:value` can name for text.
enum SearchTextField: String, Hashable, Sendable {
    case keyword, title, caption, camera, lens
}

/// A field `field:value` can name for a number.
enum SearchNumberField: String, Hashable, Sendable {
    case iso, f, mm

    /// The photo's number for this field; nil when the camera didn't say.
    func value(of photo: PhotoItem) -> Double? {
        switch self {
        case .iso: photo.camera.iso.map(Double.init)
        case .f: photo.camera.fNumber
        case .mm: photo.camera.focalLength
        }
    }
}

/// How a number token compares.
enum SearchComparison: String, Hashable, Sendable, CaseIterable {
    // Two-character operators first, so `>=` isn't read as `>`.
    case atLeast = ">=", atMost = "<=", above = ">", below = "<", equal = "="

    func holds(_ value: Double, _ bound: Double) -> Bool {
        switch self {
        case .atLeast: value >= bound
        case .atMost: value <= bound
        case .above: value > bound
        case .below: value < bound
        case .equal: value == bound
        }
    }
}

/// One search token.
enum SearchTerm: Hashable, Sendable {
    /// Lowercased text in one field, or in any (nil).
    case text(String, SearchTextField?)
    case number(SearchNumberField, SearchComparison, Double)

    /// The term for `field:value`, or plain text when the field is unknown or
    /// the number bad; nil for an empty token.
    init?(field: String?, value: String) {
        if let field, !value.isEmpty {
            if let textField = SearchTextField(rawValue: field.lowercased()) {
                self = .text(value.lowercased(), textField)
                return
            }
            if let numberField = SearchNumberField(rawValue: field.lowercased()),
               let parsed = Self.comparison(value) {
                self = .number(numberField, parsed.0, parsed.1)
                return
            }
        }
        let plain = field.map { $0 + ":" + value } ?? value
        guard !plain.isEmpty else { return nil }
        self = .text(plain.lowercased(), nil)
    }

    /// `>n`, `<n`, `>=n`, `<=n`, `=n` or `n`; nil when n isn't a finite number.
    static func comparison(_ value: String) -> (SearchComparison, Double)? {
        let comparison = SearchComparison.allCases.first { value.hasPrefix($0.rawValue) } ?? .equal
        let digits = value.hasPrefix(comparison.rawValue) ? value.dropFirst(comparison.rawValue.count) : Substring(value)
        guard let bound = Double(digits), bound.isFinite else { return nil }
        return (comparison, bound)
    }

    func matches(_ photo: PhotoItem) -> Bool {
        switch self {
        case .number(let field, let comparison, let bound):
            guard let value = field.value(of: photo) else { return false }
            return comparison.holds(value, bound)
        case .text(let needle, let field):
            return Self.texts(of: photo, in: field).contains { $0.lowercased().contains(needle) }
        }
    }

    /// The texts a token in `field` (nil: any) looks through.
    static func texts(of photo: PhotoItem, in field: SearchTextField?) -> [String] {
        let camera = photo.camera.searchName.map { [$0] } ?? []
        let lens = photo.camera.lens.map { [$0] } ?? []
        switch field {
        case .keyword: return photo.keywords
        case .title: return [photo.title]
        case .caption: return [photo.caption]
        case .camera: return camera
        case .lens: return lens
        case nil: return [photo.name] + photo.keywords + [photo.title, photo.caption] + camera + lens
        }
    }
}

extension CameraDetails {
    /// Make and model, "Fixture Optics FX-1"; nil when neither is known.
    var searchName: String? {
        let parts = [make, model].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

extension LibraryCatalog {
    /// Searches for the field's suggestions list (`lens:"50mm F1.8"`), at
    /// most `limit`: the catalog's cameras, then lenses, then keywords, each
    /// A to Z, whose value has a word starting with `prefix` (any case) or
    /// whose search starts with it. An empty prefix lists them all.
    public func searchSuggestions(prefix: String, limit: Int = 8) -> [String] {
        guard limit > 0 else { return [] }
        let needle = prefix.trimmingSpaces.lowercased()
        let byText: (String, String) -> Bool = { $0.lowercased() < $1.lowercased() }
        let groups: [(SearchTextField, [String])] = [
            (.camera, Set(items.compactMap(\.camera.searchName)).sorted(by: byText)),
            (.lens, Set(items.compactMap(\.camera.lens)).sorted(by: byText)),
            (.keyword, Set(items.flatMap(\.keywords)).sorted(by: byText)),
        ]
        var suggestions: [String] = []
        for (field, values) in groups {
            for value in values where !value.contains("\"") {
                let search = field.rawValue + ":" + (value.contains(" ") ? "\"" + value + "\"" : value)
                let words = value.lowercased().split(separator: " ")
                guard needle.isEmpty || search.lowercased().hasPrefix(needle)
                    || words.contains(where: { $0.hasPrefix(needle) }) else { continue }
                suggestions.append(search)
                if suggestions.count == limit { return suggestions }
            }
        }
        return suggestions
    }
}

extension String {
    /// Without leading and trailing whitespace.
    fileprivate var trimmingSpaces: String {
        guard let first = firstIndex(where: { !$0.isWhitespace }),
              let last = lastIndex(where: { !$0.isWhitespace }) else { return "" }
        return String(self[first...last])
    }
}

extension MetadataInspectorID {
    /// The window's search field.
    public static let search = "library.search"
}
