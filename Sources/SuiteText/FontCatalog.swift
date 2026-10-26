// FontCatalog.swift: shell-text's font list on Core Text (ST-5). Every font
// descriptor of the available-fonts collection becomes a face of its family:
// its style name, its weight (the normalized -1...1 weight trait as the
// nearest of the nine weights CoreTextMeasurer draws, 100...900) and its
// italic symbolic trait. Hidden families (a leading ".") are left out; the
// system UI font is listed instead as FakeText's "System UI" family, the name
// CoreTextMeasurer resolves an empty or unknown family to, with an upright and
// an italic face at each weight. Families are unique and sorted by name
// (case-insensitive, then exact); faces are unique by name, sorted by weight,
// upright first, then name.
#if canImport(AppKit)
import AppKit
import CoreText
import SuiteModel

/// Lists the Mac's font families and their faces.
public struct FontCatalog: FontListing {
    public init() {}

    public func families() -> [FontFamily] {
        var faces: [String: [FontFace]] = [FakeText.systemFamily: Self.systemFaces]
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        for descriptor in descriptors {
            guard let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String,
                  !family.isEmpty, !family.hasPrefix("."), family != FakeText.systemFamily else { continue }
            faces[family, default: []].append(Self.face(descriptor))
        }
        return faces.map { FontFamily(name: $0.key, faces: Self.unique($0.value)) }
            .sorted { Self.ordered($0.name, $1.name) }
    }

    /// Whether family `a` lists before `b`: case-insensitive, then exact.
    public static func ordered(_ a: String, _ b: String) -> Bool {
        switch a.caseInsensitiveCompare(b) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: a < b
        }
    }

    /// `descriptor`'s style name, weight in hundreds and italic flag.
    static func face(_ descriptor: CTFontDescriptor) -> FontFace {
        let style = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String ?? ""
        let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [String: Any] ?? [:]
        let trait = (traits[kCTFontWeightTrait as String] as? NSNumber)?.doubleValue ?? 0
        let symbolic = (traits[kCTFontSymbolicTrait as String] as? NSNumber)?.uint32Value ?? 0
        let italic = symbolic & CTFontSymbolicTraits.traitItalic.rawValue != 0
        return FontFace(name: style.isEmpty ? (italic ? "Italic" : "Regular") : style,
                        weight: weight(trait), italic: italic)
    }

    /// The normalized weight trait as the nearest of CoreTextMeasurer's nine weights, 100...900.
    static func weight(_ trait: Double) -> Int {
        let value = trait.isFinite ? trait : 0
        let nearest = (1...9).min { a, b in
            abs(Double(CoreTextMeasurer.weight(a * 100).rawValue) - value)
                < abs(Double(CoreTextMeasurer.weight(b * 100).rawValue) - value)
        }
        return (nearest ?? 4) * 100
    }

    /// `faces` with each name once (the first kept), by weight, upright first, then name.
    static func unique(_ faces: [FontFace]) -> [FontFace] {
        var seen = Set<String>()
        return faces.filter { seen.insert($0.name).inserted }.sorted {
            ($0.weight, $0.italic ? 1 : 0, $0.name) < ($1.weight, $1.italic ? 1 : 0, $1.name)
        }
    }

    /// The system UI font's faces: an upright and an italic one at each of the nine weights.
    static let systemFaces: [FontFace] = {
        let names = ["Ultralight", "Thin", "Light", "Regular", "Medium", "Semibold", "Bold", "Heavy", "Black"]
        return names.enumerated().flatMap { index, name in
            [FontFace(name: name, weight: (index + 1) * 100, italic: false),
             FontFace(name: name == "Regular" ? "Italic" : "\(name) Italic", weight: (index + 1) * 100, italic: true)]
        }
    }()
}
#endif
