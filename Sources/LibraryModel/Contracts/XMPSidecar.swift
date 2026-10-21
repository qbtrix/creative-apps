// Contracts/XMPSidecar.swift (metadata-more MD-4 slot; MD-15 filled the packet,
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
    /// what was `written`: a photo whose fields equal its written ones is
    /// skipped, and so is one with nothing to say and nothing written, so
    /// folders never fill with empty packets. Samples have no file and no sidecar.
    public func sidecarWrites(after written: [String: SidecarFields]) -> [SidecarWrite] {
        var plan: [SidecarWrite] = []
        for photo in items {
            guard let photoPath = photo.path else { continue }
            let previous = written[photo.id]
            // `previous == SidecarFields(photo: photo)`, inline and without building one:
            // this runs for every photo after each change (QB-LIB-M4).
            if let previous, previous.rating == (photo.flag == .reject ? -1 : photo.rating),
               previous.label == photo.label, previous.title == photo.title,
               previous.caption == photo.caption, previous.keywords == photo.keywords { continue }
            let fields = SidecarFields(photo: photo)
            if previous == nil && fields.isEmpty { continue }
            plan.append(SidecarWrite(
                photoID: photo.id, path: sidecarPath(for: photoPath), fields: fields, data: XMPSidecar.encode(fields)))
        }
        return plan
    }

    /// The Info tab's Sidecar row for photo `id`: a sample has none, then
    /// "Saving…" while `writing`, the failure's own sentence, "Saved to <name>"
    /// when `written` matches, else "No sidecar yet". Nil for an unknown id.
    public func sidecarStatus(
        for id: String, written: [String: SidecarFields], failures: [String: String], writing: Set<String>
    ) -> String? {
        guard let photo = items.first(where: { $0.id == id }) else { return nil }
        guard let photoPath = photo.path else { return "Samples have no file, so no sidecar." }
        if writing.contains(id) { return "Saving…" }
        if let failure = failures[id] { return failure }
        guard written[id] == SidecarFields(photo: photo) else { return "No sidecar yet" }
        let path = sidecarPath(for: photoPath)
        let name = path.lastIndex(of: "/").map { String(path[path.index(after: $0)...]) } ?? path
        return "Saved to \(name)"
    }

    /// `XMPSidecar.path` against the catalog's files. Only a file whose path
    /// starts with the photo's stem can share it, so only those are passed.
    func sidecarPath(for photoPath: String) -> String {
        let stem = XMPSidecar.stem(of: photoPath)
        var siblings: Set<String> = []
        for photo in items {
            if let path = photo.path, path.hasPrefix(stem) { siblings.insert(path) }
        }
        return XMPSidecar.path(for: photoPath, siblings: siblings)
    }
}
