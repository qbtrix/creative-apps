// PhotoJourneyTests+Retouch.swift: PJ-FH1 and PJ-FH2, fill and heal in Photo
// (fill-heal FH-3; docs/blueprints/suiteui/features/fill-heal.md, Journey
// steps). On sky.png (the 800 x 600 test photo): G picks the Paint Bucket,
// Tool Options shows Tolerance, Contiguous and All Layers
// (`photo.tool.tolerance`, `.contiguous`, `.all-layers`), a click in the sky
// fills it as one "Paint Bucket" step and Command-Z takes it back; J picks
// Spot Heal with Size and Hardness, a click on the sun's edge heals it as one
// "Spot Heal" step, Remove paints over the sun as one "Remove" step and
// Command-Z restores it. Written in FH-3, on since FH-8 wired the tools to
// their commands. Shift-J's cycle to Remove waits on #4890, so the palette
// picks it. Shots `retouch-bucket-options`, `retouch-bucket-filled`,
// `retouch-spot-heal`, `retouch-removed`.
import CoreGraphics
import XCTest

final class PhotoRetouchJourneyTests: XCTestCase {
    /// PJ-FH1: G, Tolerance 32, click the sky, Undo once.
    @MainActor func testPaintBucket() throws {
        let photo = try openSky()
        photo.press(character: "g")
        let tool = photo.element("suite.tools").buttons["Paint Bucket"]
        XCTAssert(tool.waitForExistence(timeout: 5) && tool.isSelected, "G didn't pick the Paint Bucket")
        for id in ["photo.tool.tolerance", "photo.tool.contiguous", "photo.tool.all-layers"] {
            XCTAssert(photo.element(id).waitForExistence(timeout: 5), "no \(id) in Tool Options")
        }
        photo.shot("retouch-bucket-options")
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.1, dy: 0.1), to: CGVector(dx: 0.1, dy: 0.1))
        expectStep("Undo Paint Bucket", photo, "the click made no Paint Bucket step")
        photo.shot("retouch-bucket-filled")
        photo.press(character: "z", .command)
        expectStep("Redo Paint Bucket", photo, "Command-Z didn't take the fill back in one step")
    }

    /// PJ-FH2: J, click a spot, Remove over the sun, Undo once.
    @MainActor func testSpotHealAndRemove() throws {
        let photo = try openSky()
        photo.press(character: "j")
        let spot = photo.element("suite.tools").buttons["Spot Heal"]
        XCTAssert(spot.waitForExistence(timeout: 5) && spot.isSelected, "J didn't pick Spot Heal")
        XCTAssert(photo.element("photo.tool.size").exists && photo.element("photo.tool.hardness").exists,
                  "Spot Heal shows no Size or Hardness")
        // The sun's left edge, so the spot has something to heal.
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.6, dy: 0.37), to: CGVector(dx: 0.6, dy: 0.37))
        expectStep("Undo Spot Heal", photo, "the click made no Spot Heal step")
        photo.shot("retouch-spot-heal")
        photo.element("suite.tools").buttons["Remove"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.64, dy: 0.37), to: CGVector(dx: 0.76, dy: 0.37))
        expectStep("Undo Remove", photo, "the stroke made no Remove step")
        photo.shot("retouch-removed")
        photo.press(character: "z", .command)
        expectStep("Redo Remove", photo, "Command-Z didn't restore the sun in one step")
        expectStep("Undo Spot Heal", photo, "the Remove stroke made more than one step")
    }

    /// Waits for the button titled `title`, such as the window toolbar's "Undo Remove".
    @MainActor private func expectStep(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
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
