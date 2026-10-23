// DocumentSetupTests.swift (document-setup DS-2; MJ-DS): sizes convert between units at the document's
// resolution to whole pixels, each field gets its own problem, orientation swaps the sides, a hex background
// with no alpha reads transparent (DS-3), and document.set-settings plans the content offset for its anchor,
// keeps the duration in seconds across a rate change and is one undo step (DS-4). The spec shape runs now.
import Testing
import SuiteKernel

/// A document for the settings commands: its setup, its limits, the anchors it was given and one history.
private final class FakeSetupDoc: DocumentSetupTarget {
    var documentSetup: DocumentSetup
    let documentLimits = DocumentLimits(maxSide: 16_384, rates: [FrameRate(whole: 25), FrameRate(whole: 30)], maxSeconds: 3_600)
    var history = History<DocumentSetup>(), anchors: [BoxAnchor] = []
    init(_ setup: DocumentSetup) { documentSetup = setup }
    func apply(_ setup: DocumentSetup, anchor: BoxAnchor) throws {
        history.record("Document Settings", documentSetup)
        (documentSetup, anchors) = (setup, anchors + [anchor])
    }
}

/// A 1920 × 1080 px, 30 fps, 10 s document and the catalog of the two specs.
private func tenSeconds() throws -> (FakeSetupDoc, CommandCatalog<any DocumentSetupTarget>) {
    let doc = FakeSetupDoc(DocumentSetup(width: 1920, height: 1080, frameRate: FrameRate(whole: 30), durationSeconds: 10))
    let catalog = try CommandCatalog(app: "test", DocumentSetupCommands.specs) { ($0 as? FakeSetupDoc)?.history ?? History<DocumentSetup>() }
    return (doc, catalog)
}

@Suite struct DocumentSetupTests {
    static let print = DocumentSetup(width: 4, height: 6, unit: .inch, resolution: 300, background: .transparent)

    /// DS-1: both specs, their kinds and schemas; set takes an anchor; file.new's setup schema takes a print size.
    @Test func specsHaveSchemas() throws {
        let specs = DocumentSetupCommands.specs
        #expect(specs.map(\.id) == ["document.read-settings", "document.set-settings"] && specs.map(\.kind) == [.query, .edit])
        for spec in specs { #expect(spec.params.validate(spec.example).isEmpty && !spec.title.isEmpty, "\(spec.id)") }
        let set = try #require(specs.last)
        #expect(set.params.validate(.object(["anchor": .string("bottom"), "duration": .number(15)])).isEmpty)
        #expect(!set.params.validate(.object(["anchor": .string("middle")])).isEmpty)
        let printParams = JSONValue.object(["width": .number(4), "height": .number(6), "unit": .string("in"),
                                            "resolution": .number(300), "background": .string("transparent")])
        #expect(DocumentSetupCommands.setupSchema.validate(printParams).isEmpty)
        #expect(!DocumentSetupCommands.setupSchema.validate(.object(["height": .number(6)])).isEmpty)
        #expect(LengthUnit.allCases.map(\.rawValue) == ["px", "pt", "in", "cm", "mm"])
    }

    /// 4 × 6 in at 300 ppi is 1200 × 1800; 10 cm is 1181; 5 cm rounds up to 591; 72 pt and 25.4 mm are an inch; px ignores ppi.
    @Test func unitsToPixels() {
        #expect(Self.print.pixelSize == (1200, 1800))
        #expect(DocumentSetup(width: 10, height: 5, unit: .cm, resolution: 300).pixelSize == (1181, 591))
        #expect(DocumentSetup(width: 72, height: 25.4, unit: .pt, resolution: 300).pixelSize.width == 300)
        #expect(DocumentSetup(width: 72, height: 25.4, unit: .mm, resolution: 300).pixelSize.height == 300)
        #expect(DocumentSetup(width: 1920, height: 1080, resolution: 300).pixelSize == (1920, 1080))
        #expect(DocumentSetup(width: .nan, height: .infinity, unit: .inch).pixelSize == (0, 0))
    }

    /// A unit change converts the numbers and keeps the pixels.
    @Test func unitChangeKeepsPixels() {
        let cm = Self.print.converted(to: .cm), px = Self.print.converted(to: .px)
        #expect(cm.unit == .cm && abs(cm.width - 10.16) < 1e-9 && cm.pixelSize == (1200, 1800))
        #expect(px.unit == .px && px.width == 1200 && px.height == 1800)
        #expect(px.converted(to: .mm).pixelSize == (1200, 1800) && abs(px.converted(to: .pt).width - 288) < 1e-9)
    }

    /// Each problem is on its own field with its sentence: 0 width, a height past the limit, 0 ppi, a rate and a duration.
    @Test func problemsPerField() {
        let still = DocumentLimits()
        #expect(DocumentSetup(width: 0, height: 1080).problems(still) == [SetupProblem(.width, "Width must be 1 to 16384 px.")])
        #expect(DocumentSetup(width: 100, height: 0).problems(still) == [SetupProblem(.height, "Height must be 1 to 16384 px.")])
        #expect(DocumentSetup(width: 100, height: 20_000).problems(DocumentLimits(maxSide: 30_000)).isEmpty)
        #expect(DocumentSetup(width: 20_000, height: 100).problems(still).map(\.field) == [.width])
        #expect(DocumentSetup(width: 100, height: 100, resolution: 0).problems(still).map(\.field) == [.resolution])
        #expect(DocumentSetup(width: 100, height: 100, background: .color(hex: "#12")).problems(still).map(\.field) == [.background])
        #expect(Self.print.problems(still).isEmpty && DocumentSetup(width: 1, height: 16_384).problems(still).isEmpty)
        let timed = DocumentLimits(rates: [FrameRate(whole: 30)], maxSeconds: 60)
        let comp = DocumentSetup(width: 1920, height: 1080, frameRate: FrameRate(whole: 30), durationSeconds: 10)
        #expect(comp.problems(timed).isEmpty && comp.problems(still).isEmpty)
        var off = comp
        (off.frameRate, off.durationSeconds) = (FrameRate(whole: 24), 0)
        #expect(off.problems(timed).map(\.field) == [.frameRate, .duration])
        off.durationSeconds = 61
        #expect(off.problems(timed).last?.text == "Duration must be more than 0 and at most 60 seconds.")
    }

    /// Swap turns 1080 × 1920 into 1920 × 1080.
    @Test func swapTurnsTheSides() {
        let story = DocumentSetup(width: 1080, height: 1920).swapped()
        #expect(story.width == 1920 && story.height == 1080 && story.pixelSize == (1920, 1080))
    }

    /// "#00000000" reads transparent; names and hex parse and code as one string; junk doesn't.
    @Test func backgroundHex() throws {
        #expect(DocumentBackground(parsing: "#00000000") == .transparent && DocumentBackground(parsing: "#1B2A4A00") == .transparent)
        #expect(DocumentBackground(parsing: "white") == .white && DocumentBackground(parsing: "transparent") == .transparent)
        #expect(DocumentBackground(parsing: "#1b2a4a") == .color(hex: "#1B2A4A") && DocumentBackground(parsing: "#1B2A4AFF") == .color(hex: "#1B2A4AFF"))
        #expect(DocumentBackground(parsing: "navy") == nil && DocumentBackground(parsing: "#1B2A4") == nil && DocumentBackground(parsing: "#GGGGGG") == nil)
        let decoded = try JSONValue.object(["width": .number(4), "height": .number(6), "background": .string("#00000000")]).decode(DocumentSetup.self)
        #expect(decoded == DocumentSetup(width: 4, height: 6, background: .transparent))
        #expect(try JSONValue(encoding: DocumentBackground.color(hex: "#1B2A4A")) == .string("#1B2A4A"))
        #expect(try JSONValue(encoding: Self.print).decode(DocumentSetup.self) == Self.print)
    }

    /// Growing 1920 × 1080 to 1920 × 1200 anchored bottom moves content down 120, as one undo step; a rate
    /// change keeps the duration in seconds; a duration change is its own step.
    @Test func settings() throws {
        var (doc, catalog) = try tenSeconds()
        var target: any DocumentSetupTarget = doc
        let grow = try catalog.run("document.set-settings", params: .object(["height": .number(1200), "anchor": .string("bottom")]), on: &target)
        guard case .object(let read) = grow.result else { Issue.record("no reading"); return }
        #expect(read["offsetX"] == .number(0) && read["offsetY"] == .number(120) && read["pixelHeight"] == .number(1200))
        #expect(grow.undoStep == "Document Settings" && doc.history.steps.count == 1 && doc.anchors == [.bottom])
        _ = try catalog.run("document.set-settings", params: .object(["frameRate": .object(["num": .number(25), "den": .number(1)])]), on: &target)
        #expect(doc.documentSetup.frameRate == FrameRate(whole: 25) && doc.documentSetup.durationSeconds == 10)
        _ = try catalog.run("document.set-settings", params: .object(["duration": .number(15), "background": .string("#1B2A4A")]), on: &target)
        #expect(doc.documentSetup.durationSeconds == 15 && doc.documentSetup.background == .color(hex: "#1B2A4A"))
        #expect(doc.history.steps.count == 3 && doc.documentSetup.pixelSize == (1920, 1200))
        (doc, catalog) = try tenSeconds()
        try DocumentSetupCommands.run("document.set-settings", .object(["width": .number(2000), "height": .number(1200)]), on: doc)
        #expect(doc.anchors == [.center])
        #expect(DocumentSetupCommands.offset(from: DocumentSetup(width: 1920, height: 1080), to: DocumentSetup(width: 2000, height: 1200),
                                             anchor: .center) == Point(x: 40, y: 60))
    }

    /// Read answers the setup and its pixels; a set with a problem is refused and writes nothing.
    @Test func readAndRefuse() throws {
        let (doc, catalog) = try tenSeconds()
        var target: any DocumentSetupTarget = doc
        let read = try catalog.run("document.read-settings", params: .object([:]), on: &target)
        #expect(read.undoStep == nil)
        guard case .object(let fields) = read.result else { Issue.record("no reading"); return }
        #expect(fields["pixelWidth"] == .number(1920) && fields["duration"] == .number(10) && fields["unit"] == .string("px"))
        #expect(throws: CatalogError.failed(id: "document.set-settings", message: "Width must be 1 to 16384 px.")) {
            try catalog.run("document.set-settings", params: .object(["width": .number(0)]), on: &target)
        }
        #expect(throws: CatalogError.self) {
            try catalog.run("document.set-settings", params: .object(["frameRate": .object(["num": .number(24), "den": .number(1)])]), on: &target)
        }
        #expect(doc.history.steps.isEmpty && doc.anchors.isEmpty && doc.documentSetup.width == 1920)
    }
}
