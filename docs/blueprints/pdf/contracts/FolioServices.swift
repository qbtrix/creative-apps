// FolioServices.swift: the one place a window gets its services. `.fake`
// runs every journey before PDFKit is wired (`-FolioFixture <name>`); the
// macOS app builds `.live` in FolioApp/Live/FolioServices+Live.swift, one slot
// per contract, so each feature swaps exactly its own slot.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FolioServices: Sendable {
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

    public init(opening: any DocumentOpening, imaging: any PageImaging, text: any PageTextReading,
                finding: any TextFinding, selecting: any TextSelecting, annotating: any Annotating,
                forms: any FormFilling, signing: any Signing, signatures: any SignatureStoring,
                organizing: any PageOrganizing, history: any DocumentHistory, writing: any DocumentWriting,
                exporting: any PageExporting, recognizing: any TextRecognizing) {
        self.opening = opening; self.imaging = imaging; self.text = text; self.finding = finding
        self.selecting = selecting; self.annotating = annotating; self.forms = forms; self.signing = signing
        self.signatures = signatures; self.organizing = organizing; self.history = history
        self.writing = writing; self.exporting = exporting; self.recognizing = recognizing
    }

    /// Every fake, reading the named fixtures (all of FolioFixtures by default).
    public static func fake(_ files: [FolioFixtureFile] = FolioFixtures.all,
                            signatures: [FolioSignature] = []) -> FolioServices {
        let library = FolioFakeLibrary(Dictionary(files.map { (FolioSourceID("fake:\($0.title)"), $0) },
                                                  uniquingKeysWith: { a, _ in a }))
        return FolioServices(
            opening: FakeDocumentOpening(), imaging: FakePageImaging(library: library),
            text: FakePageTextReading(library: library), finding: FakeTextFinding(),
            selecting: FakeTextSelecting(), annotating: FakeAnnotating(), forms: FakeFormFilling(),
            signing: FakeSigning(), signatures: FakeSignatureStore(signatures),
            organizing: FakePageOrganizing(), history: FakeDocumentHistory(),
            writing: FakeDocumentWriting(library: library), exporting: FakePageExporting(library: library),
            recognizing: FakeTextRecognizing(library: library))
    }
}

/// The named fixtures journeys launch with (`-FolioFixture <name>`) and the
/// budget tests time. W0 copies these; a feature adds its own in its own file.
public enum FolioFixtures {
    public static let letter = FolioFixtureFile(title: "Lease", pages: [
        .init(lines: ["RESIDENTIAL LEASE AGREEMENT", "This lease is made between the Landlord and the Tenant.",
                      "1. Term. The term begins on the first day of the month.", "2. Rent. Rent is due on the first day."]),
        .init(lines: ["3. Deposit. The deposit is held for the term.", "4. Pets. No pets without consent."]),
        .init(lines: ["5. Signatures.", "Landlord ____________  Tenant ____________"]),
    ])
    public static let form = FolioFixtureFile(title: "Application", pages: [
        .init(lines: ["MEMBERSHIP APPLICATION", "Name", "Email", "Plan", "Agree to terms", "Signature"]),
    ], fields: [
        FolioFormField(id: FolioFieldID("name"), page: FolioPageID(0), rect: FolioRect(x: 200, y: 680, width: 240, height: 20),
                       kind: .text(multiline: false, maxLength: 60), isRequired: true, tooltip: "Your full name"),
        FolioFormField(id: FolioFieldID("email"), page: FolioPageID(0), rect: FolioRect(x: 200, y: 652, width: 240, height: 20),
                       kind: .text(multiline: false, maxLength: nil), isRequired: true),
        FolioFormField(id: FolioFieldID("plan.basic"), page: FolioPageID(0), rect: FolioRect(x: 200, y: 624, width: 14, height: 14),
                       kind: .radio(group: "plan", option: "Basic")),
        FolioFormField(id: FolioFieldID("plan.plus"), page: FolioPageID(0), rect: FolioRect(x: 260, y: 624, width: 14, height: 14),
                       kind: .radio(group: "plan", option: "Plus")),
        FolioFormField(id: FolioFieldID("agree"), page: FolioPageID(0), rect: FolioRect(x: 200, y: 596, width: 14, height: 14),
                       kind: .checkbox, isRequired: true),
        FolioFormField(id: FolioFieldID("signature"), page: FolioPageID(0), rect: FolioRect(x: 200, y: 540, width: 200, height: 40),
                       kind: .signature),
    ])
    public static let scan = FolioFixtureFile(title: "Receipt scan", pages: [
        .init(size: FolioSize(width: 600, height: 800), lines: ["CORNER BAKERY", "Bread 4.50", "Coffee 3.20", "TOTAL 7.70"], scanned: true),
        .init(size: FolioSize(width: 600, height: 800), lines: ["Thank you"], scanned: true),
    ])
    public static let locked = FolioFixtureFile(title: "Payslip", password: "folio", pages: [.init(lines: ["PAYSLIP", "Net pay 1,234.00"])])
    public static let marked = FolioFixtureFile(title: "Draft", pages: [.init(lines: ["Draft for review", "Please check the totals."])],
        annotations: [FolioAnnotation(id: FolioAnnotationID(0), page: FolioPageID(0), rect: FolioRect(x: 300, y: 700, width: 20, height: 20),
                                      color: .highlightYellow, body: .note("Check with finance"))])
    /// 500 pages, 40 lines each: the budgets' document.
    public static let long = FolioFixtureFile(title: "Manual", pages: (0..<500).map { p in
        .init(lines: (0..<40).map { "Page \(p + 1) line \($0 + 1): the quick brown fox jumps over the lazy dog." })
    })
    public static let all = [letter, form, scan, locked, marked, long]
    public static func named(_ name: String) -> FolioFixtureFile? {
        ["letter": letter, "form": form, "scan": scan, "locked": locked, "marked": marked, "long": long][name]
    }
}
