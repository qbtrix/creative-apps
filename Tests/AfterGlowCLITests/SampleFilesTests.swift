// SampleFilesTests.swift (sample-files SS-1, docs/blueprints/suite/features/sample-files.md):
// each sample the tour opens is a real document, not just a file. For every file
// SampleCatalog names, and the three journey-only fixtures (Logo.design,
// Title.flare, Logo.flare, which live only in UITests/Fixtures/suite/), one test:
// the file is there, opens with its app's headless open, has the content its
// make script promises (counts from the app's summary) and re-saves without
// error. Each stays disabled, naming the slice that makes its file, until that
// slice lands. Tests/SuiteModelTests/SampleFilesTests.swift is the presence-only
// check; this suite is SampleOpenTests so the two never clash.
import AfterGlowCLICore
import Foundation
import LibraryModel
import SuiteKernel
import SuiteModel
import Testing

@Suite struct SampleOpenTests {
    /// The repo's root: three folders up from this file.
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let samples = "Bundle/Samples", fixtures = "UITests/Fixtures/suite"

    /// The bytes of `name` under `folder`; a catalog sample must also be one SampleCatalog names.
    static func bytes(_ name: String, in folder: String) throws -> Data {
        if folder == samples { _ = try #require(SampleCatalog.samples.first { $0.fileName == name }, "\(name) isn't in SampleCatalog") }
        let url = root.appendingPathComponent(folder).appendingPathComponent(name)
        #expect(FileManager.default.fileExists(atPath: url.path), "missing \(folder)/\(name)")
        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty, "\(folder)/\(name) is empty")
        return data
    }

    /// Opens `name` with `app`'s headless open, re-saves it, and returns its summary's fields.
    static func open(_ name: String, in folder: String, app: String) throws -> [String: JSONValue] {
        let headless = try #require(Apps.named(app, in: Apps.all))
        let session = try headless.session(open: try bytes(name, in: folder), name: name)
        let saved = try session.save()
        #expect(!saved.isEmpty, "\(name) re-saved empty")
        guard case .object(let fields) = session.summary() else { Issue.record("\(name): summary isn't an object"); return [:] }
        return fields
    }

    /// The objects in the summary's array `key` ("pages", "scenes", "compositions", "layers").
    static func items(_ fields: [String: JSONValue], _ key: String) -> [[String: JSONValue]] {
        guard case .array(let values) = fields[key] else { return [] }
        return values.compactMap { if case .object(let item) = $0 { item } else { nil } }
    }

    /// The number at `key` in one summary item, 0 when absent.
    static func number(_ item: [String: JSONValue], _ key: String) -> Double {
        if case .number(let value) = item[key] { value } else { 0 }
    }

    @Test(.disabled("SS-3: Cards.design is made in SS-vector")) func testCards() throws {
        let pages = Self.items(try Self.open("Cards.design", in: Self.samples, app: "design"), "pages")
        // Three cards, each with at least a shape and a title.
        #expect(pages.reduce(0) { $0 + Self.number($1, "layers") } >= 6)
    }

    @Test(.disabled("SS-3: Logo.design is made in SS-vector")) func testLogoDesign() throws {
        let pages = Self.items(try Self.open("Logo.design", in: Self.fixtures, app: "design"), "pages")
        #expect(pages.reduce(0) { $0 + Self.number($1, "layers") } >= 1)
    }

    @Test(.disabled("SS-4: Bounce.flare is made in SS-flare")) func testBounce() throws {
        let scene = try #require(Self.items(try Self.open("Bounce.flare", in: Self.samples, app: "flare"), "scenes").first)
        let fps = Self.number(scene, "fps")
        try #require(fps > 0)
        // A 2 s loop holding the ball.
        #expect(Self.number(scene, "frames") / fps == 2)
        #expect(Self.number(scene, "layers") >= 1)
    }

    @Test(.disabled("SS-4: Title.flare is made in SS-flare")) func testTitle() throws {
        let scenes = Self.items(try Self.open("Title.flare", in: Self.fixtures, app: "flare"), "scenes")
        #expect(scenes.reduce(0) { $0 + Self.number($1, "layers") } >= 1)
    }

    @Test(.disabled("SS-4: Logo.flare is made in SS-flare")) func testLogoFlare() throws {
        let scenes = Self.items(try Self.open("Logo.flare", in: Self.fixtures, app: "flare"), "scenes")
        #expect(scenes.reduce(0) { $0 + Self.number($1, "layers") } >= 1)
    }

    @Test(.disabled("SS-5: beach.ora is made in SS-photo")) func testBeach() throws {
        let fields = try Self.open("beach.ora", in: Self.samples, app: "photo")
        // The gradient photo, a second pixel layer and the Exposure adjustment.
        #expect(Self.items(fields, "layers").count == 3)
        #expect(Self.number(fields, "width") > 0 && Self.number(fields, "height") > 0)
    }

    @Test(.disabled("SS-5: Sunset.png is made in SS-photo")) func testSunset() throws {
        let fields = try Self.open("Sunset.png", in: Self.samples, app: "photo")
        #expect(Self.number(fields, "width") > 0 && Self.number(fields, "height") > 0)
        // The tour's Library tile imports it into the person's catalog.
        var library = try LibraryHeadless.new(.object([:]))
        try library.importImage(try Self.bytes("Sunset.png", in: Self.samples), name: "Sunset.png")
        #expect(library.library.items.count == 1)
        #expect(!(try library.save()).isEmpty)
    }

    @Test(.disabled("SS-6: Intro.halo is made in SS-halo")) func testIntro() throws {
        let comp = try #require(Self.items(try Self.open("Intro.halo", in: Self.samples, app: "halo"), "compositions").first)
        let fps = Self.number(comp, "fps")
        try #require(fps > 0)
        // A 5 s comp: a solid, the title and the sliding shape.
        #expect(Self.number(comp, "frames") / fps == 5)
        #expect(Self.number(comp, "layers") == 3)
    }
}
