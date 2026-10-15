// Fakes/FolioFakes.swift: a fake for every Folio contract, so views and
// journeys run before PDFKit and Vision are wired (`-FolioFixture <name>`).
// The pure use cases' fakes are full reference behaviour: W1 promotes each to
// its Live/ file and the fake becomes a one-line wrapper (no copies: jscpd).
// The platform fakes read a "fake PDF": the line `%FOLIO-FAKE-PDF-1`, then a
// FolioFixtureFile as JSON, laid out on a fixed grid (FolioFakeLayout) so
// tests know where every glyph is. Sources live in FakeDocumentSources,
// keyed by a hash of the bytes, so a saved file reopens under its own id.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: The fake file format and layout

public struct FolioFixtureFile: Codable, Equatable, Sendable {
    public struct Page: Codable, Equatable, Sendable {
        public var size: FolioSize
        public var rotation: FolioRotation
        public var lines: [String]
        /// Indices of lines that do NOT end a paragraph (joined on copy).
        public var continued: [Int]
        /// A scan: no text layer until recognized; `lines` is what OCR finds.
        public var scanned: Bool
        /// Text recognized by Folio and saved as an invisible layer.
        public var recognized: [String]?
        public var label: String?
        /// Bytes of picture data on the page (a stand-in for images): written
        /// as padding, divided by 4 the first time the writer optimizes images.
        public var imageBytes: Int
        /// True once optimized: a second optimize leaves the pictures alone.
        public var optimized: Bool
        public var crop: FolioRect?
        public init(size: FolioSize = .letter, rotation: FolioRotation = .r0, lines: [String], continued: [Int] = [],
                    scanned: Bool = false, recognized: [String]? = nil, label: String? = nil, imageBytes: Int = 0,
                    optimized: Bool = false, crop: FolioRect? = nil) {
            self.size = size; self.rotation = rotation; self.lines = lines; self.continued = continued
            self.scanned = scanned; self.recognized = recognized; self.label = label; self.imageBytes = imageBytes
            self.optimized = optimized; self.crop = crop
        }
    }
    public struct Outline: Codable, Equatable, Sendable {
        public var title: String
        public var page: Int
        public init(title: String, page: Int) { self.title = title; self.page = page }
    }
    public var title: String
    public var author: String
    public var password: String?
    public var ownerPassword: String?
    public var permissions: FolioPermissions
    public var scripts: FolioScriptKind
    public var pages: [Page]
    public var outline: [Outline]
    /// Fields and annotations name pages by index into `pages`.
    public var fields: [FolioFormField]
    public var annotations: [FolioAnnotation]
    /// Picture data, one padding string per page with imageBytes > 0.
    public var pictures: [String]
    public init(title: String, author: String = "", password: String? = nil, ownerPassword: String? = nil,
                permissions: FolioPermissions = .all, scripts: FolioScriptKind = .none, pages: [Page],
                outline: [Outline] = [], fields: [FolioFormField] = [], annotations: [FolioAnnotation] = []) {
        self.title = title; self.author = author; self.password = password; self.ownerPassword = ownerPassword
        self.permissions = permissions; self.scripts = scripts; self.pages = pages; self.outline = outline
        self.fields = fields; self.annotations = annotations
        self.pictures = pages.filter { $0.imageBytes > 0 }.map { String(repeating: "x", count: $0.imageBytes) }
    }
    public static let magic = "%FOLIO-FAKE-PDF-1\n"
    public func data() -> Data {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        return Data(Self.magic.utf8) + ((try? enc.encode(self)) ?? Data())
    }
    /// nil: not a fake PDF at all; `.failure`: starts like one but is damaged.
    public static func decode(_ data: Data) -> Result<FolioFixtureFile, FolioOpenError>? {
        let magic = Data(Self.magic.utf8)
        guard data.starts(with: magic) else { return nil }
        do { return .success(try JSONDecoder().decode(FolioFixtureFile.self, from: data.dropFirst(magic.count))) } catch {
            return .failure(.damaged("its contents end early or are garbled"))
        }
    }
}

public enum FolioFakeLayout {
    public static let margin = 72.0
    public static let lineHeight = 14.0
    public static let glyphWidth = 6.0
    public static let glyphHeight = 12.0
    /// Line i of a page `height` tall: 72 pt in, 14 pt per line from the top.
    public static func line(_ text: String, index: Int, pageHeight: Double, endsParagraph: Bool = true) -> FolioTextLine {
        let y = pageHeight - margin - lineHeight * Double(index + 1)
        let rects = (0..<text.count).map { n in
            FolioRect(x: margin + glyphWidth * Double(n), y: y, width: glyphWidth, height: glyphHeight)
        }
        return FolioTextLine(text: text, glyphRects: rects, endsParagraph: endsParagraph)
    }
    public static func text(_ lines: [String], continued: [Int] = [], pageHeight: Double, origin: FolioTextOrigin) -> FolioPageText {
        FolioPageText(lines: lines.enumerated().map {
            line($1, index: $0, pageHeight: pageHeight, endsParagraph: !continued.contains($0))
        }, origin: origin)
    }
    /// FNV-1a over the bytes: the fake's content-derived source id.
    public static func sourceID(_ data: Data) -> FolioSourceID {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in data { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
        return FolioSourceID("fake:" + String(h, radix: 16))
    }
}

// MARK: Sources

public actor FakeDocumentSources: DocumentSources {
    private var bytes: [FolioSourceID: Data] = [:]
    private var names: [FolioSourceID: String] = [:]
    private var decoded: [FolioSourceID: FolioFixtureFile] = [:]
    public init() {}
    public func register(_ id: FolioSourceID, data: Data, name: String) async {
        bytes[id] = data; names[id] = name
        if case .success(let f)? = FolioFixtureFile.decode(data) { decoded[id] = f }
    }
    public func data(for id: FolioSourceID) async -> Data? { bytes[id] }
    public func name(for id: FolioSourceID) async -> String? { names[id] }
    /// The fixture page a FolioPage came from (fakes only).
    public func fixturePage(_ page: FolioPage) -> FolioFixtureFile.Page? {
        guard case .source(let src, let i) = page.origin, let f = decoded[src], f.pages.indices.contains(i) else { return nil }
        return f.pages[i]
    }
}

// MARK: Platform fakes

public struct FakeDocumentOpening: DocumentOpening {
    public let sources: FakeDocumentSources
    public var unavailableHelp: String? { nil }
    public init(sources: FakeDocumentSources) { self.sources = sources }
    public static let maxBytes = 2 * 1_073_741_824

    public func open(_ data: Data, name: String, password: String?) async throws(FolioOpenError) -> FolioOpened {
        guard data.count <= Self.maxBytes else { throw .tooLarge(bytes: data.count) }
        guard let result = FolioFixtureFile.decode(data) else { throw .notPDF }
        let file: FolioFixtureFile
        switch result { case .success(let f): file = f; case .failure(let e): throw e }
        var ownerUnlocked = file.ownerPassword == nil
        if let required = file.password {
            guard let given = password else { throw .needsPassword }
            guard given == required || given == file.ownerPassword else { throw .wrongPassword }
        }
        if let owner = file.ownerPassword, password == owner { ownerUnlocked = true }
        let source = FolioFakeLayout.sourceID(data)
        await sources.register(source, data: data, name: name)
        var opened = Self.opened(file, source: source, name: name)
        opened.state.permissions.ownerUnlocked = ownerUnlocked
        return opened
    }

    public func open(images: [FolioImageInput], name: String, paper: FolioSize) async throws(FolioOpenError) -> FolioOpened {
        var pages: [FolioFixtureFile.Page] = []
        var skipped: [FolioSkipped] = []
        for input in images {
            guard let px = Self.pngSize(input.data) else {
                skipped.append(FolioSkipped(name: input.name, reason: "not an image")); continue
            }
            let scale = min(paper.width / px.width, paper.height / px.height, 1)
            pages.append(.init(size: FolioSize(width: px.width * scale, height: px.height * scale), lines: [],
                               scanned: true, imageBytes: input.data.count))
        }
        guard !pages.isEmpty else { throw .notPDF }
        let file = FolioFixtureFile(title: name, pages: pages)
        let data = file.data()
        let source = FolioFakeLayout.sourceID(data)
        await sources.register(source, data: data, name: name)
        var opened = Self.opened(file, source: source, name: name)
        opened.skipped = skipped
        return opened
    }

    /// Width and height from a PNG's IHDR chunk (bytes 16 to 23), else nil.
    static func pngSize(_ d: Data) -> FolioSize? {
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let b = [UInt8](d.prefix(24))
        guard b.count == 24, Array(b[0..<8]) == sig else { return nil }
        func be(_ i: Int) -> Double { Double(UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3])) }
        let w = be(16), h = be(20)
        return w > 0 && h > 0 ? FolioSize(width: w, height: h) : nil
    }

    static func opened(_ file: FolioFixtureFile, source: FolioSourceID, name: String) -> FolioOpened {
        let pages = file.pages.enumerated().map { i, p in
            FolioPage(id: FolioPageID(i), origin: .source(source, index: i), size: p.size, rotation: p.rotation,
                      label: p.label, crop: p.crop, recognizedText: p.recognized.map {
                          FolioFakeLayout.text($0, pageHeight: p.size.height, origin: .recognized) })
        }
        let fields = file.fields.filter { pages.indices.contains($0.page.raw) }
        let annotations = file.annotations.map { a -> FolioAnnotation in var a = a; a.fromFile = true; return a }
        var state = FolioDocumentState(title: name, pages: pages, annotations: annotations, fields: fields,
                                       outline: file.outline.compactMap { o in
                                           pages.indices.contains(o.page) ? FolioOutlineItem(title: o.title, page: FolioPageID(o.page)) : nil },
                                       permissions: file.permissions)
        state.author = file.author
        state.scripts = file.scripts
        let noText = file.pages.enumerated().filter { $0.element.scanned && $0.element.recognized == nil }.map { FolioPageID($0.offset) }
        return FolioOpened(source: source, state: state, pagesWithoutText: noText)
    }
}

public struct FakePageImaging: PageImaging {
    public let sources: FakeDocumentSources
    public var unavailableHelp: String? { nil }
    public init(sources: FakeDocumentSources) { self.sources = sources }
    /// White page; each text line is a grey band, so a snapshot shows text rows.
    public func image(of page: FolioPage, maxPixels: Int) async -> FolioBitmap? {
        let fixture = await sources.fixturePage(page)
        guard page.origin == .blank || fixture != nil, maxPixels > 0 else { return nil }
        let d = page.displaySize
        let longSide = max(d.width, d.height)
        guard longSide > 0 else { return nil }
        let scale = Double(maxPixels) / longSide
        let w = max(1, Int(d.width * scale)), h = max(1, Int(d.height * scale))
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for i in (fixture?.lines ?? []).indices {
            let top = Int((FolioFakeLayout.margin + FolioFakeLayout.lineHeight * Double(i)) * scale)
            for y in top..<min(h, top + max(1, Int(FolioFakeLayout.glyphHeight * scale))) {
                for x in 0..<w { let o = (y * w + x) * 4; px[o] = 160; px[o + 1] = 160; px[o + 2] = 160 }
            }
        }
        return FolioBitmap(width: w, height: h, rgba: px)
    }
}

public struct FakePageTextReading: PageTextReading {
    public let sources: FakeDocumentSources
    public var unavailableHelp: String? { nil }
    public init(sources: FakeDocumentSources) { self.sources = sources }
    public func text(of page: FolioPage) async -> FolioPageText {
        if let recognized = page.recognizedText { return recognized }
        guard let p = await sources.fixturePage(page), !p.scanned else { return .empty }
        return FolioFakeLayout.text(p.lines, continued: p.continued, pageHeight: page.size.height, origin: .embedded)
    }
}

public struct FakeTextRecognizing: TextRecognizing {
    public let sources: FakeDocumentSources
    public var unavailableHelp: String? { nil }
    public var languages: [String] { ["en-US", "fr-FR", "de-DE"] }
    public init(sources: FakeDocumentSources) { self.sources = sources }
    public func recognize(_ page: FolioPage, languages: [String]) async throws(FolioRecognizeError) -> FolioPageText {
        guard let p = await sources.fixturePage(page) else { return FolioPageText(lines: [], origin: .recognized) }
        return FolioFakeLayout.text(p.lines, pageHeight: page.size.height, origin: .recognized)
    }
}

public struct FakeDocumentWriting: DocumentWriting {
    public let sources: FakeDocumentSources
    public var unavailableHelp: String? { nil }
    public init(sources: FakeDocumentSources) { self.sources = sources }
    /// Writes a fake file the fake opener reads back: pages in order with
    /// their lines, recognized text and pictures (a quarter when optimizing);
    /// Flatten drops fields and annotations and adds "[flattened n]" to the
    /// first page; passwords and restrictions as asked.
    public func write(_ doc: FolioDocumentState, options: FolioWriteOptions) async throws(FolioWriteError) -> Data {
        let permissions = options.permissions ?? doc.permissions
        if permissions.restrictions != doc.permissions.restrictions, !doc.permissions.ownerUnlocked { throw .restricted }
        var pages: [FolioFixtureFile.Page] = []
        for page in doc.pages {
            var out = FolioFixtureFile.Page(size: page.size, rotation: page.rotation, lines: [], label: page.label, crop: page.crop)
            if case .source(let src, _) = page.origin {
                guard let p = await sources.fixturePage(page) else { throw .sourceMissing(await sources.name(for: src) ?? src.raw) }
                out.lines = p.lines; out.continued = p.continued; out.scanned = p.scanned
                let shrink = options.optimizeImages && !p.optimized
                out.imageBytes = shrink ? p.imageBytes / 4 : p.imageBytes
                out.optimized = p.optimized || options.optimizeImages
            }
            if options.keepRecognizedText, let rec = page.recognizedText { out.recognized = rec.lines.map(\.text) }
            pages.append(out)
        }
        let index = Dictionary(uniqueKeysWithValues: doc.pages.enumerated().map { ($1.id, $0) })
        func reindexed(_ id: FolioPageID) -> FolioPageID { FolioPageID(index[id] ?? 0) }
        var fields = doc.fields.map { f -> FolioFormField in var f = f; f.page = reindexed(f.page); return f }
        var annotations = doc.annotations.map { a -> FolioAnnotation in
            var a = a; a.page = reindexed(a.page); a.fromFile = false; return a
        }
        if options.flatten, !pages.isEmpty {
            pages[0].lines.append("[flattened \(fields.count + annotations.count)]")
            fields = []; annotations = []
        }
        var restricted = permissions; restricted.ownerUnlocked = true
        let outline = doc.outline.compactMap { o in o.page.flatMap { index[$0] }.map { FolioFixtureFile.Outline(title: o.title, page: $0) } }
        let file = FolioFixtureFile(title: doc.title, author: doc.author, password: options.openPassword,
                                    ownerPassword: options.ownerPassword, permissions: restricted, scripts: doc.scripts,
                                    pages: pages, outline: outline, fields: fields, annotations: annotations)
        return file.data()
    }
}

public struct FakePageExporting: PageExporting {
    public let sources: FakeDocumentSources
    public var unavailableHelp: String? { nil }
    public init(sources: FakeDocumentSources) { self.sources = sources }
    /// "<FORMAT> <page id> <w>x<h> <annotation count>" per page; w and h at the asked ppi.
    public func images(of pages: [FolioPage], annotations: [FolioAnnotation], as format: FolioImageExport)
        async throws(FolioWriteError) -> [Data] {
        pages.map { p in
            let s = Double(format.ppi) / 72
            let d = p.displaySize
            let n = annotations.filter { $0.page == p.id }.count
            return Data("\(format.format.rawValue.uppercased()) \(p.id.raw) \(Int(d.width * s))x\(Int(d.height * s)) \(n)".utf8)
        }
    }
    /// Plain: the lines, pages split by a form feed. Rich text and
    /// word-processing: the same text after a "{\\rtf1" or "PK" marker.
    public func text(of doc: FolioDocumentState, as format: FolioTextFormat) async throws(FolioWriteError) -> Data {
        var parts: [String] = []
        for page in doc.pages {
            let fixtureLines = await sources.fixturePage(page)?.lines ?? []
            parts.append((page.recognizedText?.lines.map(\.text) ?? fixtureLines).joined(separator: "\n"))
        }
        let plain = parts.joined(separator: "\u{0C}")
        switch format {
        case .plain: return Data(plain.utf8)
        case .rtf: return Data(("{\\rtf1 " + plain + "}").utf8)
        case .docx: return Data(("PK" + plain).utf8)
        }
    }
}

public actor FakeSignatureStore: SignatureStoring {
    private var stored: [FolioSignature]
    private let failWith: FolioWriteError?
    public nonisolated var unavailableHelp: String? { nil }
    public init(_ signatures: [FolioSignature] = [], failWith: FolioWriteError? = nil) {
        self.stored = signatures; self.failWith = failWith
    }
    public func load() async -> [FolioSignature] { stored }
    public func save(_ signatures: [FolioSignature]) async throws(FolioWriteError) {
        if let failWith { throw failWith }
        stored = signatures
    }
}

// MARK: Pure fakes (reference behaviour; become the live types in W1)

public struct FakeTextFinding: TextFinding {
    public init() {}
    public func find(_ query: FolioSearchQuery, pages: [FolioPageID], text: [FolioPageID: FolioPageText]) -> [FolioSearchHit] {
        let needle = Array(query.matchCase ? query.text : query.text.lowercased())
        guard !needle.isEmpty else { return [] }
        var hits: [FolioSearchHit] = []
        for page in pages {
            for (li, line) in (text[page]?.lines ?? []).enumerated() {
                let hay = Array(query.matchCase ? line.text : line.text.lowercased())
                let original = Array(line.text)
                guard hay.count >= needle.count, hay.count == original.count else { continue }
                var i = 0
                while i + needle.count <= hay.count {
                    if Array(hay[i..<(i + needle.count)]) == needle,
                       !query.wholeWords || Self.isBoundary(hay, i - 1) && Self.isBoundary(hay, i + needle.count) {
                        let span = FolioTextSpan(page: page, line: li, start: i, end: i + needle.count)
                        let quad = Self.union(line.glyphRects, i, i + needle.count)
                        let lo = max(0, i - 30), hi = min(original.count, i + needle.count + 30)
                        hits.append(FolioSearchHit(span: span, quad: quad, context: String(original[lo..<hi])))
                        i += needle.count
                    } else { i += 1 }
                }
            }
        }
        return hits
    }
    static func isBoundary(_ c: [Character], _ i: Int) -> Bool {
        !c.indices.contains(i) || !(c[i].isLetter || c[i].isNumber)
    }
    static func union(_ rects: [FolioRect], _ start: Int, _ end: Int) -> FolioRect {
        let slice = rects.indices.contains(start) ? Array(rects[start..<min(end, rects.count)]) : []
        guard let f = slice.first, let l = slice.last else { return FolioRect(x: 0, y: 0, width: 0, height: 0) }
        return FolioRect(corner: FolioPoint(x: f.x, y: min(f.y, l.y)), FolioPoint(x: l.maxX, y: max(f.maxY, l.maxY)))
    }
}

public struct FakeTextSelecting: TextSelecting {
    public init() {}
    static let empty = FolioTextSelection(spans: [], quads: [], string: "")
    /// (line, character) nearest a point: the line whose box is closest in y,
    /// then the glyph whose center is closest in x.
    static func position(_ p: FolioPoint, _ text: FolioPageText) -> (Int, Int)? {
        let candidates = text.lines.enumerated().compactMap { i, l in l.bounds.map { (i, $0) } }
        guard let (li, _) = candidates.min(by: { abs(($0.1.y + $0.1.height / 2) - p.y) < abs(($1.1.y + $1.1.height / 2) - p.y) })
        else { return nil }
        let rects = text.lines[li].glyphRects
        let ci = rects.indices.min(by: { abs(rects[$0].x + rects[$0].width / 2 - p.x) < abs(rects[$1].x + rects[$1].width / 2 - p.x) })
        return ci.map { (li, $0) }
    }
    static func span(_ page: FolioPageID, _ text: FolioPageText, _ li: Int, _ s: Int, _ e: Int) -> FolioTextSelection {
        let chars = Array(text.lines[li].text)
        return FolioTextSelection(spans: [FolioTextSpan(page: page, line: li, start: s, end: e)],
                                  quads: [FakeTextFinding.union(text.lines[li].glyphRects, s, e)], string: String(chars[s..<e]))
    }
    public func select(from: FolioPoint, to: FolioPoint, on page: FolioPageID, text: FolioPageText) -> FolioTextSelection {
        guard let a = Self.position(from, text), let b = Self.position(to, text) else { return Self.empty }
        let (s, e) = a <= b ? (a, b) : (b, a)
        var spans: [FolioTextSpan] = [], quads: [FolioRect] = [], parts: [String] = []
        for li in s.0...e.0 {
            let chars = Array(text.lines[li].text)
            let start = li == s.0 ? s.1 : 0
            let end = li == e.0 ? min(chars.count, e.1 + 1) : chars.count
            guard start < end else { continue }
            spans.append(FolioTextSpan(page: page, line: li, start: start, end: end))
            quads.append(FakeTextFinding.union(text.lines[li].glyphRects, start, end))
            parts.append(String(chars[start..<end]))
        }
        return FolioTextSelection(spans: spans, quads: quads, string: parts.joined(separator: "\n"))
    }
    public func word(at point: FolioPoint, on page: FolioPageID, text: FolioPageText) -> FolioTextSelection {
        guard let (li, ci) = Self.position(point, text) else { return Self.empty }
        let chars = Array(text.lines[li].text)
        guard chars.indices.contains(ci), chars[ci].isLetter || chars[ci].isNumber else { return Self.empty }
        var s = ci, e = ci + 1
        while s > 0, chars[s - 1].isLetter || chars[s - 1].isNumber { s -= 1 }
        while e < chars.count, chars[e].isLetter || chars[e].isNumber { e += 1 }
        return Self.span(page, text, li, s, e)
    }
    public func line(at point: FolioPoint, on page: FolioPageID, text: FolioPageText) -> FolioTextSelection {
        guard let (li, _) = Self.position(point, text), !text.lines[li].text.isEmpty else { return Self.empty }
        return Self.span(page, text, li, 0, text.lines[li].text.count)
    }
    public func copyText(_ selection: FolioTextSelection, text: FolioPageText) -> String {
        var out = ""
        for span in selection.spans where text.lines.indices.contains(span.line) {
            let chars = Array(text.lines[span.line].text)
            guard span.start < span.end, span.end <= chars.count else { continue }
            out += String(chars[span.start..<span.end])
            if span != selection.spans.last { out += text.lines[span.line].endsParagraph ? "\n" : " " }
        }
        return out
    }
}

public struct FakeAnnotating: Annotating {
    public init() {}
    static func guardAllowed(_ doc: FolioDocumentState) throws(FolioEditError) {
        guard doc.permissions.canAnnotate else { throw .notAllowed("adding or changing markup") }
    }
    static func index(_ id: FolioAnnotationID, _ doc: FolioDocumentState) throws(FolioEditError) -> Int {
        guard let i = doc.annotations.firstIndex(where: { $0.id == id }) else { throw .noSuchAnnotation }
        return i
    }
    public func mark(_ selection: FolioTextSelection, style: FolioMarkupStyle, color: FolioColor,
                     in doc: inout FolioDocumentState) throws(FolioEditError) -> [FolioAnnotationID] {
        try Self.guardAllowed(doc)
        guard !selection.isEmpty else { throw .emptySelection }
        let pages = Array(Set(selection.spans.map(\.page))).sorted()
        var ids: [FolioAnnotationID] = []
        var copy = doc
        for page in pages {
            guard copy.page(page) != nil else { throw .noSuchPage }
            let quads = zip(selection.spans, selection.quads).filter { $0.0.page == page }.map(\.1)
            guard let first = quads.first else { continue }
            let box = quads.dropFirst().reduce(first) { r, q in
                FolioRect(corner: FolioPoint(x: min(r.x, q.x), y: min(r.y, q.y)), FolioPoint(x: max(r.maxX, q.maxX), y: max(r.maxY, q.maxY)))
            }
            let id = FolioAnnotationID(copy.nextAnnotationID); copy.nextAnnotationID += 1
            copy.annotations.append(FolioAnnotation(id: id, page: page, rect: box, color: color,
                                                    body: .markup(style, quads: quads, text: selection.string)))
            ids.append(id)
        }
        doc = copy
        return ids
    }
    public func add(_ body: FolioAnnotationBody, rect: FolioRect, color: FolioColor, on page: FolioPageID,
                    in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioAnnotationID {
        try Self.guardAllowed(doc)
        guard doc.page(page) != nil else { throw .noSuchPage }
        if case .freeText(let s) = body, s.folioTrimmed.isEmpty { throw .invalidValue("Type some text for the text box.") }
        let id = FolioAnnotationID(doc.nextAnnotationID)
        doc.nextAnnotationID += 1
        doc.annotations.append(FolioAnnotation(id: id, page: page, rect: rect, color: color, body: body))
        return id
    }
    public func move(_ id: FolioAnnotationID, dx: Double, dy: Double, in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.guardAllowed(doc)
        let i = try Self.index(id, doc)
        var a = doc.annotations[i]
        a.rect = a.rect.offsetBy(dx: dx, dy: dy)
        switch a.body {
        case .markup: throw .invalidValue("Highlights stay on their text. Delete it and mark the text again.")
        case .ink(let strokes): a.body = .ink(strokes.map { $0.map { FolioPoint(x: $0.x + dx, y: $0.y + dy) } })
        default: break
        }
        doc.annotations[i] = a
    }
    public func setRect(_ id: FolioAnnotationID, to rect: FolioRect, in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.guardAllowed(doc)
        let i = try Self.index(id, doc)
        guard rect.width >= 4, rect.height >= 4 else { throw .invalidValue("That's too small to see. Make it at least 4 points.") }
        if case .markup = doc.annotations[i].body { throw .invalidValue("Highlights stay on their text.") }
        doc.annotations[i].rect = rect
    }
    public func setColor(_ id: FolioAnnotationID, to color: FolioColor, in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.guardAllowed(doc)
        let i = try Self.index(id, doc)
        doc.annotations[i].color = color
    }
    public func setStyle(_ id: FolioAnnotationID, to style: FolioMarkStyle, in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.guardAllowed(doc)
        let i = try Self.index(id, doc)
        doc.annotations[i].style = FolioMarkStyle(fontSize: style.fontSize, alignment: style.alignment,
                                                  lineWidth: style.lineWidth, opacity: style.opacity)
    }
    public func setText(_ id: FolioAnnotationID, to text: String, in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.guardAllowed(doc)
        let i = try Self.index(id, doc)
        switch doc.annotations[i].body {
        case .note: doc.annotations[i].body = .note(text)
        case .freeText:
            guard !text.folioTrimmed.isEmpty else { throw .invalidValue("Type some text for the text box.") }
            doc.annotations[i].body = .freeText(text)
        default: doc.annotations[i].comment = text.isEmpty ? nil : text
        }
    }
    public func delete(_ ids: [FolioAnnotationID], in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.guardAllowed(doc)
        for id in ids { _ = try Self.index(id, doc) }
        let gone = Set(ids)
        doc.annotations.removeAll { gone.contains($0.id) }
    }
    public func hit(_ point: FolioPoint, on page: FolioPageID, in doc: FolioDocumentState) -> FolioAnnotationID? {
        doc.annotations.last { a in
            a.page == page && FolioRect(x: a.rect.x - 4, y: a.rect.y - 4, width: a.rect.width + 8, height: a.rect.height + 8).contains(point)
        }?.id
    }
}

public struct FakeFormFilling: FormFilling {
    public init() {}
    public func set(_ field: FolioFieldID, to value: FolioFieldValue, in doc: inout FolioDocumentState) throws(FolioEditError) {
        guard doc.permissions.canFillForms else { throw .notAllowed("filling in this form") }
        guard let i = doc.fields.firstIndex(where: { $0.id == field }) else { throw .noSuchField }
        let f = doc.fields[i]
        guard !f.isReadOnly else { throw .readOnlyField(f.label) }
        switch (f.kind, value) {
        case (_, .empty): doc.fields[i].value = .empty
        case (.text(let multiline, let maxLength), .text(let s)):
            if !multiline, s.contains("\n") { throw .invalidValue("This field takes one line.") }
            if let maxLength, s.count > maxLength { throw .invalidValue("This field takes at most \(maxLength) characters.") }
            doc.fields[i].value = .text(s)
        case (.checkbox, .checked(let on)): doc.fields[i].value = .checked(on)
        case (.radio(let group, let option), .checked(true)):
            for j in doc.fields.indices {
                if case .radio(group, let o) = doc.fields[j].kind { doc.fields[j].value = .checked(o == option) }
            }
        case (.radio, .checked(false)): doc.fields[i].value = .checked(false)
        case (.choice(let options, let editable), .option(let o)):
            guard editable || options.contains(o) else { throw .invalidValue("Pick one of the listed choices.") }
            doc.fields[i].value = .option(o)
        case (.signature, _): throw .invalidValue("Place a signature in this field with the Sign tool.")
        default: throw .invalidValue("That value doesn't fit this field.")
        }
    }
    static func group(_ f: FolioFormField) -> String? { if case .radio(let g, _) = f.kind { return g }; return nil }
    /// Tab stops: fillable, non-signature fields in reading order; a radio
    /// group appears once, as its checked button or else its first.
    static func order(_ doc: FolioDocumentState) -> [FolioFormField] {
        let pageIndex = Dictionary(uniqueKeysWithValues: doc.pages.enumerated().map { ($1.id, $0) })
        let sorted = doc.fields.filter { !$0.isReadOnly && $0.kind != .signature && pageIndex[$0.page] != nil }.sorted { a, b in
            let pa = pageIndex[a.page] ?? 0, pb = pageIndex[b.page] ?? 0
            if pa != pb { return pa < pb }
            if abs(a.rect.maxY - b.rect.maxY) > 2 { return a.rect.maxY > b.rect.maxY }
            return a.rect.x < b.rect.x
        }
        var seen = Set<String>(), out: [FolioFormField] = []
        for f in sorted {
            guard let g = group(f) else { out.append(f); continue }
            guard !seen.contains(g) else { continue }
            seen.insert(g)
            out.append(sorted.first { group($0) == g && $0.value == .checked(true) } ?? f)
        }
        return out
    }
    public func next(after field: FolioFieldID?, backward: Bool, in doc: FolioDocumentState) -> FolioFieldID? {
        let order = Self.order(doc)
        guard !order.isEmpty else { return nil }
        let current = field.flatMap { id in doc.fields.first { $0.id == id } }
        guard let current, let i = order.firstIndex(where: { $0.id == current.id || (Self.group($0) != nil && Self.group($0) == Self.group(current)) })
        else { return (backward ? order.last : order.first)?.id }
        let n = order.count
        return order[(i + (backward ? n - 1 : 1)) % n].id
    }
    public func missingRequired(in doc: FolioDocumentState) -> [FolioFieldID] {
        Self.order(doc).filter { f in
            guard f.isRequired else { return false }
            if let g = Self.group(f) { return !doc.fields.contains { Self.group($0) == g && $0.value == .checked(true) } }
            switch f.value { case .empty, .text(""), .checked(false): return true; default: return false }
        }.map(\.id)
    }
    public func clear(in doc: inout FolioDocumentState) throws(FolioEditError) {
        guard doc.permissions.canFillForms else { throw .notAllowed("filling in this form") }
        for i in doc.fields.indices where !doc.fields[i].isReadOnly { doc.fields[i].value = .empty }
    }
}

public struct FakeSigning: Signing {
    public init() {}
    public func make(strokes: [[FolioPoint]], isInitials: Bool, id: FolioSignatureID) throws(FolioEditError) -> FolioSignature {
        let all = strokes.flatMap { $0 }
        guard all.count >= 2, let minX = all.map(\.x).min(), let maxX = all.map(\.x).max(),
              let minY = all.map(\.y).min(), let maxY = all.map(\.y).max(), maxX - minX > 0 || maxY - minY > 0
        else { throw .invalidValue("Draw your signature in the box first.") }
        let side = max(maxX - minX, maxY - minY)
        let unit = strokes.map { $0.map { FolioPoint(x: ($0.x - minX) / side, y: ($0.y - minY) / side) } }
        let aspect = max(maxX - minX, 1) / max(maxY - minY, 1)
        return FolioSignature(id: id, kind: .drawn(unit), isInitials: isInitials, aspect: aspect)
    }
    public func make(typed name: String, isInitials: Bool, id: FolioSignatureID) throws(FolioEditError) -> FolioSignature {
        let trimmed = name.folioTrimmed
        guard !trimmed.isEmpty else { throw .invalidValue("Type your name first.") }
        return FolioSignature(id: id, kind: .typed(trimmed), isInitials: isInitials, aspect: max(1.5, Double(trimmed.count) * 0.55))
    }
    public func make(picture: FolioBitmap, isInitials: Bool, id: FolioSignatureID) throws(FolioEditError) -> FolioSignature {
        let w = picture.width, h = picture.height
        guard w > 0, h > 0, picture.rgba.count == w * h * 4 else { throw .invalidValue("That picture couldn't be read.") }
        var px = picture.rgba
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                let o = (y * w + x) * 4
                let lum = (0.2126 * Double(px[o]) + 0.7152 * Double(px[o + 1]) + 0.0722 * Double(px[o + 2])) / 255
                if lum >= 0.85 || px[o + 3] == 0 { px[o + 3] = 0 } else {
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { throw .invalidValue("That picture has no signature in it. Pick one with dark ink on a light background.") }
        let cw = maxX - minX + 1, ch = maxY - minY + 1
        var out = [UInt8](repeating: 0, count: cw * ch * 4)
        for y in 0..<ch {
            for x in 0..<cw {
                let s = ((y + minY) * w + (x + minX)) * 4, d = (y * cw + x) * 4
                out[d] = px[s]; out[d + 1] = px[s + 1]; out[d + 2] = px[s + 2]; out[d + 3] = px[s + 3]
            }
        }
        return FolioSignature(id: id, kind: .picture(FolioBitmap(width: cw, height: ch, rgba: out)), isInitials: isInitials,
                              aspect: Double(cw) / Double(ch))
    }
    public func place(_ signature: FolioSignature, at point: FolioPoint, width: Double, on page: FolioPageID,
                      in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioAnnotationID {
        guard doc.permissions.canAnnotate || doc.permissions.canFillForms else { throw .notAllowed("signing") }
        guard doc.page(page) != nil else { throw .noSuchPage }
        let rect: FolioRect
        if let field = doc.fields.first(where: { $0.page == page && $0.rect.contains(point) && $0.kind == .signature }) {
            let h = min(field.rect.height, field.rect.width / signature.aspect)
            let w = h * signature.aspect
            rect = FolioRect(x: field.rect.x + (field.rect.width - w) / 2, y: field.rect.y + (field.rect.height - h) / 2, width: w, height: h)
        } else {
            let w = max(24, width), h = w / signature.aspect
            rect = FolioRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h)
        }
        let id = FolioAnnotationID(doc.nextAnnotationID)
        doc.nextAnnotationID += 1
        doc.annotations.append(FolioAnnotation(id: id, page: page, rect: rect, color: .ink, body: .signature(signature.id)))
        return id
    }
}

public struct FakePageOrganizing: PageOrganizing {
    public init() {}
    static func assemble(_ doc: FolioDocumentState) throws(FolioEditError) {
        guard doc.permissions.canAssemble else { throw .notAllowed("changing its pages") }
    }
    static func check(_ ids: [FolioPageID], _ doc: FolioDocumentState) throws(FolioEditError) {
        guard !ids.isEmpty else { throw .noSuchPage }
        for id in ids where doc.page(id) == nil { throw .noSuchPage }
    }
    public func move(_ pages: [FolioPageID], to index: Int, in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.assemble(doc); try Self.check(pages, doc)
        let set = Set(pages)
        let moving = doc.pages.filter { set.contains($0.id) }
        var rest = doc.pages.filter { !set.contains($0.id) }
        rest.insert(contentsOf: moving, at: min(max(0, index), rest.count))
        doc.pages = rest
    }
    public func rotate(_ pages: [FolioPageID], clockwise: Bool, in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.check(pages, doc)
        let set = Set(pages)
        for i in doc.pages.indices where set.contains(doc.pages[i].id) {
            doc.pages[i].rotation = doc.pages[i].rotation.turned(clockwise: clockwise)
        }
    }
    public func delete(_ pages: [FolioPageID], in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.assemble(doc); try Self.check(pages, doc)
        let set = Set(pages)
        guard doc.pages.contains(where: { !set.contains($0.id) }) else { throw .lastPage }
        doc.pages.removeAll { set.contains($0.id) }
        doc.annotations.removeAll { set.contains($0.page) }
        doc.fields.removeAll { set.contains($0.page) }
    }
    public func combine(_ files: [FolioOpened], title: String) throws(FolioEditError) -> FolioDocumentState {
        guard let first = files.first else { throw .pageRange("Pick at least one PDF to combine.") }
        var doc = first.state
        doc.title = title
        for other in files.dropFirst() { _ = try insert(other, at: doc.pages.count, in: &doc) }
        return doc
    }
    public func insert(_ other: FolioOpened, at index: Int, in doc: inout FolioDocumentState) throws(FolioEditError) -> [FolioPageID] {
        try Self.assemble(doc)
        var map: [FolioPageID: FolioPageID] = [:]
        var added: [FolioPage] = []
        for p in other.state.pages {
            let id = FolioPageID(doc.nextPageID); doc.nextPageID += 1
            map[p.id] = id
            var q = p; q.id = id; added.append(q)
        }
        doc.pages.insert(contentsOf: added, at: min(max(0, index), doc.pages.count))
        let taken = Set(doc.fields.map(\.id.name))
        for f in other.state.fields {
            guard let page = map[f.page] else { continue }
            var g = f; g.page = page
            if taken.contains(g.id.name) { g.id = FolioFieldID(g.id.name + " 2") }
            doc.fields.append(g)
        }
        for a in other.state.annotations {
            guard let page = map[a.page] else { continue }
            var b = a; b.page = page; b.id = FolioAnnotationID(doc.nextAnnotationID); doc.nextAnnotationID += 1
            doc.annotations.append(b)
        }
        return added.map(\.id)
    }
    public func insertBlank(size: FolioSize, at index: Int, in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioPageID {
        try Self.assemble(doc)
        guard size.width >= 72, size.height >= 72, size.width <= 14_400, size.height <= 14_400 else {
            throw .invalidValue("A page must be between 1 and 200 inches on each side.")
        }
        let id = FolioPageID(doc.nextPageID); doc.nextPageID += 1
        doc.pages.insert(FolioPage(id: id, origin: .blank, size: size), at: min(max(0, index), doc.pages.count))
        return id
    }
    public func crop(_ pages: [FolioPageID], to rect: FolioRect?, in doc: inout FolioDocumentState) throws(FolioEditError) {
        try Self.check(pages, doc)
        if let r = rect, r.width < 72 || r.height < 72 {
            throw .invalidValue("Keep at least 1 inch of the page on each side.")
        }
        let set = Set(pages)
        for i in doc.pages.indices where set.contains(doc.pages[i].id) {
            guard let r = rect else { doc.pages[i].crop = nil; continue }
            let s = doc.pages[i].size
            let x = min(max(0, r.x), s.width - 72), y = min(max(0, r.y), s.height - 72)
            doc.pages[i].crop = FolioRect(x: x, y: y, width: min(r.width, s.width - x), height: min(r.height, s.height - y))
        }
    }
    public func extract(_ pages: [FolioPageID], from doc: FolioDocumentState) throws(FolioEditError) -> FolioDocumentState {
        try Self.check(pages, doc)
        let set = Set(pages)
        var out = doc
        out.pages = doc.pages.filter { set.contains($0.id) }
        out.annotations = doc.annotations.filter { set.contains($0.page) }
        out.fields = doc.fields.filter { set.contains($0.page) }
        out.outline = []
        return out
    }
    public func split(_ doc: FolioDocumentState, after: [Int]) throws(FolioEditError) -> [FolioDocumentState] {
        let cuts = Array(Set(after)).sorted()
        guard let first = cuts.first, let last = cuts.last, first >= 1, last < doc.pages.count else {
            throw .pageRange("Split after a page from 1 to \(max(1, doc.pages.count - 1)).")
        }
        var parts: [FolioDocumentState] = []
        var start = 0
        for end in cuts + [doc.pages.count] {
            var part = try extract(doc.pages[start..<end].map(\.id), from: doc)
            part.title = "\(doc.title) (part \(parts.count + 1))"
            parts.append(part)
            start = end
        }
        return parts
    }
    public func parseRange(_ text: String, pageCount: Int) throws(FolioEditError) -> [Int] {
        var out = Set<Int>()
        let pieces = text.split(separator: ",").map { String($0).folioTrimmed }.filter { !$0.isEmpty }
        guard !pieces.isEmpty else { throw .pageRange("Type pages like 1-3, 5.") }
        for piece in pieces {
            let ends = piece.split(separator: "-", omittingEmptySubsequences: false).map { String($0).folioTrimmed }
            guard ends.count <= 2, let lo = Int(ends[0].isEmpty ? "1" : ends[0]) else {
                throw .pageRange("\"\(piece)\" isn't a page or a range. Type pages like 1-3, 5.")
            }
            let hi = ends.count == 2 ? (ends[1].isEmpty ? pageCount : Int(ends[1]) ?? -1) : lo
            guard lo >= 1, hi <= pageCount, lo <= hi else {
                throw .pageRange("This document has pages 1 to \(pageCount).")
            }
            out.formUnion(lo...hi)
        }
        return out.sorted()
    }
}

public struct FakeDocumentHistory: DocumentHistory {
    public init() {}
    public func record(_ before: FolioDocumentState, name: String, coalesceKey: String?, in history: inout FolioHistory) {
        history.redoSteps.removeAll()
        if history.coalescing, let key = coalesceKey, history.undoSteps.last?.coalesceKey == key { return }
        history.undoSteps.append(.init(name: name, state: before, coalesceKey: coalesceKey))
        if history.undoSteps.count > history.limit { history.undoSteps.removeFirst(history.undoSteps.count - history.limit) }
        history.coalescing = coalesceKey != nil
    }
    public func endCoalescing(_ history: inout FolioHistory) { history.coalescing = false }
    public func undo(_ current: FolioDocumentState, in history: inout FolioHistory) -> FolioDocumentState? {
        guard let step = history.undoSteps.popLast() else { return nil }
        history.redoSteps.append(.init(name: step.name, state: current, coalesceKey: nil))
        history.coalescing = false
        return step.state
    }
    public func redo(_ current: FolioDocumentState, in history: inout FolioHistory) -> FolioDocumentState? {
        guard let step = history.redoSteps.popLast() else { return nil }
        history.undoSteps.append(.init(name: step.name, state: current, coalesceKey: nil))
        history.coalescing = false
        return step.state
    }
}
