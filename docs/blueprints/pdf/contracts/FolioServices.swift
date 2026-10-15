// FolioServices.swift: the one place a window gets its services. `.fake`
// runs every journey before PDFKit is wired (`-FolioFixture <name>`); the
// macOS app builds `.live` in FolioApp/Live/FolioServices+Live.swift, one slot
// per contract, so each feature swaps exactly its own slot. Every platform
// service shares the one `sources` store the opener registers into.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FolioServices: Sendable {
    public var sources: any DocumentSources
    public var opening: any DocumentOpening
    public var imaging: any PageImaging
    public var text: any PageTextReading
    public var finding: any TextFinding
    public var selecting: any TextSelecting
    public var annotating: any Annotating
    public var forms: any FormFilling
    public var signing: any Signing
    public var signatures: any SignatureStoring
    public var organizing: any PageOrganizing
    public var history: any DocumentHistory
    public var writing: any DocumentWriting
    public var exporting: any PageExporting
    public var recognizing: any TextRecognizing

    public init(sources: any DocumentSources, opening: any DocumentOpening, imaging: any PageImaging,
                text: any PageTextReading, finding: any TextFinding, selecting: any TextSelecting,
                annotating: any Annotating, forms: any FormFilling, signing: any Signing,
                signatures: any SignatureStoring, organizing: any PageOrganizing, history: any DocumentHistory,
                writing: any DocumentWriting, exporting: any PageExporting, recognizing: any TextRecognizing) {
        self.sources = sources; self.opening = opening; self.imaging = imaging; self.text = text
        self.finding = finding; self.selecting = selecting; self.annotating = annotating; self.forms = forms
        self.signing = signing; self.signatures = signatures; self.organizing = organizing
        self.history = history; self.writing = writing; self.exporting = exporting; self.recognizing = recognizing
    }

    /// Every fake, sharing one fake source store.
    public static func fake(signatures: [FolioSignature] = []) -> FolioServices {
        let sources = FakeDocumentSources()
        return FolioServices(
            sources: sources, opening: FakeDocumentOpening(sources: sources), imaging: FakePageImaging(sources: sources),
            text: FakePageTextReading(sources: sources), finding: FakeTextFinding(), selecting: FakeTextSelecting(),
            annotating: FakeAnnotating(), forms: FakeFormFilling(), signing: FakeSigning(),
            signatures: FakeSignatureStore(signatures), organizing: FakePageOrganizing(), history: FakeDocumentHistory(),
            writing: FakeDocumentWriting(sources: sources), exporting: FakePageExporting(sources: sources),
            recognizing: FakeTextRecognizing(sources: sources))
    }
}

/// The named fixtures journeys launch with (`-FolioFixture <name>`), the
/// sample writer turns into real PDFs (`-FolioSample <name>`,
/// `-FolioWriteSample <name> <path>`) and the budget tests time. W0 copies
/// these; each feature adds its own in its `Fixtures/FolioFixtures+<Area>.swift`.
public enum FolioFixtures {
    public static let letter = FolioFixtureFile(title: "Lease", author: "Property Office", pages: [
        .init(lines: ["RESIDENTIAL LEASE AGREEMENT", "This lease is made between the Landlord and the Tenant.",
                      "1. Term. The term begins on the first day of the month.", "2. Rent. Rent is due on the first day."],
              continued: [], label: "i"),
        .init(lines: ["3. Deposit. The deposit is held for the term.", "4. Pets. No pets without consent."], label: "ii"),
        .init(lines: ["5. Signatures.", "Landlord ____________  Tenant ____________"], label: "iii"),
    ], outline: [.init(title: "Agreement", page: 0), .init(title: "Deposit and pets", page: 1), .init(title: "Signatures", page: 2)])

    static func field(_ name: String, _ label: String, _ y: Double, _ kind: FolioFieldKind, x: Double = 200,
                      w: Double = 240, h: Double = 20, required: Bool = false, value: FolioFieldValue = .empty) -> FolioFormField {
        FolioFormField(id: FolioFieldID(name), label: label, page: FolioPageID(0), rect: FolioRect(x: x, y: y, width: w, height: h),
                       kind: kind, value: value, isRequired: required)
    }
    public static let form = FolioFixtureFile(title: "Application", pages: [
        .init(lines: ["MEMBERSHIP APPLICATION", "Name", "Email", "Plan", "Agree to terms", "Signature"]),
    ], fields: [
        field("name", "Name", 680, .text(multiline: false, maxLength: 60), required: true),
        field("email", "Email", 652, .text(multiline: false, maxLength: nil), required: true),
        field("plan.basic", "Plan", 624, .radio(group: "plan", option: "Basic"), w: 14, h: 14),
        field("plan.plus", "Plan", 624, .radio(group: "plan", option: "Plus"), x: 260, w: 14, h: 14),
        field("agree", "Agree to terms", 596, .checkbox, w: 14, h: 14, required: true),
        field("signature", "Signature", 540, .signature, w: 200, h: 40),
    ])
    /// `form` already filled, with a highlight from the file: history-files' journeys.
    public static let filled = FolioFixtureFile(title: "Filled", pages: form.pages, fields: [
        field("name", "Name", 680, .text(multiline: false, maxLength: 60), required: true, value: .text("Ada Lovelace")),
        field("agree", "Agree to terms", 596, .checkbox, w: 14, h: 14, required: true, value: .checked(true)),
    ], annotations: [FolioAnnotation(id: FolioAnnotationID(0), page: FolioPageID(0), rect: FolioRect(x: 72, y: 706, width: 132, height: 12),
                                     color: .highlightYellow, body: .markup(.highlight, quads: [FolioRect(x: 72, y: 706, width: 132, height: 12)],
                                                                            text: "MEMBERSHIP"))])
    public static let scripted = FolioFixtureFile(title: "Tax form", scripts: .javascript, pages: [.init(lines: ["TAX FORM", "Total"])],
        fields: [field("total", "Total", 680, .text(multiline: false, maxLength: nil))])
    public static let scan = FolioFixtureFile(title: "Receipt scan", pages: [
        .init(size: FolioSize(width: 600, height: 800), lines: ["CORNER BAKERY", "Bread 4.50", "Coffee 3.20", "TOTAL 7.70"],
              scanned: true, imageBytes: 40_000),
        .init(size: FolioSize(width: 600, height: 800), lines: ["Thank you"], scanned: true, imageBytes: 40_000),
    ])
    public static let locked = FolioFixtureFile(title: "Payslip", password: "folio", pages: [.init(lines: ["PAYSLIP", "Net pay 1,234.00"])])
    /// Opens without a password but restricts changes; "owner" unlocks them.
    public static let restricted = FolioFixtureFile(title: "Policy", ownerPassword: "owner",
        permissions: FolioPermissions(canAnnotate: false, canAssemble: false, ownerUnlocked: false),
        pages: [.init(lines: ["POLICY", "Do not modify."])])
    public static let marked = FolioFixtureFile(title: "Draft", pages: [.init(lines: ["Draft for review", "Please check the totals."])],
        annotations: [FolioAnnotation(id: FolioAnnotationID(0), page: FolioPageID(0), rect: FolioRect(x: 300, y: 700, width: 20, height: 20),
                                      color: .highlightYellow, body: .note("Check with finance"))])
    /// Six photo pages: Reduce File Size.
    public static let photos = FolioFixtureFile(title: "Photos", pages: (0..<6).map { _ in
        .init(lines: [], imageBytes: 200_000) })
    /// 500 pages, 40 lines each: the budgets' document.
    public static let long = FolioFixtureFile(title: "Manual", pages: (0..<500).map { p in
        .init(lines: (0..<40).map { "Page \(p + 1) line \($0 + 1): the quick brown fox jumps over the lazy dog." })
    })
    public static let all: [String: FolioFixtureFile] = [
        "letter": letter, "form": form, "filled": filled, "scripted": scripted, "scan": scan, "locked": locked,
        "restricted": restricted, "marked": marked, "photos": photos, "long": long,
    ]
    public static func named(_ name: String) -> FolioFixtureFile? { all[name] }
}
