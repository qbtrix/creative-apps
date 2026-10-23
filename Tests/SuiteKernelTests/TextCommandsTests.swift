// TextCommandsTests.swift (text-style TS-1 written, TS-6 on): the seven text commands on a test target with a kernel
// `History`: the specs' ids, titles, kinds and availability, the intents' commands, each run being one undo step, a
// scrub under one drag token being one step, and the nearest-face rule.
import Testing
import SuiteKernel

/// One selected text layer (or none), its history folding steps by drag token, and a face list per family.
struct TextDoc: TextStyleTarget {
    var style: TextStyle? = .standard
    var help: String?
    var history = History<TextStyle?>()
    static let all = (1...9).flatMap { w in [(weight: w * 100, italic: false), (weight: w * 100, italic: true)] }
    static let families: [String: [(weight: Int, italic: Bool)]] = [
        "System": all, "Serif": [(400, false), (600, false), (800, false)],
    ]
    var textStyle: TextStyle? { style }
    var textHelp: String? { help }
    func faces(of family: String) -> [(weight: Int, italic: Bool)] { Self.families[family] ?? [] }
    mutating func setTextStyle(_ s: TextStyle, name: String, drag: String?) throws {
        history.record(name, style, key: drag.map { "\(name):\($0)" }); style = s
    }
    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = style
        let moved = history.undo { old in defer { current = old }; return current }
        style = current
        return moved
    }
}

@Suite struct TextCommandsTests {
    static let catalog = (try? CommandCatalog(app: "test", TextCommands.specs(TextDoc.self), history: { $0.history }))
    static let titles = ["text.set-font": "Font", "text.set-size": "Text Size", "text.set-italic": "Italic",
                         "text.set-alignment": "Alignment", "text.set-line-height": "Line Height", "text.set-tracking": "Letter Spacing"]

    @Test func specsAreTheSevenWithTheirTitlesAndIntents() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == (Array(Self.titles.keys) + ["text.read"]).sorted())
        #expect(catalog.spec("text.read")?.kind == .query)
        for (id, title) in Self.titles {
            let spec = try #require(catalog.spec(id))
            #expect(spec.kind == .edit && spec.title == title, "\(id)")
            #expect(spec.params.validate(spec.example).isEmpty, "\(id)")
            #expect(catalog.availability(id, on: TextDoc()) == .available, "\(id)")
        }
        #expect(TextIntent.lineHeight(1.5, drag: "d1").command.id == "text.set-line-height")
        #expect(TextIntent.lineHeight(1.5, drag: "d1").command.params == .object(["value": .number(1.5), "drag": .string("d1")]))
        #expect(TextIntent.alignment(.justified).command.params == .object(["alignment": .string("justified")]))
        #expect(TextIntent.font(family: "Serif", weight: 600, italic: false).command.id == "text.set-font")
        #expect(TextIntent.tracking(20, drag: nil).command.params == .object(["value": .number(20)]))
    }
    @Test func eachCommandIsOneStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = TextDoc()
        let runs: [(String, JSONValue)] = [
            ("text.set-font", .object(["family": .string("Serif")])), ("text.set-size", .object(["size": .number(36)])),
            ("text.set-italic", .object(["on": .bool(true)])), ("text.set-alignment", .object(["alignment": .string("justified")])),
            ("text.set-line-height", .object(["value": .number(1.5)])), ("text.set-tracking", .object(["value": .number(20)])),
        ]
        doc.style?.family = "System"
        for (count, (id, params)) in runs.enumerated() where id != "text.set-font" {
            let outcome = try catalog.run(id, params: params, on: &doc)
            #expect(outcome.undoStep == Self.titles[id] && doc.history.steps.count == count, "\(id)")
        }
        #expect(doc.style?.size == 36 && doc.style?.italic == true && doc.style?.paragraph.alignment == .justified)
        #expect(doc.style?.paragraph.lineHeight == 1.5 && doc.style?.paragraph.tracking == 20)
        _ = try catalog.run("text.set-font", params: .object(["family": .string("Serif")]), on: &doc)
        #expect(doc.history.steps.last == "Font" && doc.style?.family == "Serif")
        #expect(try catalog.run("text.read", params: .object([:]), on: &doc).undoStep == nil)
    }
    @Test func lineHeightScrubIsOneStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = TextDoc()
        for sample in 0..<60 {
            let params = TextIntent.lineHeight(1.2 + Double(sample) / 50, drag: "scrub-1").command.params
            _ = try catalog.run("text.set-line-height", params: params, on: &doc)
        }
        #expect(doc.history.steps == ["Line Height"])
        #expect(doc.undo() && doc.style?.paragraph.lineHeight == 1.2)
    }
    @Test func setFontPicksTheNearestFace() throws {
        let catalog = try #require(Self.catalog)
        var doc = TextDoc()
        doc.style?.weight = 700
        doc.style?.italic = true
        _ = try catalog.run("text.set-font", params: .object(["family": .string("Serif")]), on: &doc)
        // Serif has 400, 600 and 800 upright: 600 and 800 tie for 700, ties go lighter; no italic face.
        #expect(doc.style?.family == "Serif" && doc.style?.weight == 600 && doc.style?.italic == false)
        _ = try catalog.run("text.set-font", params: .object(["family": .string("System")]), on: &doc)
        #expect(doc.style?.weight == 600 && doc.style?.italic == false)
        #expect(throws: CatalogError.self) { try catalog.run("text.set-font", params: .object(["family": .string("Nope")]), on: &doc) }
        #expect(doc.style?.family == "System")
    }
    @Test func noTextSelectedIsUnavailableWithTheReason() throws {
        let catalog = try #require(Self.catalog)
        let none = TextDoc(style: nil, help: "Select a text layer first.")
        for id in catalog.ids { #expect(catalog.availability(id, on: none) == .unavailable("Select a text layer first."), "\(id)") }
        var serif = TextDoc()
        serif.style?.family = "Serif"
        #expect(catalog.availability("text.set-italic", on: serif) == .unavailable("This family has no italic."))
        #expect(catalog.availability("text.set-size", on: serif) == .available)
    }
}
