// PhotoJourneyTests+Fixtures.swift: the helpers every Photo journey file
// calls (photo-journey-kit; docs/blueprints/photo/features/photo-journey-kit.md).
// writeTestPhoto writes the test photo a journey opens, and photoArguments
// builds the launch arguments that skip the system panels (-PhotoOpenFile,
// -PhotoSaveTo, -PhotoExportTo, -PhotoRecoveryDir) or pick a fixture or a
// window width. Every launch autosaves into its own recovery folder: a new
// temp folder unless the journey passes `recoveryDir:` (PJ-3 does, to relaunch
// on its autosave), so one journey's autosave never reaches the shared
// Application Support/Photo/Recovery and offers a restore to every later
// launch. expectMenuReason reads a menu item's help from the window's
// `photo.menu.reasons`, since XCUITest reads no text from a help tag.
// PhotoJourneyKitTests.testWrittenPhotoOpens proves both: the
// arguments are spelled right, and a written beach.png opens to the v1 open
// state, shot as "kit-opened".
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

/// Writes the test photo as a PNG: 800 x 600 by default (sky gradient, sun at (560, 220), r 90);
/// the hitch probe asks for 4000 x 3000. Drawn on the 800 x 600 plan and scaled to `width` x `height`.
func writeTestPhoto(to url: URL, width: Int = 800, height: Int = 600) throws {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
        let gradient = CGGradient(
            colorsSpace: space,
            colors: [CGColor(srgbRed: 0.16, green: 0.42, blue: 0.86, alpha: 1),
                     CGColor(srgbRed: 0.98, green: 0.62, blue: 0.42, alpha: 1)] as CFArray,
            locations: [0, 1])
    else { throw CocoaError(.fileWriteUnknown) }
    context.scaleBy(x: CGFloat(width) / 800, y: CGFloat(height) / 600)
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 600), end: CGPoint(x: 0, y: 0), options: [])
    context.setFillColor(CGColor(srgbRed: 1, green: 0.86, blue: 0.3, alpha: 1))
    context.fillEllipse(in: CGRect(x: 470, y: 290, width: 180, height: 180))
    guard let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

/// Launch arguments for a Photo journey; nil arguments are left out, except
/// `recoveryDir`: nil means a new temp folder, so `-PhotoRecoveryDir` is
/// always passed exactly once and the journey's own folder is the only one.
func photoArguments(
    open file: URL? = nil, saveTo: URL? = nil, exportTo: URL? = nil,
    fixture: String? = nil, recoveryDir: URL? = nil, windowWidth: Int? = nil
) -> [String] {
    var arguments = [String]()
    if let file { arguments += ["-PhotoOpenFile", file.path] }
    if let saveTo { arguments += ["-PhotoSaveTo", saveTo.path] }
    if let exportTo { arguments += ["-PhotoExportTo", exportTo.path] }
    if let fixture { arguments += ["-PhotoFixture", fixture] }
    let recovery = recoveryDir
        ?? FileManager.default.temporaryDirectory.appending(path: "photo-journey-recovery-\(UUID().uuidString)")
    arguments += ["-PhotoRecoveryDir", recovery.path]
    if let windowWidth { arguments += ["-PhotoWindowWidth", "\(windowWidth)"] }
    return arguments
}

/// The Edit or Layer menu's `item` says `help` ("Paste: Nothing to paste."),
/// read from the window's `photo.menu.reasons`: XCUITest reads a menu item's
/// help tag as no text (run 38808431710's hierarchy has the tag, sized to its
/// words, with no label, title or value). The menus build their help from
/// the same `PhotoMenu.editHelpText`.
@MainActor func expectMenuReason(_ item: String, in menu: String, help: String, _ photo: Journey) {
    let reasons = photo.app.descendants(matching: .any).matching(NSPredicate(
        format: "identifier == 'photo.menu.reasons' AND label CONTAINS %@", "\(item): \(help)")).firstMatch
    let shown = photo.element("photo.menu.reasons")
    XCTAssert(
        reasons.waitForExistence(timeout: 5),
        "\(menu) > \(item) doesn't say \(help) (photo.menu.reasons reads \(shown.exists ? shown.label : "nothing"))")
}

final class PhotoJourneyKitTests: XCTestCase {
    /// The arguments are spelled right; a written beach.png opens, titled
    /// beach.png, with its canvas and nothing over the window (no restore
    /// offer, sheet or dialog): the v1 open state.
    @MainActor func testWrittenPhotoOpens() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-kit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "beach.png")
        let fresh = photoArguments()
        XCTAssertEqual(fresh.count, 2, "photoArguments() isn't just its own -PhotoRecoveryDir: \(fresh)")
        XCTAssertEqual(fresh.first, "-PhotoRecoveryDir", "photoArguments() passes no recovery folder")
        XCTAssertNotEqual(fresh.last, photoArguments().last, "two photoArguments() calls share a recovery folder")
        let recovery = folder.appending(path: "recovery")
        XCTAssertEqual(
            photoArguments(open: file, fixture: "sample", recoveryDir: recovery),
            ["-PhotoOpenFile", file.path, "-PhotoFixture", "sample", "-PhotoRecoveryDir", recovery.path],
            "photoArguments(open:fixture:recoveryDir:)")

        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.app.windows["beach.png"].waitForExistence(timeout: 30), "beach.png didn't open")
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        XCTAssertFalse(
            photo.app.buttons["photo.recovery.restore"].waitForExistence(timeout: 5),
            "a restore offer covers the opened window: another launch's autosave reached this one")
        XCTAssertFalse(photo.app.sheets.firstMatch.exists, "a sheet covers the opened window")
        XCTAssertFalse(photo.app.dialogs.firstMatch.exists, "a dialog covers the opened window")
        photo.shot("kit-opened")
    }
}
