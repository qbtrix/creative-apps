// Contracts/FolioContracts.swift: one protocol per Folio use case.
// Linux-safe. Rules every conformance keeps:
// - Reads take values. Writes take the document `inout` and throw
//   FolioEditError, leaving it unchanged when they throw.
// - No contract records undo: FolioWorkspace.edit(_:_:) does, around a call.
// - `unavailableHelp` is nil once the service works; until then every control
//   that needs it is disabled with that sentence (CLAUDE.md, No dead controls).
// - Platform work (PDFKit, Vision, CoreGraphics) lives only in live types in
//   FolioApp; everything else has a Linux live type in FolioModel/Live.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-1 Open a PDF (or make one from images) and read its pages, fields,
/// annotations and outline into a FolioDocumentState.
/// Live: `FolioApp/Live/PDFKitOpening.swift` (PDFDocument(data:), unlock(withPassword:)).
public protocol DocumentOpening: Sendable {
    var unavailableHelp: String? { get }
    /// Opens PDF bytes. Throws `.needsPassword` for a locked file opened with
    /// nil, `.wrongPassword` for a bad one, `.notPDF`, `.damaged`, `.tooLarge`.
    func open(_ data: Data, name: String, password: String?) async throws(FolioOpenError) -> FolioOpened
    /// Makes a document of one page per image (PNG, JPEG or HEIC bytes), each
    /// page the image's size at 72 ppi capped to fit A4 or Letter.
    func open(images: [Data], name: String) async throws(FolioOpenError) -> FolioOpened
}

/// UC-2 See a page: the page's picture without Folio's own annotations
/// (the view draws those from the Model, so edits never wait on a render).
/// Live: `FolioApp/Live/PDFKitImaging.swift` (PDFPage.thumbnail(of:for:)).
public protocol PageImaging: Sendable {
    var unavailableHelp: String? { get }
    /// A picture at most `maxPixels` on its long side, rotation applied.
    /// nil when the page's source is gone.
    func image(of page: FolioPage, maxPixels: Int) async -> FolioBitmap?
}

/// UC-3 The text on a page, line by line with each Character's box.
/// Live: `FolioApp/Live/PDFKitText.swift` (PDFPage.string, characterBounds(at:)).
public protocol PageTextReading: Sendable {
    var unavailableHelp: String? { get }
    func text(of page: FolioPage) async -> FolioPageText
}

/// UC-4 Find text across the document. Pure: works on page text.
/// Live: `FolioModel/Live/LiveTextFinding.swift`.
public protocol TextFinding: Sendable {
    /// Hits in page order, then reading order. An empty query finds nothing.
    func find(_ query: FolioSearchQuery, pages: [FolioPageID], text: [FolioPageID: FolioPageText]) -> [FolioSearchHit]
}

/// UC-5 Select text by dragging, double-click a word. Pure.
/// Live: `FolioModel/Live/LiveTextSelecting.swift`.
public protocol TextSelecting: Sendable {
    /// Characters between the two points in reading order on one page.
    func select(from: FolioPoint, to: FolioPoint, on page: FolioPageID, text: FolioPageText) -> FolioTextSelection
    /// The word under the point, or an empty selection.
    func word(at point: FolioPoint, on page: FolioPageID, text: FolioPageText) -> FolioTextSelection
}

/// UC-6 Mark up: highlight, underline, strike out, notes, text boxes, ink,
/// shapes, images; move, resize, recolor, comment, delete. Pure.
/// Live: `FolioModel/Live/LiveAnnotating.swift`.
public protocol Annotating: Sendable {
    /// Text markup over a selection; refuses an empty one (`.emptySelection`).
    func mark(_ selection: FolioTextSelection, style: FolioMarkupStyle, color: FolioColor,
              in doc: inout FolioDocumentState) throws(FolioEditError) -> [FolioAnnotationID]
    /// Any other body placed at `rect` on `page`.
    func add(_ body: FolioAnnotationBody, rect: FolioRect, color: FolioColor, on page: FolioPageID,
             in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioAnnotationID
    func move(_ id: FolioAnnotationID, dx: Double, dy: Double, in doc: inout FolioDocumentState) throws(FolioEditError)
    func setRect(_ id: FolioAnnotationID, to rect: FolioRect, in doc: inout FolioDocumentState) throws(FolioEditError)
    func setColor(_ id: FolioAnnotationID, to color: FolioColor, in doc: inout FolioDocumentState) throws(FolioEditError)
    /// The text of a note or text box, or the comment on any other kind.
    func setText(_ id: FolioAnnotationID, to text: String, in doc: inout FolioDocumentState) throws(FolioEditError)
    func delete(_ ids: [FolioAnnotationID], in doc: inout FolioDocumentState) throws(FolioEditError)
    /// The topmost annotation whose rect holds the point (4 pt slop), or nil.
    func hit(_ point: FolioPoint, on page: FolioPageID, in doc: FolioDocumentState) -> FolioAnnotationID?
}

/// UC-7 Fill a form: type, check, choose; Tab order; required fields. Pure.
/// Live: `FolioModel/Live/LiveFormFilling.swift`.
public protocol FormFilling: Sendable {
    /// Sets one field. A radio option sets its whole group; a value the field
    /// can't take is refused with `.invalidValue("<sentence>")`.
    func set(_ field: FolioFieldID, to value: FolioFieldValue, in doc: inout FolioDocumentState) throws(FolioEditError)
    /// Tab order: page order, then top to bottom, then left to right; skips
    /// read-only fields; wraps. nil when the form has no fillable field.
    func next(after field: FolioFieldID?, backward: Bool, in doc: FolioDocumentState) -> FolioFieldID?
    /// Required fields still empty, in Tab order.
    func missingRequired(in doc: FolioDocumentState) -> [FolioFieldID]
    /// Every field back to empty (Clear Form).
    func clear(in doc: inout FolioDocumentState) throws(FolioEditError)
}

/// UC-8 Make a signature or initials and place it. Pure.
/// Live: `FolioModel/Live/LiveSigning.swift`.
public protocol Signing: Sendable {
    /// From pad strokes in view points: trims to the ink box, scales into the
    /// unit box, keeps the aspect. Refuses fewer than 2 points of ink.
    func make(strokes: [[FolioPoint]], isInitials: Bool, id: FolioSignatureID) throws(FolioEditError) -> FolioSignature
    func make(typed name: String, isInitials: Bool, id: FolioSignatureID) throws(FolioEditError) -> FolioSignature
    /// Places a signature centered on `point`, `width` points wide. Inside an
    /// empty signature field it fits that field instead.
    func place(_ signature: FolioSignature, at point: FolioPoint, width: Double, on page: FolioPageID,
               in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioAnnotationID
}

/// UC-8b Keep signatures between launches.
/// Live: `FolioModel/Live/LiveSignatureStore.swift` (a JSON file the app's
/// folder holds; the macOS app passes the URL).
public protocol SignatureStoring: Sendable {
    var unavailableHelp: String? { get }
    func load() async -> [FolioSignature]
    func save(_ signatures: [FolioSignature]) async throws(FolioWriteError)
}

/// UC-9 Organize pages: reorder, rotate, delete, insert blank, combine
/// files, extract and split. Pure.
/// Live: `FolioModel/Live/LivePageOrganizing.swift`.
public protocol PageOrganizing: Sendable {
    /// Moves the pages, keeping their order, so the first lands at `index`
    /// of the document as it is after they are taken out.
    func move(_ pages: [FolioPageID], to index: Int, in doc: inout FolioDocumentState) throws(FolioEditError)
    func rotate(_ pages: [FolioPageID], clockwise: Bool, in doc: inout FolioDocumentState) throws(FolioEditError)
    /// Deletes pages and their annotations and fields. Refuses all of them (`.lastPage`).
    func delete(_ pages: [FolioPageID], in doc: inout FolioDocumentState) throws(FolioEditError)
    /// Inserts every page of another opened file at `index` (Combine);
    /// returns the new page ids. Its fields keep their names unless taken,
    /// then get a " 2" suffix.
    func insert(_ other: FolioOpened, at index: Int, in doc: inout FolioDocumentState) throws(FolioEditError) -> [FolioPageID]
    func insertBlank(size: FolioSize, at index: Int, in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioPageID
    /// Crops pages to `rect` (page space, before rotation), clamped to each
    /// page; refuses a rect under 72 pt on a side. nil removes the crop.
    func crop(_ pages: [FolioPageID], to rect: FolioRect?, in doc: inout FolioDocumentState) throws(FolioEditError)
    /// A new document of just these pages, in document order (Extract).
    func extract(_ pages: [FolioPageID], from doc: FolioDocumentState) throws(FolioEditError) -> FolioDocumentState
    /// Splits after each page number in `after` (1-based), into parts.
    func split(_ doc: FolioDocumentState, after: [Int]) throws(FolioEditError) -> [FolioDocumentState]
    /// "1-3, 5, 8-" style text to 1-based page numbers, sorted, unique.
    func parseRange(_ text: String, pageCount: Int) throws(FolioEditError) -> [Int]
}

/// UC-10 Undo and redo: a stack of named document snapshots. Pure.
/// Live: `FolioModel/Live/LiveDocumentHistory.swift`.
public protocol DocumentHistory: Sendable {
    /// Records `before` under `name`. Two records in a row with the same
    /// non-nil `coalesceKey` make one step (a drag, typing in one field).
    func record(_ before: FolioDocumentState, name: String, coalesceKey: String?, in history: inout FolioHistory)
    /// Ends coalescing, so the next record is its own step.
    func endCoalescing(_ history: inout FolioHistory)
    func undo(_ current: FolioDocumentState, in history: inout FolioHistory) -> FolioDocumentState?
    func redo(_ current: FolioDocumentState, in history: inout FolioHistory) -> FolioDocumentState?
}

public struct FolioHistory: Equatable, Sendable {
    public struct Step: Equatable, Sendable {
        public var name: String
        public var state: FolioDocumentState
        public var coalesceKey: String?
        public init(name: String, state: FolioDocumentState, coalesceKey: String?) {
            self.name = name; self.state = state; self.coalesceKey = coalesceKey
        }
    }
    public var undoSteps: [Step] = []
    public var redoSteps: [Step] = []
    public var limit: Int
    public var coalescing = false
    public init(limit: Int = 100) { self.limit = max(1, limit) }
    public var undoName: String? { undoSteps.last?.name }
    public var redoName: String? { redoSteps.last?.name }
}

/// UC-11 Save: the document as PDF bytes, from its sources plus the edits.
/// Live: `FolioApp/Live/PDFKitWriting.swift` (PDFDocument.write(to:withOptions:)).
public protocol DocumentWriting: Sendable {
    var unavailableHelp: String? { get }
    func write(_ doc: FolioDocumentState, options: FolioWriteOptions) async throws(FolioWriteError) -> Data
}

/// UC-12 Export pages as pictures, or the text as plain text, rich text or a
/// word-processing document.
/// Live: `FolioApp/Live/PDFKitExporting.swift`.
public protocol PageExporting: Sendable {
    var unavailableHelp: String? { get }
    /// One encoded image per page, in the order given, annotations drawn.
    func images(of pages: [FolioPage], annotations: [FolioAnnotation], as format: FolioImageExport)
        async throws(FolioWriteError) -> [Data]
    /// The document's text in reading order. Plain text separates pages with a
    /// form feed; rich text and word-processing keep paragraphs, bold, italic
    /// and size where the PDF's text layer has them.
    func text(of doc: FolioDocumentState, as format: FolioTextFormat) async throws(FolioWriteError) -> Data
}

/// UC-13 Recognize text on a scanned page (OCR), so it can be found,
/// selected and highlighted. Live: `FolioApp/Live/VisionRecognizing.swift`
/// (RecognizeTextRequest, accurate level).
public protocol TextRecognizing: Sendable {
    var unavailableHelp: String? { get }
    /// Languages offered in the Recognize Text sheet, BCP 47 tags.
    var languages: [String] { get }
    func recognize(_ page: FolioPage, languages: [String]) async throws(FolioRecognizeError) -> FolioPageText
}
