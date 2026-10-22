// LibraryXMPTests.swift: the XMP sidecar packet, its Library marker and its name (metadata-more
// MD-15). Written before its code (contract rule 13, MD-14). Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

/// The sidecar packet of a photo with these values, as text.
private func packet(
    keywords: [String] = [], title: String = "", caption: String = "", rating: Int = 0,
    label: PhotoLabel? = nil, flag: PhotoFlag = .none
) -> String {
    let photo = PhotoItem(
        name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 1_780_308_000), color: Color3(0, 0, 0),
        rating: rating, label: label, flag: flag, path: "/a/IMG_0001.jpg", keywords: keywords, title: title,
        caption: caption)
    return String(decoding: XMPSidecar.encode(SidecarFields(photo: photo)), as: UTF8.self)
}

@Test func encodeWritesEveryFieldEscapedByteForByte() {
    let expected = """
        <?xpacket begin="\u{FEFF}" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:xmp="http://ns.adobe.com/xap/1.0/" \
        xmlns:lib="https://github.com/qbtrix/creative-apps/ns/library/1.0/" lib:Writer="Library">
        <xmp:Rating>3</xmp:Rating>
        <xmp:Label>Red</xmp:Label>
        <dc:subject><rdf:Bag><rdf:li>A&amp;B</rdf:li><rdf:li>&lt;x&gt;</rdf:li></rdf:Bag></dc:subject>
        <dc:title><rdf:Alt><rdf:li xml:lang="x-default">Harbour &quot;at&quot; dawn</rdf:li></rdf:Alt></dc:title>
        <dc:description><rdf:Alt><rdf:li xml:lang="x-default">Low tide</rdf:li></rdf:Alt></dc:description>
        </rdf:Description></rdf:RDF></x:xmpmeta>
        <?xpacket end="w"?>
        """
    #expect(packet(keywords: ["A&B", "<x>"], title: "Harbour \"at\" dawn", caption: "Low tide", rating: 3, label: .red)
        == expected)
}

@Test func emptyFieldsWriteNoElementAndARejectRatesMinusOne() {
    let text = packet()
    #expect(text.contains("lib:Writer=\"Library\""))
    for element in ["xmp:Rating", "xmp:Label", "dc:subject", "dc:title", "dc:description"] {
        #expect(!text.contains("<\(element)>"), "\(element) written for empty fields")
    }
    #expect(packet(rating: 3, flag: .reject).contains("<xmp:Rating>-1</xmp:Rating>"))
}

@Test func controlCharactersButTabAndNewlineAreDropped() {
    let text = packet(title: "Har\u{07}bour\u{0}", caption: "Low\ttide\nat dawn")
    #expect(text.contains(">Harbour</rdf:li>"))
    #expect(text.contains(">Low\ttide\nat dawn</rdf:li>"))
}

@Test func theMarkerIsLibrarysWriterProperty() {
    let own = packet(keywords: ["Pier"], rating: 3)
    #expect(XMPSidecar.isWrittenByLibrary(Data(own.utf8)))
    let foreign = own.replacingOccurrences(of: " lib:Writer=\"Library\"", with: "")
    #expect(!XMPSidecar.isWrittenByLibrary(Data(foreign.utf8)))
    #expect(!XMPSidecar.isWrittenByLibrary(Data()))
}

@Test func aSidecarTakesTheStemUnlessASiblingSharesIt() {
    #expect(XMPSidecar.path(for: "/a/IMG_1.jpg", siblings: ["/a/IMG_1.jpg"]) == "/a/IMG_1.xmp")
    #expect(XMPSidecar.path(for: "/a/IMG_1.jpg", siblings: ["/a/IMG_1.jpg", "/a/IMG_1.heic"]) == "/a/IMG_1.jpg.xmp")
    #expect(XMPSidecar.path(for: "/a/IMG_1.heic", siblings: ["/a/IMG_1.jpg", "/a/IMG_1.heic"]) == "/a/IMG_1.heic.xmp")
    #expect(XMPSidecar.path(for: "/a/IMG_1.jpg", siblings: ["/a/IMG_1.jpg", "/b/IMG_1.heic"]) == "/a/IMG_1.xmp")
}
