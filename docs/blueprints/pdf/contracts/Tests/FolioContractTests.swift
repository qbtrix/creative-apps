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

private func open(_ s: FolioServices, _ f: FolioFixtureFile, password: String? = nil) async throws -> FolioOpened {
    try await s.opening.open(f.data(), name: f.title, password: password)
}

private func png(_ w: UInt32, _ h: UInt32) -> Data {
    var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52]
    for v in [w, h] { b += [UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)] }
    return Data(b + [8, 6, 0, 0, 0])
}

@Test func openReadAndFind() async throws {   // P-J1, P-J2
    let s = FolioServices.fake()
    let doc = try await open(s, FolioFixtures.letter)
    #expect(doc.state.pages.count == 3)
    #expect(doc.state.outline.map(\.title) == ["Agreement", "Deposit and pets", "Signatures"])
    #expect(doc.state.pages.map(\.label) == ["i", "ii", "iii"])
    #expect(await s.sources.data(for: doc.source) == FolioFixtures.letter.data())
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
    let s = FolioServices.fake()
    await #expect(throws: FolioOpenError.needsPassword) { try await open(s, FolioFixtures.locked) }
    await #expect(throws: FolioOpenError.wrongPassword) { try await open(s, FolioFixtures.locked, password: "nope") }
    #expect(try await open(s, FolioFixtures.locked, password: "folio").state.pages.count == 1)
    await #expect(throws: FolioOpenError.notPDF) { try await s.opening.open(Data("hello".utf8), name: "x", password: nil) }
    let data = FolioFixtures.letter.data()
    await #expect(throws: FolioOpenError.damaged("its contents end early or are garbled")) {
        try await s.opening.open(data.prefix(data.count / 2), name: "x", password: nil)
    }
    let scripted = try await open(s, FolioFixtures.scripted)
    #expect(scripted.state.scripts == .javascript)
}

@Test func selectMarkAndCopy() async throws {   // P-J3, P-J4
    let s = FolioServices.fake()
    var doc = try await open(s, FolioFixtures.letter).state
    let page = doc.pages[0]
    let text = await s.text.text(of: page)
    let sel = s.selecting.select(from: FolioPoint(x: 73, y: 712), to: FolioPoint(x: 72 + 6 * 16 + 1, y: 712), on: page.id, text: text)
    #expect(sel.string == "RESIDENTIAL LEASE")
    let ids = try s.annotating.mark(sel, style: .highlight, color: .highlightYellow, in: &doc)
    #expect(ids.count == 1 && doc.annotations.count == 1)
    #expect(throws: FolioEditError.emptySelection) {
        try s.annotating.mark(FolioTextSelection(spans: [], quads: [], string: ""), style: .underline, color: .red, in: &doc)
    }
    let box = try s.annotating.add(.freeText("Initial here"), rect: FolioRect(x: 400, y: 100, width: 120, height: 20),
                                   color: .black, on: page.id, in: &doc)
    try s.annotating.setStyle(box, to: FolioMarkStyle(fontSize: 200, alignment: .center), in: &doc)
    #expect(doc.annotations.last?.style.fontSize == 72 && doc.annotations.last?.style.alignment == .center)
    let note = try s.annotating.add(.note("Ask about parking"), rect: FolioRect(x: 500, y: 700, width: 20, height: 20),
                                    color: .highlightYellow, on: page.id, in: &doc)
    #expect(s.annotating.hit(FolioPoint(x: 510, y: 710), on: page.id, in: doc) == note)
    try s.annotating.move(note, dx: 10, dy: -10, in: &doc)
    #expect(throws: FolioEditError.self) { try s.annotating.move(ids[0], dx: 1, dy: 1, in: &doc) }
    try s.annotating.delete([note], in: &doc)
    #expect(doc.annotations.count == 2)
    #expect(s.selecting.word(at: FolioPoint(x: 72 + 6 * 13, y: 712), on: page.id, text: text).string == "LEASE")
    let line = s.selecting.line(at: FolioPoint(x: 100, y: 698), on: page.id, text: text)
    #expect(line.string == "This lease is made between the Landlord and the Tenant.")
    // Two lines of one paragraph copy as one line.
    let joined = FolioFakeLayout.text(["one two", "three"], continued: [0], pageHeight: 792, origin: .embedded)
    let both = s.selecting.select(from: FolioPoint(x: 73, y: 712), to: FolioPoint(x: 72 + 6 * 4 + 1, y: 698), on: page.id, text: joined)
    #expect(s.selecting.copyText(both, text: joined) == "one two three")
    // Ligatures spelled out, soft hyphens dropped.
    let lig = FolioFakeLayout.text(["\u{FB01}nal re\u{00AD}view"], pageHeight: 792, origin: .embedded)
    let all = s.selecting.line(at: FolioPoint(x: 80, y: 712), on: page.id, text: lig)
    #expect(s.selecting.copyText(all, text: lig) == "final review")
}

@Test func fillFormInTabOrder() async throws {   // P-J5
    let s = FolioServices.fake()
    var doc = try await open(s, FolioFixtures.form).state
    var order: [FolioFieldID] = []
    var at: FolioFieldID? = nil
    for _ in 0..<5 { at = s.forms.next(after: at, backward: false, in: doc); if let at { order.append(at) } }
    // A radio group is one stop; the signature field is not a stop; wraps.
    #expect(order == ["name", "email", "plan.basic", "agree", "name"].map { FolioFieldID($0) })
    #expect(s.forms.missingRequired(in: doc) == [FolioFieldID("name"), FolioFieldID("email"), FolioFieldID("agree")])
    try s.forms.set(FolioFieldID("name"), to: .text("Ada Lovelace"), in: &doc)
    try s.forms.set(FolioFieldID("plan.plus"), to: .checked(true), in: &doc)
    #expect(doc.fields.first { $0.id.name == "plan.basic" }?.value == .checked(false))
    #expect(s.forms.next(after: FolioFieldID("email"), backward: false, in: doc) == FolioFieldID("plan.plus"))
    #expect(throws: FolioEditError.invalidValue("This field takes one line.")) {
        try s.forms.set(FolioFieldID("name"), to: .text("a\nb"), in: &doc)
    }
    #expect(s.forms.missingRequired(in: doc) == [FolioFieldID("email"), FolioFieldID("agree")])
    #expect(doc.fields.first { $0.id == FolioFieldID("agree") }?.label == "Agree to terms")
}

@Test func signIntoField() async throws {   // P-J6
    let s = FolioServices.fake()
    var doc = try await open(s, FolioFixtures.form).state
    let sig = try s.signing.make(strokes: [[FolioPoint(x: 10, y: 10), FolioPoint(x: 310, y: 110)]], isInitials: false,
                                 id: FolioSignatureID("sig-1"))
    #expect(sig.aspect == 3)
    try await s.signatures.save([sig])
    #expect(await s.signatures.load() == [sig])
    let id = try s.signing.place(sig, at: FolioPoint(x: 250, y: 560), width: 150, on: FolioPageID(0), in: &doc)
    #expect(doc.annotations.first { $0.id == id }?.rect == FolioRect(x: 240, y: 540, width: 120, height: 40))
    // A picture: white background dropped, trimmed to the ink (a 4 x 2 dark bar in a 10 x 6 white picture).
    var rgba = [UInt8](repeating: 255, count: 10 * 6 * 4)
    for y in 2..<4 { for x in 3..<7 { let o = (y * 10 + x) * 4; rgba[o] = 20; rgba[o + 1] = 20; rgba[o + 2] = 60 } }
    let pic = try s.signing.make(picture: FolioBitmap(width: 10, height: 6, rgba: rgba), isInitials: false, id: FolioSignatureID("p"))
    #expect(pic.aspect == 2)
    if case .picture(let b) = pic.kind { #expect(b.width == 4 && b.height == 2 && b.rgba[3] == 255) } else { Issue.record("not a picture") }
    #expect(throws: FolioEditError.self) {
        try s.signing.make(picture: FolioBitmap(width: 2, height: 2, rgba: [UInt8](repeating: 255, count: 16)), isInitials: false, id: FolioSignatureID("q"))
    }
    #expect(throws: FolioEditError.invalidValue("Draw your signature in the box first.")) {
        try s.signing.make(strokes: [[FolioPoint(x: 1, y: 1)]], isInitials: true, id: FolioSignatureID("x"))
    }
}

@Test func organizeCombineSplit() async throws {   // P-J7, P-J8
    let s = FolioServices.fake()
    var doc = try await open(s, FolioFixtures.letter).state
    let ids = doc.pages.map(\.id)
    try s.organizing.move([ids[2]], to: 0, in: &doc)
    #expect(doc.pages.map(\.id) == [ids[2], ids[0], ids[1]])
    try s.organizing.rotate([ids[0]], clockwise: true, in: &doc)
    #expect(doc.page(ids[0])?.displaySize == FolioSize(width: 792, height: 612))
    try s.organizing.delete([ids[1]], in: &doc)
    #expect(throws: FolioEditError.lastPage) { try s.organizing.delete(doc.pages.map(\.id), in: &doc) }
    let other = try await open(s, FolioFixtures.form)
    let added = try s.organizing.insert(other, at: doc.pages.count, in: &doc)
    #expect(added.count == 1 && doc.pages.count == 3 && doc.fields.count == 6)
    try s.organizing.crop([doc.pages[0].id], to: FolioRect(x: 36, y: 36, width: 540, height: 720), in: &doc)
    #expect(doc.pages[0].displaySize == FolioSize(width: 540, height: 720))
    #expect(throws: FolioEditError.invalidValue("Keep at least 1 inch of the page on each side.")) {
        try s.organizing.crop([doc.pages[0].id], to: FolioRect(x: 0, y: 0, width: 10, height: 10), in: &doc)
    }
    #expect(try s.organizing.parseRange("1-2, 3", pageCount: 3) == [1, 2, 3])
    #expect(try s.organizing.parseRange("2-", pageCount: 3) == [2, 3])
    #expect(throws: FolioEditError.pageRange("This document has pages 1 to 3.")) { try s.organizing.parseRange("4", pageCount: 3) }
    #expect(try s.organizing.split(doc, after: [1]).map(\.pages.count) == [1, 2])
    let letter = try await open(s, FolioFixtures.letter)
    let combined = try s.organizing.combine([letter, other], title: "Combined")
    #expect(combined.pages.count == 4 && combined.title == "Combined" && combined.fields.count == 6)
}

@Test func undoRedoCoalesces() async throws {   // P-J9
    let s = FolioServices.fake()
    var doc = try await open(s, FolioFixtures.form).state
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

@Test func saveRoundTripFlattenPasswordRestrictions() async throws {   // P-J10
    let s = FolioServices.fake()
    var doc = try await open(s, FolioFixtures.form).state
    try s.forms.set(FolioFieldID("email"), to: .text("ada@example.com"), in: &doc)
    doc.title = "Membership"
    try s.organizing.crop([doc.pages[0].id], to: FolioRect(x: 36, y: 36, width: 540, height: 720), in: &doc)
    let data = try await s.writing.write(doc, options: .plain)
    let back = try await s.opening.open(data, name: "Membership", password: nil)
    #expect(back.state.fields.first { $0.id.name == "email" }?.value == .text("ada@example.com"))
    #expect(back.state.pages[0].crop == FolioRect(x: 36, y: 36, width: 540, height: 720))
    // The saved file reopens under its own source and saves again.
    #expect(try await s.writing.write(back.state, options: .plain).count > 0)
    let flat = try await s.writing.write(doc, options: FolioWriteOptions(flatten: true, openPassword: "pw"))
    await #expect(throws: FolioOpenError.needsPassword) { try await s.opening.open(flat, name: "x", password: nil) }
    #expect(try await s.opening.open(flat, name: "x", password: "pw").state.fields.isEmpty)
    // Restrictions: kept without the owner password, changed with it.
    let policy = try await open(s, FolioFixtures.restricted)
    #expect(policy.state.permissions.ownerUnlocked == false)
    await #expect(throws: FolioWriteError.restricted) {
        try await s.writing.write(policy.state, options: FolioWriteOptions(permissions: .all))
    }
    #expect(try await s.writing.write(policy.state, options: .plain).count > 0)
    let unlocked = try await open(s, FolioFixtures.restricted, password: "owner")
    #expect(try await s.writing.write(unlocked.state, options: FolioWriteOptions(permissions: .all)).count > 0)
}

@Test func exportTextAndImages() async throws {   // P-J21
    let s = FolioServices.fake()
    let doc = try await open(s, FolioFixtures.form).state
    let images = try await s.exporting.images(of: doc.pages, annotations: doc.annotations, as: FolioImageExport(format: .png, ppi: 144))
    #expect(images.first.map { String(decoding: $0, as: UTF8.self) } == "PNG 0 1224x1584 0")
    let docx = try await s.exporting.text(of: doc, as: .docx)
    #expect(String(decoding: docx, as: UTF8.self).hasPrefix("PKMEMBERSHIP APPLICATION"))
}

@Test func newFromImagesAndReduce() async throws {   // P-J22, P-J23
    let s = FolioServices.fake()
    let made = try await s.opening.open(images: [FolioImageInput(name: "a.png", data: png(600, 800)),
                                                 FolioImageInput(name: "b.png", data: png(800, 600)),
                                                 FolioImageInput(name: "notes.txt", data: Data("hi".utf8))],
                                        name: "Scans", paper: .letter)
    #expect(made.state.pages.count == 2)
    #expect(made.state.pages[0].size.height > made.state.pages[0].size.width)
    #expect(made.state.pages[1].size.width > made.state.pages[1].size.height)
    #expect(made.skipped == [FolioSkipped(name: "notes.txt", reason: "not an image")])
    #expect(made.pagesWithoutText.count == 2)
    let saved = try await s.writing.write(made.state, options: .plain)
    #expect(try await s.opening.open(saved, name: "Scans", password: nil).state.pages.count == 2)
    let photos = try await open(s, FolioFixtures.photos)
    let full = try await s.writing.write(photos.state, options: .plain)
    let small = try await s.writing.write(photos.state, options: FolioWriteOptions(optimizeImages: true))
    #expect(Double(small.count) <= 0.6 * Double(full.count))
    // Reducing the reduced file gains nothing, so the workspace writes nothing.
    let reduced = try await s.opening.open(small, name: "Photos (reduced)", password: nil)
    let again = try await s.writing.write(reduced.state, options: FolioWriteOptions(optimizeImages: true))
    #expect(again.count >= small.count - 64)
}

@Test func recognizeKeepAndReopen() async throws {   // P-J20
    let s = FolioServices.fake()
    var doc = try await open(s, FolioFixtures.scan)
    #expect(doc.pagesWithoutText == [FolioPageID(0), FolioPageID(1)])
    #expect(await s.text.text(of: doc.state.pages[0]).origin == .none)
    let rec = try await s.recognizing.recognize(doc.state.pages[0], languages: ["en-US"])
    #expect(rec.origin == .recognized && rec.lines.last?.text == "TOTAL 7.70")
    doc.state.pages[0].recognizedText = rec   // the workspace does this inside edit("Recognize Text")
    let page0 = doc.state.pages[0]
    let found = s.finding.find(FolioSearchQuery(text: "total"), pages: [page0.id], text: [page0.id: await s.text.text(of: page0)])
    #expect(found.count == 1)
    let saved = try await s.writing.write(doc.state, options: .plain)
    let back = try await s.opening.open(saved, name: "Receipt scan", password: nil)
    #expect(back.pagesWithoutText == [FolioPageID(1)])
    #expect(await s.text.text(of: back.state.pages[0]).lines.last?.text == "TOTAL 7.70")
}

@Test func permissionsRefuse() async throws {
    let s = FolioServices.fake()
    var doc = try await open(s, FolioFixtures.restricted).state
    #expect(throws: FolioEditError.notAllowed("adding or changing markup")) {
        try s.annotating.add(.note("x"), rect: FolioRect(x: 0, y: 0, width: 20, height: 20), color: .red, on: FolioPageID(0), in: &doc)
    }
    #expect(throws: FolioEditError.notAllowed("changing its pages")) { try s.organizing.insertBlank(size: .letter, at: 0, in: &doc) }
}
