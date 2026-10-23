// CropCommandsTests.swift (orientation-crop OC-m): the image and crop commands run their rule on a
// target as one named undo step each, and CropAspect codes as Library's raw keys.
import Testing
import SuiteKernel

@Suite struct CropCommandsTests {
    static func near(_ a: Rect, _ b: Rect) -> Bool {
        abs(a.minX - b.minX) < 1e-9 && abs(a.minY - b.minY) < 1e-9 && abs(a.maxX - b.maxX) < 1e-9 && abs(a.maxY - b.maxY) < 1e-9
    }

    /// A turn, a flip and a half turn each face the image one new way as one named step.
    @Test func oneStep() throws {
        let catalog = try CropShapeTarget.catalog()
        var photo = CropShapeTarget()
        let cw = try catalog.run("image.rotate-cw", params: .object([:]), on: &photo)
        #expect(cw == CommandOutcome(result: .object(["orientation": .number(6)]), undoStep: "Rotate Right"))
        _ = try catalog.run("image.flip", params: .object(["axis": .string("vertical")]), on: &photo)
        #expect(photo.orientation == Orientation.right.flipped(.vertical) && photo.history.undoName == "Flip Vertical")
        _ = try catalog.run("image.rotate-180", params: .object([:]), on: &photo)
        _ = try catalog.run("image.rotate-ccw", params: .object([:]), on: &photo)
        #expect(photo.history.steps == ["Rotate Right", "Flip Vertical", "Rotate 180°", "Rotate Left"])
        #expect(photo.orientation == .right.flipped(.vertical).rotated(clockwise: true).rotated(clockwise: true).rotated(clockwise: false))
    }

    /// 4:5 portrait frames the tallest centred 4:5 of the unit square; swap turns it; apply and
    /// reset each take one step; a frame outside the bounds is refused.
    @Test func cropRunsTheRules() throws {
        let catalog = try CropShapeTarget.catalog()
        var photo = CropShapeTarget()
        #expect(throws: CatalogError.self) { try catalog.run("crop.swap", params: .object([:]), on: &photo) }
        _ = try catalog.run("crop.set-aspect", params: .object(["aspect": .string("4:5"), "orientation": .string("portrait")]), on: &photo)
        #expect(Self.near(try #require(photo.cropFrame).rect, Rect(minX: 0.1, minY: 0, maxX: 0.9, maxY: 1)))
        _ = try catalog.run("crop.swap", params: .object([:]), on: &photo)
        #expect(Self.near(try #require(photo.cropFrame).rect, Rect(minX: 0, minY: 0.1, maxX: 1, maxY: 0.9)))
        let bad = JSONValue.object(["x": .number(0.5), "y": .number(0), "w": .number(0.6), "h": .number(1)])
        #expect(throws: CatalogError.self) { try catalog.run("crop.set-frame", params: bad, on: &photo) }
        _ = try catalog.run("crop.apply", params: .object([:]), on: &photo)
        _ = try catalog.run("crop.reset", params: .object([:]), on: &photo)
        #expect(photo.applied == 1 && photo.cropFrame == nil)
        #expect(photo.history.steps == ["Crop Ratio", "Swap Crop", "Crop", "Reset Crop"])
    }

    /// The aspect codes as its raw key, so Library's stored "4:5" and "Original" read back.
    @Test func aspectCodesAsItsKey() throws {
        #expect(try JSONValue(encoding: CropAspect.ratio(width: 4, height: 5)) == .string("4:5"))
        #expect(try JSONValue.string("Original").decode(CropAspect.self) == .original)
        #expect(throws: (any Error).self) { try JSONValue.string("4:0").decode(CropAspect.self) }
    }
}
