// LibraryJourneyTests+Layout.swift: J12, Library at every window width
// (packet docs/blueprints/library/features/status-and-layout.md, Journey
// steps 1 to 7). On `-LibraryFixture shoot` it
// launches at 880 × 560 (SuiteSize.windowMinimum), 1024 × 768, 1280 × 800,
// 1440 × 900 and 1920 × 1080 with `-SuiteWindowSize <w>x<h>`, as Halo's
// testLayoutAtWidths does, and checks only what lies on the runner's display.
// Each size: the status row (`library.status`, its pills `library.status.*`)
// reads "24 photos" and "Thumbnails 160 pt" (#3130), its pills centred on
// one line (midY: the ids name each pill's text until #3197) without
// overlapping; the
// grid's visible cells (`library.grid.cell.<id>`, else buttons whose label
// holds `IMG_`) line up in rows and columns with equal gaps; Sort By Name,
// then a click and a Shift-click select five; the inspector's Rating, Flag
// and Label rows line up; the loupe shows one zoom pill and "1 of 24" once
// (in its HUD) with the photo centered and no "Zoom 100%" at Fit (#3135),
// and Command-1 shows "Zoom 100%";
// the inspector's one header (`library.inspector.header`) reads "5 Photos"
// with "Captured" for five photos, and "IMG_0001" with "6000 × 4000" and
// "JPEG" for one; every control listed in
// `library.controls` lies inside the window. After the loop the grid has
// fewer columns at 880 than at 1024. Written before its code (lead.md,
// contract rule 13); SL-4 draws the status row and runs it.
// Every shot is audited under `library`. A plain Text reads its words as its
// value and a label as its label, so text is read from either.
import AppKit
import XCTest

final class LibraryLayoutJourneyTests: XCTestCase {
    static let sizes = [CGSize(width: 880, height: 560), CGSize(width: 1024, height: 768), CGSize(width: 1280, height: 800),
                        CGSize(width: 1440, height: 900), CGSize(width: 1920, height: 1080)]
    static let cellPrefix = "library.grid.cell."
    /// The alignment tolerance of blueprint 7.3, in points.
    static let tight: CGFloat = 0.5

    /// J12: the status row, grid, inspector and loupe line up at every width.
    @MainActor func testLayoutAtWidths() throws {
        try walkLayout()
    }

    /// The journey itself.
    @MainActor private func walkLayout() throws {
        let screen = NSScreen.screens.first?.frame.size ?? .zero
        var columns: [Int: Int] = [:]
        for size in Self.sizes {
            let width = Int(size.width)
            let library = Journey("Library", self, arguments: [
                "-LibraryFixture", "shoot", "-SuiteWindowSize", "\(width)x\(Int(size.height))",
            ])
            let window = library.app.windows.firstMatch
            XCTAssert(window.waitForExistence(timeout: 30), "no window opened at \(width)")

            // 1. The status row: "24 photos" and "Thumbnails 160 pt", every pill on one centre line (#3131: the
            //    ids name the pill's text, whose top edge moves with a warning triangle, until #3197), inside
            //    the window and the row, no two overlapping.
            let status = library.element("library.status")
            XCTAssert(status.waitForExistence(timeout: 10), "no status row (library.status) at \(width)")
            library.shot("layout-\(width)")
            if size.width <= screen.width {
                XCTAssertEqual(window.frame.width, size.width, accuracy: 2, "-SuiteWindowSize \(width) wasn't the window's width")
            }
            let count = Self.text("24 photos", in: status)
            XCTAssert(count.waitForExistence(timeout: 5), "the status row doesn't read 24 photos at \(width)")
            XCTAssertEqual(Self.text(of: library.element("library.status.cellSize")), "Thumbnails 160 pt", "library.status.cellSize at \(width)")
            let pills = status.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'library.status.'")).allElementsBoundByIndex + [count]
            let middle = count.frame.midY
            for pill in pills {
                let name = pill.identifier.isEmpty ? "the size text" : pill.identifier
                XCTAssertEqual(pill.frame.midY, middle, accuracy: Self.tight, "\(name) is off the row's centre line at \(width)")
                XCTAssert(window.frame.insetBy(dx: -1, dy: -1).contains(pill.frame), "\(name) \(pill.frame) is outside the window at \(width)")
                XCTAssert(status.frame.insetBy(dx: -1, dy: -1).contains(pill.frame), "\(name) \(pill.frame) is outside the row at \(width)")
            }
            let lefts = pills.map(\.frame).sorted { $0.minX < $1.minX }
            for (left, right) in zip(lefts, lefts.dropFirst()) {
                XCTAssertLessThanOrEqual(left.maxX, right.minX + Self.tight, "status pills \(left) and \(right) overlap at \(width)")
            }

            // 2. The visible cells line up in rows and columns with equal gaps; at least 2 columns at 880.
            let cells = cellFrames(library)
            XCTAssertFalse(cells.isEmpty, "no grid cell on screen at \(width)")
            expectGrid(cells, width: width)
            columns[width] = Self.firstRow(cells).count
            if width == 880 { XCTAssertGreaterThanOrEqual(columns[width] ?? 0, 2, "under 2 grid columns at 880") }

            // 3. Sort By > Name, click the first cell and Shift-click the fifth: "5 selected".
            sortByName(library)
            for _ in 0..<6 where visibleCells(library).count < 5 { chooseViewItem("Smaller Thumbnails", library) }
            let shown = visibleCells(library)
            XCTAssertGreaterThanOrEqual(shown.count, 5, "fewer than five grid cells on screen at \(width)")
            guard shown.count >= 5 else { continue }
            library.element(shown[0].id).click()
            XCUIElement.perform(withKeyModifiers: .shift) { library.element(shown[4].id).click() }
            let selection = library.element("library.status.selection")
            XCTAssert(wait(5) { Self.text(of: selection) == "5 selected" },
                      "library.status.selection reads \(Self.text(of: selection)), not 5 selected, at \(width)")

            // 4. Where the inspector is on the screen: Rating, Flag and Label line up.
            let inspector = library.element("suite.inspector")
            if inspector.exists, inspector.frame.maxX <= screen.width { expectMetadataRows(in: inspector, width: width) }

            // 5. The loupe: one zoom pill and no Fit pill, "1 of 24" once (the HUD's), the photo centered;
            //    Command-1 shows "Zoom 100%"; Escape.
            expectLoupe(library, width: width)

            // 6. Five selected again, then IMG_0001 alone: the inspector's one header reads the selection's facts.
            if inspector.exists, inspector.frame.maxX <= screen.width {
                library.element(shown[0].id).click()
                XCUIElement.perform(withKeyModifiers: .shift) { library.element(shown[4].id).click() }
                expectHeader(library, title: "5 Photos", facts: ["Captured"], width: width)
                library.element(shown[0].id).click()
                expectHeader(library, title: "IMG_0001", facts: ["6000 × 4000", "JPEG"], width: width)
            }

            // 7. Every control library.controls lists lies inside the window.
            let listed = Self.decode(library.element("library.controls"))?.controls ?? []
            XCTAssertFalse(listed.isEmpty, "no library.controls JSON at \(width)")
            let outside = listed.compactMap { entry -> String? in
                let control = library.element(entry.id)
                guard control.exists, let seen = visibleFrame(of: control, in: window) else { return nil }
                return window.frame.insetBy(dx: -1, dy: -1).contains(seen) ? nil : "\(entry.id) \(seen)"
            }
            XCTAssert(outside.isEmpty, "library controls outside the \(width) window \(window.frame): " + outside.joined(separator: ", "))
            library.app.terminate()
        }
        // The content column follows the window: fewer columns at 880 than at 1024.
        let (narrow, wide) = (columns[880] ?? 0, columns[1024] ?? 0)
        XCTAssertLessThan(narrow, wide, "the grid has \(narrow) columns at 880 and \(wide) at 1024: the content column is rigid")
    }

    // MARK: - Steps

    /// Rows share a top edge, columns a left edge, and adjacent columns' gaps are equal.
    @MainActor private func expectGrid(_ cells: [CGRect], width: Int) {
        for row in Self.groups(cells.map(\.minY)) {
            XCTAssertLessThanOrEqual((row.max() ?? 0) - (row.min() ?? 0), Self.tight, "a grid row's tops differ at \(width): \(row)")
        }
        for column in Self.groups(cells.map(\.minX)) {
            XCTAssertLessThanOrEqual((column.max() ?? 0) - (column.min() ?? 0), Self.tight, "a grid column's left edges differ at \(width): \(column)")
        }
        let row = Self.firstRow(cells)
        let gaps = zip(row, row.dropFirst()).map { $1.minX - $0.maxX }
        if let first = gaps.first {
            for gap in gaps { XCTAssertEqual(gap, first, accuracy: Self.tight, "the grid's column gaps differ at \(width): \(gaps)") }
        }
    }

    /// The Rating, Flag and Label labels share a left edge; their controls' right edges are equal.
    @MainActor private func expectMetadataRows(in inspector: XCUIElement, width: Int) {
        let labels = ["Rating", "Flag", "Label"].map { Self.text($0, in: inspector) }
        guard labels.allSatisfy({ $0.waitForExistence(timeout: 5) }) else {
            XCTFail("the inspector shows no Rating, Flag and Label rows at \(width)")
            return
        }
        let lefts = labels.map(\.frame.minX)
        XCTAssertLessThanOrEqual((lefts.max() ?? 0) - (lefts.min() ?? 0), Self.tight, "the metadata row labels' left edges at \(width): \(lefts)")
        let dots = inspector.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'library.metadata.label.'")).allElementsBoundByIndex
        let rights = [
            inspector.descendants(matching: .any)["library.metadata.star.5"].firstMatch.frame.maxX,
            inspector.descendants(matching: .any)["library.metadata.flag"].firstMatch.frame.maxX,
            dots.map(\.frame.maxX).max() ?? 0,
        ]
        XCTAssertLessThanOrEqual((rights.max() ?? 0) - (rights.min() ?? 0), Self.tight, "the metadata controls' right edges at \(width): \(rights)")
    }

    /// Exactly one `library.inspector.header`, reading `title` and holding each of `facts`.
    @MainActor private func expectHeader(_ library: Journey, title: String, facts: [String], width: Int) {
        let headers = library.app.descendants(matching: .any).matching(identifier: "library.inspector.header")
        let header = headers.firstMatch
        XCTAssert(header.waitForExistence(timeout: 5), "no library.inspector.header at \(width)")
        XCTAssertEqual(headers.count, 1, "the inspector shows \(headers.count) headers at \(width)")
        XCTAssert(wait(5) { Self.text(of: header).contains(title) },
                  "library.inspector.header reads \(Self.text(of: header)), not \(title), at \(width)")
        let text = Self.text(of: header)
        for fact in facts {
            XCTAssert(text.contains(fact), "library.inspector.header lacks \(fact) at \(width): \(text)")
        }
    }

    /// Double-click IMG_0001: one zoom pill (the fit percent) and no Fit pill
    /// (#3133), "1 of 24" once in the window, in the HUD (#3137), the photo
    /// centered in the loupe within 1 pt; Command-1: "Zoom 100%"; Escape.
    @MainActor private func expectLoupe(_ library: Journey, width: Int) {
        let cell = library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", Self.cellPrefix, "IMG_0001")).firstMatch
        let target = cell.exists ? cell : library.app.splitGroups.descendants(matching: .button)
            .matching(NSPredicate(format: "label CONTAINS %@", "IMG_0001")).firstMatch
        XCTAssert(target.waitForExistence(timeout: 5), "no grid cell for IMG_0001 at \(width)")
        target.doubleClick()
        let loupe = library.element("library.loupe")
        XCTAssert(loupe.waitForExistence(timeout: 10), "double-clicking IMG_0001 didn't open the loupe at \(width)")
        let status = library.element("library.status")
        XCTAssert(wait(5) { Self.zoomPills(in: status) == 1 }, "the loupe at Fit shows \(Self.zoomPills(in: status)) zoom pills at \(width)")
        XCTAssertFalse(library.element("library.status.zoom").exists, "the loupe at Fit still shows a Fit pill at \(width)")
        XCTAssertFalse(library.element("library.status.position").exists, "the status row repeats the loupe's place at \(width)")
        XCTAssert(wait(5) { !Self.text("Zoom 100%", in: status).exists },
                  "the loupe at Fit reads Zoom 100%, not its fit scale, at \(width) (#3135)")
        let place = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "1 of 24", "1 of 24")
        let places = library.app.windows.firstMatch.staticTexts.matching(place).count
        XCTAssertEqual(places, 1, "\"1 of 24\" shows \(places) times in the loupe at \(width)")
        library.shot("layout-\(width)-loupe")
        let photo = library.element("library.loupe.photo").frame, column = loupe.frame
        XCTAssertEqual(photo.minX - column.minX, column.maxX - photo.maxX, accuracy: 1, "the loupe photo isn't centered across at \(width)")
        XCTAssertEqual(photo.minY - column.minY, column.maxY - photo.maxY, accuracy: 1, "the loupe photo isn't centered down at \(width)")
        library.press(character: "1", .command)
        let actual = Self.text("Zoom 100%", in: status)
        XCTAssert(actual.waitForExistence(timeout: 5), "Command-1 didn't show Zoom 100% in the status row at \(width)")
        XCTAssertEqual(Self.zoomPills(in: status), 1, "Command-1 left more than one zoom pill at \(width)")
        library.press(.escape)
        XCTAssert(loupe.waitForNonExistence(timeout: 5), "Escape left it in the loupe at \(width)")
    }

    // MARK: - Helpers

    /// The elements in the status row labelled "Zoom …": ViewerStatusBar's zoom pill.
    @MainActor private static func zoomPills(in status: XCUIElement) -> Int {
        status.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Zoom ")).count
    }

    /// The frames of the cells at least half inside the grid's scroll view, in
    /// layout order; cells by identifier, else buttons whose label holds `IMG_`.
    @MainActor private func visibleCells(_ library: Journey) -> [(id: String, frame: CGRect)] {
        guard let tree = try? library.app.windows.firstMatch.snapshot() else { return [] }
        var byID: [(id: String, frame: CGRect)] = [], byLabel: [(id: String, frame: CGRect)] = []
        Self.collect(tree, clip: tree.frame, byID: &byID, byLabel: &byLabel)
        return (byID.isEmpty ? byLabel : byID).sorted {
            abs($0.frame.minY - $1.frame.minY) > 1 ? $0.frame.minY < $1.frame.minY : $0.frame.minX < $1.frame.minX
        }
    }

    @MainActor private func cellFrames(_ library: Journey) -> [CGRect] { visibleCells(library).map(\.frame) }

    @MainActor private static func collect(
        _ node: XCUIElementSnapshot, clip: CGRect,
        byID: inout [(id: String, frame: CGRect)], byLabel: inout [(id: String, frame: CGRect)]
    ) {
        let clip = node.elementType == .scrollView ? clip.intersection(node.frame) : clip
        let seen = node.frame.intersection(clip)
        let halfIn = !seen.isNull && seen.width * 2 >= node.frame.width && seen.height * 2 >= node.frame.height
        if node.identifier.hasPrefix(cellPrefix) {
            if halfIn { byID.append((node.identifier, node.frame)) }
            return
        }
        if node.elementType == .button, node.label.contains("IMG_"), halfIn { byLabel.append((node.identifier, node.frame)) }
        for child in node.children { collect(child, clip: clip, byID: &byID, byLabel: &byLabel) }
    }

    /// The cells sharing the first cell's row, left to right.
    private static func firstRow(_ cells: [CGRect]) -> [CGRect] {
        guard let top = cells.first?.minY else { return [] }
        return cells.filter { abs($0.minY - top) <= 2 }.sorted { $0.minX < $1.minX }
    }

    /// `values` clustered where they lie within 2 pt of a neighbour.
    private static func groups(_ values: [CGFloat]) -> [[CGFloat]] {
        var groups: [[CGFloat]] = []
        for value in values.sorted() {
            if let last = groups.last?.last, value - last <= 2 { groups[groups.count - 1].append(value) } else { groups.append([value]) }
        }
        return groups
    }

    /// View > Sort By > Name.
    @MainActor private func sortByName(_ library: Journey) {
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        let byName = sort.menuItems["Name"]
        XCTAssert(byName.waitForExistence(timeout: 3), "View > Sort By has no Name")
        byName.click()
    }

    /// Opens View and chooses its enabled item `title`.
    @MainActor private func chooseViewItem(_ title: String, _ library: Journey) {
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let item = view.menuItems[title]
        XCTAssert(item.waitForExistence(timeout: 3), "the View menu has no \(title)")
        item.click()
    }

    /// The part of `control` a scroll view leaves on screen; nil when none (Halo's check).
    @MainActor private func visibleFrame(of control: XCUIElement, in window: XCUIElement) -> CGRect? {
        let frame = control.frame
        guard !window.frame.insetBy(dx: -1, dy: -1).contains(frame) else { return frame }
        let scrolls = window.descendants(matching: .scrollView)
            .containing(control.elementType, identifier: control.identifier).allElementsBoundByIndex
        let shown = scrolls.reduce(frame) { $0.intersection($1.frame) }
        return shown.isNull || shown.isEmpty ? nil : shown
    }

    /// Polls `condition` every tenth of a second for up to `seconds`.
    @MainActor private func wait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return condition()
    }

    /// What a plain Text reads: its value, or its label when the value is empty.
    @MainActor private static func text(of element: XCUIElement) -> String {
        let value = (element.value as? String) ?? ""
        return value.isEmpty ? element.label : value
    }

    /// The first element under `root` that reads `text`.
    @MainActor private static func text(_ text: String, in root: XCUIElement) -> XCUIElement {
        root.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
    }

    /// The ControlDocument in `probe`'s label; nil when it's missing or isn't one.
    @MainActor private static func decode(_ probe: XCUIElement) -> ControlDocument? {
        guard probe.waitForExistence(timeout: 5) else { return nil }
        return try? JSONDecoder().decode(ControlDocument.self, from: Data(probe.label.utf8))
    }
}
