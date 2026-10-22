// FakeCanvasPlaceTests.swift (placed-images PL-9): the fake canvas takes placed images. A placed image and its asset
// survive save and open, two rects showing one file store one asset, a locked rect refuses with its reason, a file
// with no picture saves the JSON it did before pictures, and RJ-X36's steps save the rects its job file lists.
import Foundation
import Testing
import SuiteKernel

@Suite struct FakeCanvasPlaceTests {
    let catalog = FakeCanvasDocument.catalog
    static let jobs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/fake")
    /// RJ-X36's 1200 × 400 PNG.
    static func wide() throws -> Data { try Data(contentsOf: jobs.appendingPathComponent("place-image/input/wide.png")) }
    /// RJ-X36's canvas: one free 300 × 300 rect, selected.
    static let square = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 250, y: 150, w: 300, h: 300)], selection: 1)
    /// `place.image`'s params for `data`, into the selected rect with `fill`.
    static func place(_ data: Data, fill: Bool = false) -> JSONValue {
        .object(["name": .string("wide.png"), "base64": .string(data.base64EncodedString()), "fill": .bool(fill)])
    }
    /// The selected picture as `place.read` reports it.
    func read(_ doc: inout FakeCanvasDocument) throws -> [String: JSONValue] {
        guard case .object(let fields) = try catalog.run("place.read", params: .object([:]), on: &doc).result else { return [:] }
        return fields
    }

    @Test func theFakeListsThePlaceCommands() {
        #expect(PlaceCommands.specs(FakeCanvasDocument.self).map(\.id).allSatisfy(catalog.ids.contains))
        #expect(FakeCanvasDocument.fixture.placeHelp == nil && FakeCanvasDocument.fixture.placeFormats == [.png, .svg])
        #expect(catalog.availability("place.read", on: .fixture).why == "Select a placed image first.")
    }

    @Test func aPlacedImageAndItsAssetSurviveSaveAndOpen() throws {
        var doc = Self.square
        let placed = try catalog.run("place.image", params: Self.place(try Self.wide(), fill: true), on: &doc)
        #expect(placed.undoStep == "Place Image" && placed.result == .object(["id": .string("1")]) && doc.rects.count == 1)
        _ = try catalog.run("place.focus", params: .object(["x": .number(0.25), "y": .number(0.5)]), on: &doc)
        var opened = try FakeCanvasDocument.open(doc.save(), name: "one.fake")
        #expect(opened.rects == doc.rects && opened.assets == doc.assets && opened.assets.byID.count == 1)
        #expect(try opened.save() == doc.save())
        try opened.select(1)
        let fields = try read(&opened)
        #expect(fields["name"] == .string("wide.png") && fields["format"] == .string("png"))
        #expect(fields["width"] == .number(1200) && fields["height"] == .number(400))
        // Cover keeps 3:1: 900 × 300 over the square, a quarter of the way along the spare 600.
        #expect(try fields["drawn"] == JSONValue(encoding: Rect(minX: 100, minY: 150, maxX: 1000, maxY: 450)))
    }

    @Test func twoRectsShowingOneFileStoreOneAsset() throws {
        var doc = Self.square
        let file = Self.place(try Self.wide())
        _ = try catalog.run("place.image", params: file, on: &doc)
        _ = try catalog.run("place.image", params: file, on: &doc)
        #expect(doc.rects.compactMap(\.placed).count == 2 && doc.assets.byID.count == 1)
        guard case .object(let saved) = try JSONValue(json: doc.save()), case .array(let assets)? = saved["assets"] else {
            Issue.record("the saved file has no assets"); return
        }
        #expect(assets.count == 1)
        #expect(try FakeCanvasDocument.open(doc.save(), name: "two.fake").assets == doc.assets)
    }

    @Test func aLockedRectRefusesWithItsReason() throws {
        var doc = FakeCanvasDocument.fixture
        try doc.select(2)
        let before = try doc.save(), image = PlacedImage(assetID: "a", box: Rect(minX: 0, minY: 0, maxX: 10, maxY: 10))
        #expect(throws: CatalogError.unavailable(id: "place", why: "Unlock Rect 2 first.")) {
            try doc.setPlaced(image, asset: nil, name: "Place Image", drag: nil)
        }
        do {
            _ = try catalog.run("place.image", params: Self.place(try Self.wide(), fill: true), on: &doc)
            Issue.record("a locked rect took a picture")
        } catch { #expect("\(error)".contains("Unlock Rect 2 first.")) }
        #expect(try doc.save() == before && doc.history.steps.isEmpty && doc.assets.byID.isEmpty)
    }

    @Test func theOldAddRectJobsJSONIsUnchanged() throws {
        let input = try Data(contentsOf: Self.jobs.appendingPathComponent("add-rect/input/one.fake"))
        var doc = try FakeCanvasDocument.open(input, name: "one.fake")
        #expect(try doc.save() == input)
        _ = try catalog.run("rect.add", params: .object(["x": .number(1), "y": .number(2), "w": .number(3), "h": .number(4)]), on: &doc)
        let added = try doc.save()
        #expect(String(decoding: added, as: UTF8.self) == #"[{"h":60,"id":1,"locked":false,"name":"Rect 1","w":100,"x":10,"y":10},"#
                + #"{"h":4,"id":2,"locked":false,"name":"Rect 2","w":3,"x":1,"y":2}]"#)
        // A picture placed then undone stays in memory for redo, never in the file.
        _ = try catalog.run("place.image", params: Self.place(try Self.wide()), on: &doc)
        _ = try catalog.run("edit.undo", params: .object([:]), on: &doc)
        #expect(try doc.assets.byID.count == 1 && doc.save() == added)
    }

    /// RJ-X36: the job's steps, run through the catalog on its input, save its expected rects: the picture filled into
    /// the square, the 30-sample focus drag taken back by one undo.
    @Test func realJobX36PassesOnLinux() throws {
        let folder = Self.jobs.appendingPathComponent("place-image")
        guard case .object(let job) = try JSONValue(json: Data(contentsOf: folder.appendingPathComponent("place-image.jobs.json"))),
              case .array(let steps)? = job["steps"], case .object(let expect)? = job["expect"],
              case .object(let out)? = expect["out/one-placed.json"], let want = out["json"] else {
            Issue.record("place-image.jobs.json has no steps and expectation"); return
        }
        var doc = try FakeCanvasDocument.open(Data(contentsOf: folder.appendingPathComponent("input/one.fake")), name: "one.fake")
        #expect(doc.rects == Self.square.rects)
        var ids: [String] = []
        for case .object(let step) in steps {
            guard case .string(let id)? = step["id"] else { continue }
            if id == "place.image", case .object(let params)? = step["params"] {
                #expect(try params["base64"] == .string(Self.wide().base64EncodedString()) && params["fill"] == .bool(true))
            }
            _ = try catalog.run(id, params: step["params"] ?? .object([:]), on: &doc); ids.append(id)
        }
        #expect(ids.filter { $0 == "place.focus" }.count == 30 && ids.last == "edit.undo")
        #expect(doc.history.steps == ["Place Image"])
        #expect(try JSONValue(json: doc.save()) == want)
        let fields = try read(&doc)
        #expect(try fields["drawn"] == JSONValue(encoding: Rect(minX: -50, minY: 150, maxX: 850, maxY: 450)))
        #expect(fields["focus"] == .object(["x": .number(0.5), "y": .number(0.5)]))
    }
}
