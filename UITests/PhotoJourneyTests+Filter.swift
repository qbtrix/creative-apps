// PhotoJourneyTests+Filter.swift (adjust-everywhere AJ-3, AJ-4, AJ-9): the
// filter and look journeys on beach.png (800 x 600). PJ-AJ1: a marquee over
// the sun, Filter > Blur > Gaussian Blur…, Radius 8, OK: inside softens,
// outside doesn't, the sheet's Preview adds no step, and one Undo
// gives the opened picture back. PJ-AJ2: the High Contrast B&W look greys
// the picture, Save Look… "Mine" keeps it in the suite's look folder, and a
// second image opened over that folder takes Mine. Shots: `photo-filter-*`.
import XCTest

final class PhotoFilterJourneyTests: XCTestCase {
    /// The canvas regions the blur journey compares: inside the marquee, clear of its edge, and far outside it.
    static let inside = CGRect(x: 0.6, y: 0.45, width: 0.3, height: 0.4)
    static let outside = CGRect(x: 0.05, y: 0.05, width: 0.3, height: 0.25)

    /// PJ-AJ1: Marquee, Filter > Blur > Gaussian Blur…, Radius (`suite.filter.slider.radius`) 8,
    /// OK (`suite.filter.ok`): only the selection blurs, as one undo step ("Undo Gaussian Blur").
    @MainActor func testGaussianBlurInsideSelection() throws {
        let folder = try scratch("photo-filter-blur")
        let file = folder.appending(path: "beach.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file) + ["-SuiteSupportDir", folder.path])
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        photo.element("suite.tools").buttons["Marquee"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.5, dy: 0.35), to: CGVector(dx: 0.97, dy: 0.95))
        let selection = photo.app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Selection ' OR value CONTAINS 'Selection '")).firstMatch
        XCTAssert(selection.waitForExistence(timeout: 5), "the marquee drag made no selection")
        let opened = steadyCanvas(photo)
        photo.shot("filter-selected")

        choose(["Filter", "Blur", "Gaussian Blur…"], photo)
        let radius = photo.element("suite.filter.slider.radius")
        XCTAssert(radius.waitForExistence(timeout: 5), "Gaussian Blur… opened no sheet with a Radius slider")
        photo.enter("8", in: radius)
        // Tab has no other field to go to in this sheet, so the typing stays open (run 45602316434's hierarchy:
        // `suite.scrub.typing` still focused, reading 8, three seconds on). The field takes Return (onSubmit).
        if photo.element("suite.scrub.typing").exists { photo.app.typeKey(.return, modifierFlags: []) }
        XCTAssert(waitUntil { Self.number(radius.value).map { abs($0 - 8) <= 1.5 } ?? false },
                  "Radius reads \(String(describing: radius.value)), not about 8 px")
        XCTAssert(photo.element("photo.filter.preview").waitForExistence(timeout: 10), "the sheet shows no Preview")
        photo.shot("filter-sheet")
        // The sheet covers most of the canvas on the runner's window, so a canvas shot under it differs from the
        // opened one whatever the document holds (run 45780184665). The document is unchanged while no step is.
        XCTAssertFalse(photo.app.buttons["Undo Gaussian Blur"].exists, "the Preview changed the document")

        photo.element("suite.filter.ok").click()
        expect("Undo Gaussian Blur", photo, "OK made no Gaussian Blur step")
        XCTAssert(waitUntil { Self.share(opened, self.canvas(photo), in: Self.inside) > 0.01 }, "OK didn't soften the selection")
        let blurred = steadyCanvas(photo)
        XCTAssert(Self.share(opened, blurred, in: Self.outside) <= 0.005, "the blur reached outside the selection")
        photo.shot("filter-blurred")

        photo.app.typeKey("z", modifierFlags: .command)
        expect("Redo Gaussian Blur", photo, "Command-Z didn't undo the blur")
        XCTAssert(waitUntil { Self.share(opened, self.canvas(photo), in: Self.inside) <= 0.005 },
                  "one Undo didn't give back the unblurred selection")
        photo.shot("filter-undone")
    }

    /// PJ-AJ2: High Contrast B&W in the Looks grid (`suite.looks.look.bw-high-contrast`), Save Look…
    /// (`suite.looks.save`), "Mine" in `suite.looks.name`, Save (`suite.looks.name.save`); a second image takes Mine.
    @MainActor func testApplyAndSaveLook() throws {
        let folder = try scratch("photo-filter-look")
        let first = folder.appending(path: "beach.png"), second = folder.appending(path: "dunes.png")
        try writeTestPhoto(to: first)
        try writeTestPhoto(to: second, width: 600, height: 400)
        let support = ["-SuiteSupportDir", folder.appending(path: "support").path]
        var photo = Journey("Photo", self, arguments: photoArguments(open: first) + support)
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        click(photo.element("suite.looks.look.bw-high-contrast"), photo)
        expect("Undo Apply Look", photo, "the High Contrast B&W look made no Apply Look step")
        expectGrey(photo, "the High Contrast B&W look didn't grey the canvas")
        photo.shot("filter-look-applied")

        click(photo.element("suite.looks.save"), photo)
        let name = photo.element("suite.looks.name")
        XCTAssert(name.waitForExistence(timeout: 5), "Save Look… opened no name field")
        name.click()
        photo.app.typeText("Mine")
        click(photo.element("suite.looks.name.save"), photo)
        XCTAssert(mine(photo).waitForExistence(timeout: 5), "the Looks grid doesn't list Mine after Save")
        photo.shot("filter-look-saved")

        photo = Journey("Photo", self, arguments: photoArguments(open: second) + support)
        XCTAssert(photo.window(named: "dunes.png").waitForExistence(timeout: 30), "dunes.png didn't open")
        click(mine(photo), photo)
        expect("Undo Apply Look", photo, "Mine made no Apply Look step on the second image")
        expectGrey(photo, "Mine didn't grey the second image")
        photo.shot("filter-look-mine")
    }

    // MARK: Steps

    /// A fresh folder, removed after the test.
    private func scratch(_ name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// The saved look named Mine in the Looks grid.
    @MainActor private func mine(_ photo: Journey) -> XCUIElement {
        photo.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", "suite.looks.look.", "Mine")).firstMatch
    }

    /// Picks `path` from the menu bar: the menu, its submenus, then the enabled item.
    @MainActor private func choose(_ path: [String], _ photo: Journey) {
        guard let top = path.first, let last = path.last else { return }
        let bar = photo.app.menuBars.firstMatch.menuBarItems[top]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(top) menu")
        bar.click()
        var menu = bar
        for title in path.dropFirst().dropLast() {
            menu = menu.menuItems[title]
            XCTAssert(menu.waitForExistence(timeout: 5), "no \(title) submenu")
            menu.hover()
        }
        let item = menu.menuItems[last]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(path.joined(separator: " > "))")
        XCTAssert(item.isEnabled, "\(path.joined(separator: " > ")) is disabled")
        item.click()
    }

    /// Scrolls the inspector until `element` lies inside it, then clicks it. The Looks grid is lazy: its buttons
    /// exist only once it scrolls into view, under the whole Adjust tab, so each try scrolls a long way.
    @MainActor private func click(_ element: XCUIElement, _ photo: Journey) {
        let inspector = photo.element("suite.inspector")
        XCTAssert(inspector.waitForExistence(timeout: 5), "no inspector (suite.inspector)")
        for _ in 0..<30 where !element.waitForExistence(timeout: 0.5) { inspector.scroll(byDeltaX: 0, deltaY: -150) }
        XCTAssert(element.exists, "no \(element.identifier) in the inspector")
        for _ in 0..<30 where !inspector.frame.contains(element.frame) {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.minY < inspector.frame.minY ? 40 : -40)
        }
        element.click()
    }

    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 10), "\(message) (no \(title) button)")
    }

    /// The canvas's middle pixel comes to read grey (red, green and blue within 8 of each other).
    @MainActor private func expectGrey(_ photo: Journey, _ message: String) {
        var read: [Int] = []
        let grey = waitUntil {
            read = PhotoJourneyTests.adjPixel(self.canvas(photo)) ?? []
            return read.count == 3 && (read.max() ?? 0) - (read.min() ?? 0) <= 8
        }
        XCTAssert(grey, "\(message): the middle pixel reads \(read)")
    }

    // MARK: Canvas

    @MainActor private func canvas(_ photo: Journey) -> Data {
        photo.element("suite.canvas").screenshot().pngRepresentation
    }

    /// The canvas once two shots half a second apart match, or the last after five seconds.
    @MainActor private func steadyCanvas(_ photo: Journey) -> Data {
        var last = canvas(photo)
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.5)
            let next = canvas(photo)
            if next == last { break }
            last = next
        }
        return last
    }

    /// The share of `region`'s pixels (fractions of the shot) whose color differs by more than 6 of 255.
    static func share(_ first: Data, _ second: Data, in region: CGRect) -> Double {
        guard let a = PhotoJourneyTests.adjRGBA(first), let b = PhotoJourneyTests.adjRGBA(second),
            a.width == b.width, a.height == b.height, a.bytes.count == b.bytes.count, a.width > 0, a.height > 0
        else { return 1 }
        let x0 = Int(region.minX * Double(a.width)), x1 = min(a.width, Int(region.maxX * Double(a.width)))
        let y0 = Int(region.minY * Double(a.height)), y1 = min(a.height, Int(region.maxY * Double(a.height)))
        guard x1 > x0, y1 > y0 else { return 1 }
        var differing = 0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let base = (y * a.width + x) * 4
                if (base..<(base + 3)).contains(where: { abs(Int(a.bytes[$0]) - Int(b.bytes[$0])) > 6 }) { differing += 1 }
            }
        }
        return Double(differing) / Double((x1 - x0) * (y1 - y0))
    }

    /// A bar's value: a number (the slider ScrubField shows XCUI), else the first number in its text ("8.0 px").
    static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return (value as? String).flatMap { Double($0.split(separator: " ").first.map(String.init) ?? "") }
    }

    /// Whether `condition` holds within five seconds.
    @MainActor private func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<10 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return condition()
    }
}
