// PhotoJourneyTests+Retouch.swift: PJ-FH1 and PJ-FH2, fill and heal in Photo
// (fill-heal FH-3; docs/blueprints/suiteui/features/fill-heal.md, Journey
// steps). On sky.png (the 800 x 600 test photo): G picks the Paint Bucket,
// Tool Options shows Tolerance, Contiguous and All Layers
// (`photo.tool.tolerance`, `.contiguous`, `.all-layers`), a click in the sky
// fills it and Command-Z takes it back; J picks Spot Heal with Size and
// Hardness, a click heals a spot, Remove paints over the sun and Command-Z
// restores it. Written in FH-3 and skipped until FH-8 wires the tools to
// their commands (`live` turns them on). Shots `retouch-bucket-options`,
// `retouch-bucket-filled`, `retouch-spot-heal`, `retouch-removed`.
import CoreGraphics
import XCTest

final class PhotoRetouchJourneyTests: XCTestCase {
    /// False until fill-heal FH-8 enables the tools.
    private static let live = false

    /// PJ-FH1: G, Tolerance 32, click the sky, Undo once.
    @MainActor func testPaintBucket() throws {
        try XCTSkipUnless(Self.live, "waits on fill-heal FH-8: the retouch tools are disabled until then")
        let photo = try openSky()
        photo.press(character: "g")
        let tool = photo.element("suite.tools").buttons["Paint Bucket"]
        XCTAssert(tool.waitForExistence(timeout: 5) && tool.isSelected, "G didn't pick the Paint Bucket")
        for id in ["photo.tool.tolerance", "photo.tool.contiguous", "photo.tool.all-layers"] {
            XCTAssert(photo.element(id).waitForExistence(timeout: 5), "no \(id) in Tool Options")
        }
        photo.shot("retouch-bucket-options")
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.1, dy: 0.1), to: CGVector(dx: 0.1, dy: 0.1))
        photo.shot("retouch-bucket-filled")
        photo.press(character: "z", .command)
    }

    /// PJ-FH2: J, click a spot, Remove over the sun, Undo once.
    @MainActor func testSpotHealAndRemove() throws {
        try XCTSkipUnless(Self.live, "waits on fill-heal FH-8: the retouch tools are disabled until then")
        let photo = try openSky()
        photo.press(character: "j")
        let spot = photo.element("suite.tools").buttons["Spot Heal"]
        XCTAssert(spot.waitForExistence(timeout: 5) && spot.isSelected, "J didn't pick Spot Heal")
        XCTAssert(photo.element("photo.tool.size").exists && photo.element("photo.tool.hardness").exists,
                  "Spot Heal shows no Size or Hardness")
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.3, dy: 0.3), to: CGVector(dx: 0.3, dy: 0.3))
        photo.shot("retouch-spot-heal")
        photo.element("suite.tools").buttons["Remove"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.62, dy: 0.5), to: CGVector(dx: 0.78, dy: 0.5))
        photo.shot("retouch-removed")
        photo.press(character: "z", .command)
    }

    @MainActor private func openSky() throws -> Journey {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-retouch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "sky.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.window(named: "sky.png").waitForExistence(timeout: 30), "sky.png didn't open")
        return photo
    }
}
