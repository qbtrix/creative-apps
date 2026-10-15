// Contracts/FolioValues.swift: the value types every Folio contract speaks.
// Linux-safe, Foundation only, no engine import. The Model owns the edits
// (page order, rotation, annotations, field values, signatures placed); the
// opened PDF bytes are read-only sources that only the live macOS types read.
// Coordinates are PDF points in page space: origin bottom-left of the page's
// crop box before rotation, y up (Apple docs: PDFPage, "Page coordinates").
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: Geometry

public struct FolioPoint: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct FolioSize: Hashable, Codable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    /// US Letter and A4, the two sizes New Blank Page offers.
    public static let letter = FolioSize(width: 612, height: 792)
    public static let a4 = FolioSize(width: 595.28, height: 841.89)
}

public struct FolioRect: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    /// The rectangle spanned by two corners in any order.
    public init(corner a: FolioPoint, _ b: FolioPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public func contains(_ p: FolioPoint) -> Bool { p.x >= x && p.x <= maxX && p.y >= y && p.y <= maxY }
    public func intersects(_ o: FolioRect) -> Bool { x < o.maxX && o.x < maxX && y < o.maxY && o.y < maxY }
    public func offsetBy(dx: Double, dy: Double) -> FolioRect { FolioRect(x: x + dx, y: y + dy, width: width, height: height) }
}

/// Quarter turns clockwise, as PDF's /Rotate stores them.
public enum FolioRotation: Int, CaseIterable, Codable, Sendable {
    case r0 = 0, r90 = 90, r180 = 180, r270 = 270
    public func turned(clockwise: Bool) -> FolioRotation {
        let step = clockwise ? 90 : 270
        return FolioRotation(rawValue: (rawValue + step) % 360) ?? .r0
    }
}

/// sRGB, 0...1 per channel. Document content, so not a SuiteUI token.
public struct FolioColor: Hashable, Codable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.unit(red); self.green = Self.unit(green)
        self.blue = Self.unit(blue); self.alpha = Self.unit(alpha)
    }
    static func unit(_ v: Double) -> Double { v.isFinite ? Swift.min(1, Swift.max(0, v)) : 0 }
    public static let highlightYellow = FolioColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.45)
    public static let ink = FolioColor(red: 0.07, green: 0.16, blue: 0.45)
    public static let red = FolioColor(red: 0.85, green: 0.1, blue: 0.1)
    public static let black = FolioColor(red: 0, green: 0, blue: 0)
}

// MARK: Sources and pages

/// One opened file. Folio keeps the bytes it opened and never rewrites them in
/// place; Save writes a new file from the sources plus the edits.
public struct FolioSourceID: Hashable, Codable, Sendable {
    public var raw: String
    public init(_ raw: String) { self.raw = raw }
}

public struct FolioPageID: Hashable, Codable, Sendable, Comparable {
    public var raw: Int
    public init(_ raw: Int) { self.raw = raw }
    public static func < (a: FolioPageID, b: FolioPageID) -> Bool { a.raw < b.raw }
}

/// Where a page's pixels come from: a page of an opened source, or a blank
/// page Folio made.
public enum FolioPageOrigin: Hashable, Codable, Sendable {
    case source(FolioSourceID, index: Int)
    case blank
}

public struct FolioPage: Identifiable, Hashable, Codable, Sendable {
    public var id: FolioPageID
    public var origin: FolioPageOrigin
    /// The crop box size before rotation, in points.
    public var size: FolioSize
    public var rotation: FolioRotation
    /// The printed page label when the file has one ("iv", "A-3"), else nil.
    public var label: String?
    /// The visible part of the page after Crop, in page space; nil shows it all.
    public var crop: FolioRect?
    /// Text Folio recognized on this page (OCR), part of the document so it
    /// undoes, saves as an invisible text layer and reopens; nil when none.
    public var recognizedText: FolioPageText?
    public init(id: FolioPageID, origin: FolioPageOrigin, size: FolioSize,
                rotation: FolioRotation = .r0, label: String? = nil, crop: FolioRect? = nil,
                recognizedText: FolioPageText? = nil) {
        self.id = id; self.origin = origin; self.size = size; self.rotation = rotation
        self.label = label; self.crop = crop; self.recognizedText = recognizedText
    }
    /// The size as shown, after crop and rotation.
    public var displaySize: FolioSize {
        let s = crop.map { FolioSize(width: $0.width, height: $0.height) } ?? size
        return rotation == .r90 || rotation == .r270 ? FolioSize(width: s.height, height: s.width) : s
    }
}

// MARK: Page text

/// One line of text on a page, as the source's text layer (or OCR) gives it.
/// `glyphRects[i]` is the box of the i-th Character of `text`.
public struct FolioTextLine: Hashable, Codable, Sendable {
    public var text: String
    public var glyphRects: [FolioRect]
    /// True when a paragraph ends after this line: Copy keeps a line break
    /// here and joins other lines with a space.
    public var endsParagraph: Bool
    public init(text: String, glyphRects: [FolioRect], endsParagraph: Bool = true) {
        self.text = text; self.glyphRects = glyphRects; self.endsParagraph = endsParagraph
    }
    public var bounds: FolioRect? {
        guard let first = glyphRects.first else { return nil }
        return glyphRects.dropFirst().reduce(first) { r, g in
            FolioRect(corner: FolioPoint(x: min(r.x, g.x), y: min(r.y, g.y)),
                      FolioPoint(x: max(r.maxX, g.maxX), y: max(r.maxY, g.maxY)))
        }
    }
}

public enum FolioTextOrigin: String, Codable, Sendable {
    case embedded   // the PDF's own text layer
    case recognized // made by text recognition (OCR)
    case none       // no text layer: a scan that was never recognized
}

public struct FolioPageText: Hashable, Codable, Sendable {
    public var lines: [FolioTextLine]
    public var origin: FolioTextOrigin
    public init(lines: [FolioTextLine], origin: FolioTextOrigin) { self.lines = lines; self.origin = origin }
    public static let empty = FolioPageText(lines: [], origin: .none)
}

/// A run of selected characters on one page: the line and the Character
/// offsets [start, end) inside it.
public struct FolioTextSpan: Hashable, Codable, Sendable {
    public var page: FolioPageID
    public var line: Int
    public var start: Int
    public var end: Int
    public init(page: FolioPageID, line: Int, start: Int, end: Int) {
        self.page = page; self.line = line; self.start = start; self.end = end
    }
}

public struct FolioTextSelection: Hashable, Codable, Sendable {
    public var spans: [FolioTextSpan]
    /// One rectangle per span, in page space: what a highlight covers.
    public var quads: [FolioRect]
    public var string: String
    public init(spans: [FolioTextSpan], quads: [FolioRect], string: String) {
        self.spans = spans; self.quads = quads; self.string = string
    }
    public var isEmpty: Bool { spans.isEmpty }
}

// MARK: Search

public struct FolioSearchQuery: Hashable, Sendable {
    public var text: String
    public var matchCase: Bool
    public var wholeWords: Bool
    public init(text: String, matchCase: Bool = false, wholeWords: Bool = false) {
        self.text = text; self.matchCase = matchCase; self.wholeWords = wholeWords
    }
}

public struct FolioSearchHit: Hashable, Sendable {
    public var span: FolioTextSpan
    public var quad: FolioRect
    /// Up to 30 Characters either side, for the results list.
    public var context: String
    public init(span: FolioTextSpan, quad: FolioRect, context: String) {
        self.span = span; self.quad = quad; self.context = context
    }
}

// MARK: Annotations

public struct FolioAnnotationID: Hashable, Codable, Sendable {
    public var raw: Int
    public init(_ raw: Int) { self.raw = raw }
}

public enum FolioMarkupStyle: String, CaseIterable, Codable, Sendable {
    case highlight, underline, strikeOut
}

public enum FolioShape: String, CaseIterable, Codable, Sendable {
    case rectangle, ellipse, line, arrow
}

public enum FolioTextAlignment: String, CaseIterable, Codable, Sendable { case leading, center, trailing }

/// How a mark draws, beyond its colour: what the inspector edits.
public struct FolioMarkStyle: Hashable, Codable, Sendable {
    /// Text boxes: 6...72 pt.
    public var fontSize: Double
    public var alignment: FolioTextAlignment
    /// Pen, shapes, underline and strike-out: 0.5...12 pt.
    public var lineWidth: Double
    /// 0.1...1.
    public var opacity: Double
    public init(fontSize: Double = 12, alignment: FolioTextAlignment = .leading, lineWidth: Double = 2, opacity: Double = 1) {
        self.fontSize = Swift.min(72, Swift.max(6, fontSize.isFinite ? fontSize : 12))
        self.alignment = alignment
        self.lineWidth = Swift.min(12, Swift.max(0.5, lineWidth.isFinite ? lineWidth : 2))
        self.opacity = Swift.min(1, Swift.max(0.1, opacity.isFinite ? opacity : 1))
    }
    public static let standard = FolioMarkStyle()
}

public enum FolioAnnotationBody: Hashable, Codable, Sendable {
    /// Text markup over selected text; `quads` from a FolioTextSelection.
    case markup(FolioMarkupStyle, quads: [FolioRect], text: String)
    /// A note: an icon on the page whose text opens in a popover.
    case note(String)
    /// Text drawn on the page (type on a flat form, add a label).
    case freeText(String)
    /// Freehand pen strokes.
    case ink([[FolioPoint]])
    case shape(FolioShape)
    /// A placed signature or initials from the library.
    case signature(FolioSignatureID)
    /// A placed image (PNG bytes), for "add an image".
    case image(Data)
}

public struct FolioAnnotation: Identifiable, Hashable, Codable, Sendable {
    public var id: FolioAnnotationID
    public var page: FolioPageID
    public var rect: FolioRect
    public var color: FolioColor
    public var style: FolioMarkStyle
    public var body: FolioAnnotationBody
    /// The reply or comment typed on a markup; nil when none.
    public var comment: String?
    /// True for annotations the opened file already had.
    public var fromFile: Bool
    public init(id: FolioAnnotationID, page: FolioPageID, rect: FolioRect, color: FolioColor,
                style: FolioMarkStyle = .standard, body: FolioAnnotationBody, comment: String? = nil,
                fromFile: Bool = false) {
        self.id = id; self.page = page; self.rect = rect; self.color = color; self.style = style
        self.body = body; self.comment = comment; self.fromFile = fromFile
    }
}

// MARK: Forms

public struct FolioFieldID: Hashable, Codable, Sendable {
    /// The field's fully qualified name in the file (unique per document).
    public var name: String
    public init(_ name: String) { self.name = name }
}

public enum FolioFieldKind: Hashable, Codable, Sendable {
    case text(multiline: Bool, maxLength: Int?)
    case checkbox
    /// One button of a radio group; `group` is shared, `option` is this button's export value.
    case radio(group: String, option: String)
    case choice(options: [String], editable: Bool)
    /// An unsigned signature field: Folio places a signature appearance in it.
    case signature
}

public enum FolioFieldValue: Hashable, Codable, Sendable {
    case empty
    case text(String)
    case checked(Bool)
    case option(String)
}

public struct FolioFormField: Identifiable, Hashable, Codable, Sendable {
    public var id: FolioFieldID
    /// What a person calls the field: the form's alternate name (/TU) when it
    /// has one, else the text line just left of or above the field, else the
    /// last part of the field name. Used in messages and as the VoiceOver label.
    public var label: String
    public var page: FolioPageID
    public var rect: FolioRect
    public var kind: FolioFieldKind
    public var value: FolioFieldValue
    public var isReadOnly: Bool
    public var isRequired: Bool
    /// The tooltip the form author wrote, shown as the field's help.
    public var tooltip: String?
    public init(id: FolioFieldID, label: String, page: FolioPageID, rect: FolioRect, kind: FolioFieldKind,
                value: FolioFieldValue = .empty, isReadOnly: Bool = false, isRequired: Bool = false,
                tooltip: String? = nil) {
        self.id = id; self.label = label; self.page = page; self.rect = rect; self.kind = kind; self.value = value
        self.isReadOnly = isReadOnly; self.isRequired = isRequired; self.tooltip = tooltip
    }
}

// MARK: Signatures

public struct FolioSignatureID: Hashable, Codable, Sendable {
    public var raw: String
    public init(_ raw: String) { self.raw = raw }
}

public enum FolioSignatureKind: Hashable, Codable, Sendable {
    /// Strokes in a unit box (0...1 both ways), as drawn on the pad.
    case drawn([[FolioPoint]])
    /// A typed name, drawn later in a script face.
    case typed(String)
    /// A picture of a signature (PNG), background already removed.
    case image(Data)
}

public struct FolioSignature: Identifiable, Hashable, Codable, Sendable {
    public var id: FolioSignatureID
    public var kind: FolioSignatureKind
    public var isInitials: Bool
    /// Width over height of the signature's ink box, so placement keeps it.
    public var aspect: Double
    public init(id: FolioSignatureID, kind: FolioSignatureKind, isInitials: Bool, aspect: Double) {
        self.id = id; self.kind = kind; self.isInitials = isInitials
        self.aspect = aspect.isFinite && aspect > 0 ? aspect : 3
    }
}

// MARK: Outline and document

public struct FolioOutlineItem: Hashable, Codable, Sendable {
    public var title: String
    public var page: FolioPageID?
    public var children: [FolioOutlineItem]
    public init(title: String, page: FolioPageID?, children: [FolioOutlineItem] = []) {
        self.title = title; self.page = page; self.children = children
    }
}

/// What the file's owner allows (PDF permissions), as opened.
public struct FolioPermissions: Hashable, Codable, Sendable {
    public var canAnnotate: Bool
    public var canFillForms: Bool
    public var canAssemble: Bool
    public var canCopy: Bool
    public var canPrint: Bool
    /// True when the file has no owner restrictions or was opened with the
    /// owner password; only then may Save change or drop the restrictions.
    public var ownerUnlocked: Bool
    public init(canAnnotate: Bool = true, canFillForms: Bool = true, canAssemble: Bool = true,
                canCopy: Bool = true, canPrint: Bool = true, ownerUnlocked: Bool = true) {
        self.canAnnotate = canAnnotate; self.canFillForms = canFillForms
        self.canAssemble = canAssemble; self.canCopy = canCopy; self.canPrint = canPrint
        self.ownerUnlocked = ownerUnlocked
    }
    public var restrictions: [Bool] { [canAnnotate, canFillForms, canAssemble, canCopy, canPrint] }
    public static let all = FolioPermissions()
}

/// The whole editable document: a value, so undo is a stack of these and
/// every edit is testable on Linux.
public struct FolioDocumentState: Hashable, Codable, Sendable {
    public var title: String
    /// Info dictionary author; empty when the file has none.
    public var author: String = ""
    public var pages: [FolioPage]
    public var annotations: [FolioAnnotation]
    public var fields: [FolioFormField]
    public var outline: [FolioOutlineItem]
    public var permissions: FolioPermissions
    /// Form scripts or XFA the file carries; Folio never runs them and says so.
    public var scripts: FolioScriptKind = .none
    public var nextPageID: Int
    public var nextAnnotationID: Int
    public init(title: String, pages: [FolioPage], annotations: [FolioAnnotation] = [],
                fields: [FolioFormField] = [], outline: [FolioOutlineItem] = [],
                permissions: FolioPermissions = .all) {
        self.title = title; self.pages = pages; self.annotations = annotations
        self.fields = fields; self.outline = outline; self.permissions = permissions
        self.nextPageID = (pages.map(\.id.raw).max() ?? -1) + 1
        self.nextAnnotationID = (annotations.map(\.id.raw).max() ?? -1) + 1
    }
    public func page(_ id: FolioPageID) -> FolioPage? { pages.first { $0.id == id } }
    public func index(of id: FolioPageID) -> Int? { pages.firstIndex { $0.id == id } }
}

public enum FolioScriptKind: String, Codable, Sendable { case none, javascript, xfa }

/// A file New from Images left out, and why (a sentence).
public struct FolioSkipped: Hashable, Sendable {
    public var name: String
    public var reason: String
    public init(name: String, reason: String) { self.name = name; self.reason = reason }
}

/// One picked image for New from Images.
public struct FolioImageInput: Sendable {
    public var name: String
    public var data: Data
    public init(name: String, data: Data) { self.name = name; self.data = data }
}

/// What opening a file gives the Model. The opener has already registered
/// the bytes in `DocumentSources` under `source`.
public struct FolioOpened: Sendable {
    public var source: FolioSourceID
    public var state: FolioDocumentState
    /// Pages whose text layer is missing: the Recognize Text banner offers OCR.
    public var pagesWithoutText: [FolioPageID]
    /// Inputs New from Images left out.
    public var skipped: [FolioSkipped]
    public init(source: FolioSourceID, state: FolioDocumentState, pagesWithoutText: [FolioPageID],
                skipped: [FolioSkipped] = []) {
        self.source = source; self.state = state; self.pagesWithoutText = pagesWithoutText; self.skipped = skipped
    }
}

/// A page picture: 8-bit RGBA, premultiplied, row-major, top row first.
public struct FolioBitmap: Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var rgba: [UInt8]
    public init(width: Int, height: Int, rgba: [UInt8]) {
        self.width = max(0, width); self.height = max(0, height); self.rgba = rgba
    }
}

// MARK: Writing and export

public struct FolioWriteOptions: Hashable, Sendable {
    /// Draw annotations and field values into the page content, so they can
    /// no longer be edited (Flatten).
    public var flatten: Bool
    /// Open password (nil: none) and owner password (nil: none).
    public var openPassword: String?
    public var ownerPassword: String?
    /// The restrictions to write; nil keeps the document's own.
    public var permissions: FolioPermissions?
    /// Reduce File Size: PDFKit's documented image options (optimize images
    /// for screen, save images as JPEG). No per-ppi control in v1 (section 1.5).
    public var optimizeImages: Bool
    /// Write each page's `recognizedText` as an invisible text layer.
    public var keepRecognizedText: Bool
    public init(flatten: Bool = false, openPassword: String? = nil, ownerPassword: String? = nil,
                permissions: FolioPermissions? = nil, optimizeImages: Bool = false, keepRecognizedText: Bool = true) {
        self.flatten = flatten; self.openPassword = openPassword; self.ownerPassword = ownerPassword
        self.permissions = permissions; self.optimizeImages = optimizeImages; self.keepRecognizedText = keepRecognizedText
    }
    public static let plain = FolioWriteOptions()
}

public enum FolioImageFormat: String, CaseIterable, Codable, Sendable { case png, jpeg }

/// Text export formats: plain text, rich text, and a word-processing
/// document (Office Open XML). Text, paragraph order and basic styling,
/// never the page layout.
public enum FolioTextFormat: String, CaseIterable, Codable, Sendable { case plain, rtf, docx }

public struct FolioImageExport: Hashable, Sendable {
    public var format: FolioImageFormat
    /// Pixels per inch: 72, 150 or 300 in the sheet.
    public var ppi: Int
    /// 0...1, JPEG only.
    public var quality: Double
    public init(format: FolioImageFormat, ppi: Int, quality: Double = 0.85) {
        self.format = format; self.ppi = min(600, max(36, ppi)); self.quality = min(1, max(0.1, quality))
    }
}

// MARK: Errors (typed, with the sentence a person reads)

public enum FolioOpenError: Error, Equatable, Sendable {
    case notPDF
    case damaged(String)
    case needsPassword
    case wrongPassword
    case tooLarge(bytes: Int)
    public var message: String {
        switch self {
        case .notPDF: "This file isn't a PDF."
        case .damaged(let why): "This PDF is damaged and can't be opened (\(why))."
        case .needsPassword: "This PDF is locked. Enter its password to open it."
        case .wrongPassword: "That password didn't unlock this PDF. Try again."
        case .tooLarge(let b): "This PDF is \(b / 1_048_576) MB, over Folio's 2 GB limit."
        }
    }
}

public enum FolioEditError: Error, Equatable, Sendable {
    case noSuchPage
    case noSuchAnnotation
    case noSuchField
    case lastPage
    case readOnlyField(String)
    case notAllowed(String)
    case invalidValue(String)
    case emptySelection
    case pageRange(String)
    public var message: String {
        switch self {
        case .noSuchPage: "That page is no longer in the document."
        case .noSuchAnnotation: "That markup is no longer on the page."
        case .noSuchField: "That field is no longer in the form."
        case .lastPage: "A PDF needs at least one page. Add a page before deleting this one."
        case .readOnlyField(let name): "\(name) is read-only in this form."
        case .notAllowed(let what): "The owner of this PDF doesn't allow \(what)."
        case .invalidValue(let why): why
        case .emptySelection: "Select some text first."
        case .pageRange(let why): why
        }
    }
}

public enum FolioWriteError: Error, Equatable, Sendable {
    case sourceMissing(String)
    /// Changing or dropping owner restrictions without the owner password.
    case restricted
    case diskFull
    case failed(String)
    public var message: String {
        switch self {
        case .sourceMissing(let name): "The pages from \(name) are no longer available, so they can't be saved. Open \(name) again and insert its pages."
        case .restricted: "Changing this PDF's restrictions needs its owner password. Open it with the owner password first."
        case .diskFull: "There isn't enough space on the disk to save. Free some space and try again."
        case .failed(let why): "The PDF couldn't be saved (\(why))."
        }
    }
}

public enum FolioRecognizeError: Error, Equatable, Sendable {
    case unavailable
    case cancelled
    public var message: String {
        switch self {
        case .unavailable: "Text recognition isn't available on this Mac."
        case .cancelled: "Text recognition was cancelled. Pages already done keep their text."
        }
    }
}

// MARK: Text helpers (FoundationEssentials has no trimmingCharacters)

extension String {
    /// The string without leading and trailing whitespace and newlines.
    public var folioTrimmed: String {
        let scalars = unicodeScalars
        guard let start = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let end = scalars.lastIndex(where: { !$0.properties.isWhitespace }) else { return "" }
        return String(scalars[start...end])
    }
}
