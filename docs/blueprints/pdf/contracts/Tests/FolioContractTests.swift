// FolioContractTests.swift: proves the contracts can carry every tier-1
// journey (section 5) on the fakes. W0 splits it into one conformance suite
// per contract, run against `.fake` and, once each lands, `.live`.
import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import FolioModel

private let s = FolioServices.fake()

private func open(_ f: FolioFixtureFile, password: String? = nil) async throws -> FolioOpened {
    try await s.opening.open(f.data(), name: f.title, password: password)
}

@Test func openReadAndFind() async throws {   // P-J1, P-J2
    let doc = try await open(FolioFixtures.letter)
    #expect(doc.state.pages.count == 3)
    var text: [FolioPageID: FolioPageText] = [:]
    for p in doc.state.pages { text[p.id] = await s.text.text(of: p) }
    let hits = s.finding.find(FolioSearchQuery(text: "first day"), pages: doc.state.pages.map(\.id), text: text)
    #expect(hits.count == 2)
    #expect(hits.first?.span == FolioTextSpan(page: FolioPageID(0), line: 2, start: 32, end: 41))
    #expect(s.finding.find(FolioSearchQuery(text: "term", wholeWords: true), pages: doc.state.pages.map(\.id), text: text).count == 3)
    let img = await s.imaging.image(of: doc.state.pages[0], maxPixels: 200)
    #expect(img?.height == 200 && img?.width == 154)
}

@Test func openRefusals() async throws {   // P-J11
    await #expect(throws: FolioOpenError.needsPassword) { try await open(FolioFixtures.locked) }
    await #expect(throws: FolioOpenError.wrongPassword) { try await open(FolioFixtures.locked, password: "nope") }
    #expect(try await open(FolioFixtures.locked, password: "folio").state.pages.count == 1)
    await #expect(throws: FolioOpenError.notPDF) { try await s.opening.open(Data("hello".utf8), name: "x", password: nil) }
    #expect(FolioOpenError.wrongPassword.message == "That password didn't unlock this PDF. Try again.")
}

@Test func highlightAndNote() async throws {   // P-J3, P-J4
    var doc = try await open(FolioFixtures.letter).state
    let page = doc.pages[0]
    let text = await s.text.text(of: page)
    // Drag across "RESIDENTIAL LEASE" on line 0: glyph 0 to glyph 16.
    let sel = s.selecting.select(from: FolioPoint(x: 73, y: 712), to: FolioPoint(x: 72 + 6 * 16 + 1, y: 712), on: page.id, text: text)
    #expect(sel.string == "RESIDENTIAL LEASE")
    let ids = try s.annotating.mark(sel, style: .highlight, color: .highlightYellow, in: &doc)
    #expect(ids.count == 1 && doc.annotations.count == 1)
    #expect(throws: FolioEditError.emptySelection) {
        try s.annotating.mark(FolioTextSelection(spans: [], quads: [], string: ""), style: .underline, color: .red, in: &doc)
    }
    let note = try s.annotating.add(.note("Ask about parking"), rect: FolioRect(x: 500, y: 700, width: 20, height: 20),
                                    color: .highlightYellow, on: page.id, in: &doc)
    #expect(s.annotating.hit(FolioPoint(x: 510, y: 710), on: page.id, in: doc) == note)
    try s.annotating.move(note, dx: 10, dy: -10, in: &doc)
    #expect(throws: FolioEditError.self) { try s.annotating.move(ids[0], dx: 1, dy: 1, in: &doc) }
    try s.annotating.delete([note], in: &doc)
    #expect(doc.annotations.count == 1)
    #expect(s.selecting.word(at: FolioPoint(x: 72 + 6 * 13, y: 712), on: page.id, text: text).string == "LEASE")
}

@Test func fillFormInTabOrder() async throws {   // P-J5
    var doc = try await open(FolioFixtures.form).state
    #expect(s.forms.next(after: nil, backward: false, in: doc) == FolioFieldID("name"))
    #expect(s.forms.next(after: FolioFieldID("name"), backward: false, in: doc) == FolioFieldID("email"))
    #expect(s.forms.missingRequired(in: doc) == [FolioFieldID("name"), FolioFieldID("email"), FolioFieldID("agree")])
    try s.forms.set(FolioFieldID("name"), to: .text("Ada Lovelace"), in: &doc)
    try s.forms.set(FolioFieldID("plan.plus"), to: .checked(true), in: &doc)
    #expect(doc.fields.first { $0.id.name == "plan.basic" }?.value == .checked(false))
    #expect(throws: FolioEditError.invalidValue("This field takes one line.")) {
        try s.forms.set(FolioFieldID("name"), to: .text("a\nb"), in: &doc)
    }
    #expect(s.forms.missingRequired(in: doc) == [FolioFieldID("email"), FolioFieldID("agree")])
}

@Test func signIntoField() async throws {   // P-J6
    var doc = try await open(FolioFixtures.form).state
    let sig = try s.signing.make(strokes: [[FolioPoint(x: 10, y: 10), FolioPoint(x: 310, y: 110)]], isInitials: false,
                                 id: FolioSignatureID("sig-1"))
    #expect(sig.aspect == 3)
    try await s.signatures.save([sig])
    #expect(await s.signatures.load() == [sig])
    let id = try s.signing.place(sig, at: FolioPoint(x: 250, y: 560), width: 150, on: FolioPageID(0), in: &doc)
    let placed = doc.annotations.first { $0.id == id }
    // Fits the 200 x 40 field: 120 x 40, centered.
    #expect(placed?.rect == FolioRect(x: 240, y: 540, width: 120, height: 40))
    #expect(throws: FolioEditError.invalidValue("Draw your signature in the box first.")) {
        try s.signing.make(strokes: [[FolioPoint(x: 1, y: 1)]], isInitials: true, id: FolioSignatureID("x"))
    }
}

@Test func organizeAndCombine() async throws {   // P-J7, P-J8
    var doc = try await open(FolioFixtures.letter).state
    let ids = doc.pages.map(\.id)
    try s.organizing.move([ids[2]], to: 0, in: &doc)
    #expect(doc.pages.map(\.id) == [ids[2], ids[0], ids[1]])
    try s.organizing.rotate([ids[0]], clockwise: true, in: &doc)
    #expect(doc.page(ids[0])?.displaySize == FolioSize(width: 792, height: 612))
    try s.organizing.delete([ids[1]], in: &doc)
    #expect(throws: FolioEditError.lastPage) { try s.organizing.delete(doc.pages.map(\.id), in: &doc) }
    let other = try await open(FolioFixtures.form)
    let added = try s.organizing.insert(other, at: doc.pages.count, in: &doc)
    #expect(added.count == 1 && doc.pages.count == 3 && doc.fields.count == 6)
    #expect(try s.organizing.parseRange("1-2, 3", pageCount: 3) == [1, 2, 3])
    #expect(try s.organizing.parseRange("2-", pageCount: 3) == [2, 3])
    #expect(throws: FolioEditError.pageRange("This document has pages 1 to 3.")) { try s.organizing.parseRange("4", pageCount: 3) }
    let parts = try s.organizing.split(doc, after: [1])
    #expect(parts.map(\.pages.count) == [1, 2])
}

@Test func undoRedoCoalesces() async throws {   // P-J9
    var doc = try await open(FolioFixtures.form).state
    var h = FolioHistory()
    for text in ["A", "Ad", "Ada"] {
        let before = doc
        try s.forms.set(FolioFieldID("name"), to: .text(text), in: &doc)
        s.history.record(before, name: "Typing", coalesceKey: "field:name", in: &h)
    }
    s.history.endCoalescing(&h)
    #expect(h.undoSteps.count == 1 && h.undoName == "Typing")
    let undone = s.history.undo(doc, in: &h)
    #expect(undone?.fields.first?.value == .empty)
    #expect(h.redoName == "Typing")
    #expect(s.history.redo(undone ?? doc, in: &h)?.fields.first?.value == .text("Ada"))
}

@Test func saveRoundTripAndFlatten() async throws {   // P-J10
    var doc = try await open(FolioFixtures.form).state
    try s.forms.set(FolioFieldID("email"), to: .text("ada@example.com"), in: &doc)
    let data = try await s.writing.write(doc, options: .plain)
    let back = try await s.opening.open(data, name: "Application", password: nil)
    #expect(back.state.fields.first { $0.id.name == "email" }?.value == .text("ada@example.com"))
    let flat = try await s.writing.write(doc, options: FolioWriteOptions(flatten: true, openPassword: "pw"))
    await #expect(throws: FolioOpenError.needsPassword) { try await s.opening.open(flat, name: "x", password: nil) }
    let opened = try await s.opening.open(flat, name: "x", password: "pw")
    #expect(opened.state.fields.isEmpty)
    let images = try await s.exporting.images(of: doc.pages, annotations: doc.annotations, as: FolioImageExport(format: .png, ppi: 144))
    #expect(images.first.map { String(decoding: $0, as: UTF8.self) } == "PNG 0 1224x1584 0")
}

@Test func recognizeScannedPages() async throws {   // P-J12
    let doc = try await open(FolioFixtures.scan)
    #expect(doc.pagesWithoutText == [FolioPageID(0), FolioPageID(1)])
    #expect(await s.text.text(of: doc.state.pages[0]).origin == .none)
    let rec = try await s.recognizing.recognize(doc.state.pages[0], languages: ["en-US"])
    #expect(rec.origin == .recognized && rec.lines.last?.text == "TOTAL 7.70")
    let hits = s.finding.find(FolioSearchQuery(text: "total"), pages: [doc.state.pages[0].id], text: [doc.state.pages[0].id: rec])
    #expect(hits.count == 1)
}

@Test func permissionsRefuse() async throws {
    var doc = try await open(FolioFixtures.letter).state
    doc.permissions = FolioPermissions(canAnnotate: false, canAssemble: false)
    #expect(throws: FolioEditError.notAllowed("adding or changing markup")) {
        try s.annotating.add(.note("x"), rect: FolioRect(x: 0, y: 0, width: 20, height: 20), color: .red, on: FolioPageID(0), in: &doc)
    }
    #expect(throws: FolioEditError.notAllowed("changing its pages")) { try s.organizing.delete([FolioPageID(0)], in: &doc) }
}
