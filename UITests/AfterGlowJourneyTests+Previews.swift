// AfterGlowJourneyTests+Previews.swift: HJ-ST (shared-thumbnails; ST-4 written, ST-8 turns it on).
// Step 1: on `weekOfWork` every Recent card that isn't Missing answers: its preview or its app's mark
// (the fixture publishes no previews, so on live services they show their marks).
// Step 2 (live): Photo opens Beach.png, saves it as Beach.ora into `-PhotoSaveTo`'s folder over the
// same `-SuiteSupportDir` and quits; the home's newest card is Beach.ora and shows its preview.
// Photo's shots skip the audit: this bundle attaches only the launcher's counts.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class HomePreviewsJourneyTests: XCTestCase {
    @MainActor func testHomeShowsDocumentPreviews() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        XCTAssert(AfterGlowJourneyTests.waitForCards(home, AfterGlowJourneyTests.weekOfWork), "RECENT doesn't list the week")
        let cards = home.app.descendants(matching: .any).matching(AfterGlowJourneyTests.cardPredicate)
        let shown = { (card: XCUIElement) -> Bool in
            let value = card.value as? String ?? ""
            return value.hasPrefix("Missing") || value.contains(", preview") || value.contains(", app mark")
        }
        let answered = expectation(for: NSPredicate { _, _ in cards.allElementsBoundByIndex.allSatisfy(shown) },
                                   evaluatedWith: NSNull())
        wait(for: [answered], timeout: 15)

        // Step 2: Photo saves Beach.ora; its thumbnail is the home's newest card.
        let folder = suite.support.appending(path: "previews-journey")
        let saves = folder.appending(path: "saves")
        try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
        let png = folder.appending(path: "Beach.png")
        try Self.writeBeach(to: png)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let photo = Journey(bundlePath: root.appending(path: ".build/apps/PhotoApp.app").path,
                            bundleID: SuiteApp.photo.bundleID, auditKey: SuiteApp.photo.rawValue, self)
        photo.app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-SuiteSupportDir", suite.support.path,
                                     "-PhotoOpenFile", png.path, "-PhotoSaveTo", saves.path,
                                     "-PhotoRecoveryDir", folder.appending(path: "recovery").path]
        photo.app.launch()
        photo.app.activate()
        let opened = photo.app.windows.matching(NSPredicate(format: "title CONTAINS %@ OR label CONTAINS %@",
                                                            "Beach.png", "Beach.png")).firstMatch
        XCTAssert(opened.waitForExistence(timeout: 30), "Photo didn't open Beach.png")
        photo.press(character: "n", [.command, .shift])
        photo.press(character: "s", .command)
        let keep = photo.app.sheets.buttons["photo.file.keep-layers.document"].firstMatch
        XCTAssert(keep.waitForExistence(timeout: 10), "Save on a layered PNG didn't ask Keep layers?")
        keep.click()
        let saved = photo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'photo.bar.saved' AND label == 'Saved'")).firstMatch
        XCTAssert(saved.waitForExistence(timeout: 30), "Save as Photo Document never read Saved")
        XCTAssert(FileManager.default.fileExists(atPath: saves.appending(path: "Beach.ora").path), "Beach.ora wasn't written")
        photo.press(character: "q", .command)
        if !photo.app.wait(for: .notRunning, timeout: 15) { photo.app.terminate() }

        home.app.activate()
        let newest = { () -> String in
            let sorted = cards.allElementsBoundByIndex.filter(\.exists).sorted {
                ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX)
            }
            guard let first = sorted.first else { return "" }
            return first.identifier + " " + (first.value as? String ?? "")
        }
        let beach = expectation(for: NSPredicate { _, _ in
            let card = newest()
            return card.contains("/Beach.ora ") && card.contains(", preview")
        }, evaluatedWith: NSNull())
        wait(for: [beach], timeout: 30)
        XCTAssert(newest().contains(", preview"), "the newest card isn't Beach.ora's preview: \(newest())")
        home.shot("home-recents-previews-live")
    }

    /// An 800 x 600 beach: sky over sand, written as a PNG.
    private static func writeBeach(to url: URL) throws {
        guard let context = CGContext(data: nil, width: 800, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(srgbRed: 0.45, green: 0.7, blue: 0.95, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        context.setFillColor(CGColor(srgbRed: 0.93, green: 0.82, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 220))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
