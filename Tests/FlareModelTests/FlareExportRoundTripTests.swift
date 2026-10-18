// FlareExportRoundTripTests.swift: MJ-FX2's round-trip half (docs/blueprints/flare/features/flare-export.md, FX-8).
// On both adapters (`FakeExport` and `LiveExportAdapter` over `LiveStage`) and for `bounce`, `showcase` and
// `character`: the SVG frame and the Lottie bytes are identical after the document is saved and reopened, and
// twice in a row; the SVG parses (FoundationXML on Linux) with the scene's width and height on its root; the
// Lottie's `fr`, `w`, `h` and `op` are the scene's fps, size and duration. `FakeExport(unavailable:)` still throws
// its reason.
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import FlareCore
import FlareModel
import Testing

private let fixtures = ["bounce", "showcase", "character"]

private let adapters: [(name: String, exporter: any Exporting)] = [
    ("fake", FakeExport(frameDelay: .zero)),
    ("live", LiveExportAdapter(stage: LiveStage())),
]

private func bytes(_ exporter: any Exporting, _ document: Document, _ format: ExportFormat) async throws -> Data {
    let scene = try #require(document.scenes.first)
    let options = ExportOptions(format: format, sceneID: scene.id, frames: 0...0)
    let result = try await exporter.export(document, options: options, rasterizer: FakeRasterizer()) { _ in }
    #expect(result.files.count == 1)
    return try #require(result.files.first).data
}

/// The root element's name and attributes of an XML document; nil when it doesn't parse.
private final class RootAttributes: NSObject, XMLParserDelegate {
    var root: (name: String, attributes: [String: String])?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if root == nil { root = (elementName, attributeDict) }
    }

    static func of(_ data: Data) -> (name: String, attributes: [String: String])? {
        let parser = XMLParser(data: data), delegate = RootAttributes()
        parser.delegate = delegate
        return parser.parse() ? delegate.root : nil
    }
}

@Suite struct FlareExportRoundTripTests {
    @Test(arguments: fixtures, [ExportFormat.svgFrame, .lottie])
    func bytesSurviveSaveAndReopen(fixture: String, format: ExportFormat) async throws {
        let document = try #require(FlareFixtures.named(fixture))
        let reopened = try FlareFormat.decode(FlareFormat.encode(document))
        for (name, exporter) in adapters {
            let first = try await bytes(exporter, document, format)
            let again = try await bytes(exporter, document, format)
            let afterReopen = try await bytes(exporter, reopened, format)
            #expect(!first.isEmpty, "\(name) \(fixture)")
            #expect(first == again, "\(name) \(fixture): twice in a row")
            #expect(first == afterReopen, "\(name) \(fixture): after save and reopen")
        }
    }

    @Test(arguments: fixtures)
    func svgParsesWithTheScenesSize(fixture: String) async throws {
        let document = try #require(FlareFixtures.named(fixture))
        let scene = try #require(document.scenes.first)
        for (name, exporter) in adapters {
            let root = try #require(RootAttributes.of(try await bytes(exporter, document, .svgFrame)), "\(name)")
            #expect(root.name == "svg", "\(name) \(fixture)")
            #expect(root.attributes["width"].flatMap(Double.init) == scene.width, "\(name) \(fixture)")
            #expect(root.attributes["height"].flatMap(Double.init) == scene.height, "\(name) \(fixture)")
        }
    }

    @Test(arguments: fixtures)
    func lottieCarriesTheScenesTimingAndSize(fixture: String) async throws {
        let document = try #require(FlareFixtures.named(fixture))
        let scene = try #require(document.scenes.first)
        for (name, exporter) in adapters {
            let json = try JSONSerialization.jsonObject(with: try await bytes(exporter, document, .lottie))
            let top = try #require(json as? [String: Any], "\(name)")
            #expect((top["fr"] as? NSNumber)?.intValue == scene.fps, "\(name) \(fixture)")
            #expect((top["op"] as? NSNumber)?.intValue == scene.durationFrames, "\(name) \(fixture)")
            #expect((top["w"] as? NSNumber)?.doubleValue == scene.width, "\(name) \(fixture)")
            #expect((top["h"] as? NSNumber)?.doubleValue == scene.height, "\(name) \(fixture)")
        }
    }

    @Test func anUnavailableFakeStillThrowsItsReason() async {
        let off = FakeExport(unavailable: "Not connected yet (FX-8).")
        #expect(off.warnings(FlareFixtures.showcase, options: ExportOptions(format: .lottie, sceneID: "scene-1",
                                                                             frames: 0...0)).isEmpty)
        await #expect(throws: NotBuilt(reason: "Not connected yet (FX-8).")) {
            try await bytes(off, FlareFixtures.bounce, .svgFrame)
        }
    }
}
