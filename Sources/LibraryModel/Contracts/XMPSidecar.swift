// Contracts/XMPSidecar.swift (metadata-more MD-4 slot; MD-15 fills the packet,
// marker and name, MD-16 the plan and status): the XMP packet Library keeps
// beside each photo file, the name it goes by, and the catalog's plan of what
// to write. The packet follows the XMP spec (ISO 16684-1): Dublin Core
// `dc:subject` (Bag), `dc:title` and `dc:description` (Alt, x-default), XMP
// Basic `xmp:Rating` and `xmp:Label`, plus Library's `lib:Writer` marker. It
// shares its `x:xmpmeta`/`rdf:RDF` head and Library namespace with
// `ExportSidecar`, and escapes with SuiteModel's `XMLText` as that does.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

public enum XMPSidecar {
    /// Library's own XMP namespace (a URI we control; it need not resolve).
    static let libraryNamespace = "https://github.com/qbtrix/creative-apps/ns/library/1.0/"
    /// The `x:xmpmeta` and `rdf:RDF` opening tags every Library packet starts with.
    static let head = "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">"
        + "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">"
    /// The marker attribute `isWrittenByLibrary` looks for.
    static let marker = "lib:Writer=\"Library\""

    /// The sidecar's UTF-8 packet for `fields`: only the fields that say something.
    public static func encode(_ fields: SidecarFields) -> Data {
        var lines = [
            "<?xpacket begin=\"\u{FEFF}\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>", head,
            "<rdf:Description rdf:about=\"\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" "
                + "xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\" xmlns:lib=\"\(libraryNamespace)\" \(marker)>",
        ]
        if fields.rating != 0 { lines.append("<xmp:Rating>\(fields.rating)</xmp:Rating>") }
        if let label = fields.label { lines.append("<xmp:Label>\(text(label.rawValue))</xmp:Label>") }
        if !fields.keywords.isEmpty {
            let items = fields.keywords.map { "<rdf:li>\(text($0))</rdf:li>" }.joined()
            lines.append("<dc:subject><rdf:Bag>\(items)</rdf:Bag></dc:subject>")
        }
        if !fields.title.isEmpty { lines.append(alternative("dc:title", fields.title)) }
        if !fields.caption.isEmpty { lines.append(alternative("dc:description", fields.caption)) }
        lines.append("</rdf:Description></rdf:RDF></x:xmpmeta>")
        lines.append("<?xpacket end=\"w\"?>")
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// Whether `data` carries Library's namespace and its `lib:Writer` marker.
    public static func isWrittenByLibrary(_ data: Data) -> Bool {
        let text = String(decoding: data, as: UTF8.self)
        return text.contains("xmlns:lib=\"\(libraryNamespace)\"") && text.contains(marker)
    }

    /// `IMG_0001.xmp` beside `IMG_0001.jpg`, or `IMG_0001.jpg.xmp` when another
    /// sibling in the same folder shares the stem, so two photos never share one.
    public static func path(for photoPath: String, siblings: Set<String>) -> String {
        let stem = self.stem(of: photoPath)
        let clash = siblings.contains { $0 != photoPath && self.stem(of: $0) == stem }
        return (clash ? photoPath : stem) + ".xmp"
    }

    /// `/a/IMG_1.jpg` → `/a/IMG_1` (folder kept, so another folder's `IMG_1` differs);
    /// a name with no extension, or only a leading dot, is its own stem.
    static func stem(of path: String) -> String {
        let nameStart = path.lastIndex(of: "/").map { path.index(after: $0) } ?? path.startIndex
        guard let dot = path[nameStart...].lastIndex(of: "."), dot != nameStart else { return path }
        return String(path[..<dot])
    }

    /// `rdf:Alt` with one `x-default` item, the shape XMP gives language alternatives.
    static func alternative(_ element: String, _ value: String) -> String {
        "<\(element)><rdf:Alt><rdf:li xml:lang=\"x-default\">\(text(value))</rdf:li></rdf:Alt></\(element)>"
    }

    /// `value` safe as XML character data: control characters but tab and newline dropped, then escaped.
    static func text(_ value: String) -> String {
        var kept = String.UnicodeScalarView()
        kept.append(contentsOf: value.unicodeScalars.filter { $0.value >= 0x20 || $0 == "\t" || $0 == "\n" })
        return XMLText.escaped(String(kept))
    }
}

extension LibraryCatalog {
    /// The sidecars to write so each photo file's matches its fields, given
    /// what was `written`. MD-16; [] until then.
    public func sidecarWrites(after written: [String: SidecarFields]) -> [SidecarWrite] { [] }

    /// The Info tab's Sidecar row for photo `id`. MD-16; nil until then.
    public func sidecarStatus(
        for id: String, written: [String: SidecarFields], failures: [String: String], writing: Set<String>
    ) -> String? { nil }
}
