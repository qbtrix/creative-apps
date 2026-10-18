// LibraryJourneyTests+Grid.swift: J2, the grid shows each photo's real
// thumbnail and sorts (packet docs/blueprints/library/features/thumbnails.md,
// Journey steps). Steps 1 to 4 run on the `shoot` fixture's fakes; TH-8 adds
// step 1's live launch (`LibraryFiles.writeShoot` with
// `-LibraryImportOnLaunch`) and runs the same steps on it. Each grid cell is
// `library.grid.cell.<photo id>` with the catalog's `cellValue(for:)` as its
// value ("ready 341×512 No stars", "loading No stars"); the journey reads the
// cells from one snapshot of the window, keeps those at least half inside the
// grid's scroll view (the cells a person sees) and orders them as the grid
// lays them out. Sizes are compared with each other, never with fixed
// numbers, so the run passes at 1x and 2x alike.
import XCTest

extension LibraryJourneyTests {
    /// J2: every visible cell shows its thumbnail, a larger cell size draws a
    /// larger one, Sort By Name reorders, and Shift-click selects a range.
    @MainActor func testGridShowsThumbnailsAndSorts() {
        gridSteps(Journey("Library", self, arguments: ["-LibraryFixture", "shoot"]), suffix: "")
        // TH-8: J2 (L), step 1 launched live on `LibraryFiles.writeShoot` with
        // `-LibraryImportOnLaunch`, then `gridSteps(_, suffix: "-live")`.
    }

    /// J2 steps 1 to 4 on `library`, each shot's name ending `suffix`.
    @MainActor private func gridSteps(_ library: Journey, suffix: String) {
        // Step 1: every visible cell is ready within 2 s; IMG_0024 leads in
        // capture order; a portrait cell is taller than wide.
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let anyCell = library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", Self.cellPrefix)).firstMatch
        XCTAssert(anyCell.waitForExistence(timeout: 10), "no grid cell (\(Self.cellPrefix)<id>)")
        let first = expectAllReady(library, within: 2)
        library.shot("grid\(suffix)")
        XCTAssertEqual(first.first?.name, "IMG_0024", "the first cell in capture order")
        let portraits = first.filter(\.isPortrait)
        XCTAssertFalse(portraits.isEmpty, "no portrait cell on screen: \(first.map(\.name))")
        for cell in first {
            guard let size = cell.size else { continue }
            XCTAssertEqual(size.height > size.width, cell.isPortrait, "\(cell.name)'s thumbnail reads \(cell.value)")
        }
        let smallSide = first.compactMap(\.longSide).max() ?? 0

        // Step 2: View > Larger Thumbnails three times (160 → 280 pt): fewer
        // columns, each visible cell ready at a larger long side.
        for _ in 0..<3 { chooseViewItem("Larger Thumbnails", library) }
        let larger = expectAllReady(library, within: 2, longerThan: smallSide)
        library.shot("grid-larger\(suffix)")
        XCTAssertLessThan(Self.columns(larger), Self.columns(first), "Larger Thumbnails didn't drop a column")

        // Step 3: View > Sort By > Name puts IMG_0001 first.
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        let byName = sort.menuItems["Name"]
        XCTAssert(byName.waitForExistence(timeout: 3), "View > Sort By has no Name")
        byName.click()
        var lead: GridCell?
        for _ in 0..<25 {
            lead = gridCells(library).first
            if lead?.name == "IMG_0001" { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        library.shot("grid-by-name\(suffix)")
        XCTAssertEqual(lead?.name, "IMG_0001", "the first cell after Sort By > Name")
        XCTAssert(lead?.label.contains("IMG_0001") ?? false, "the first cell's caption reads \(lead?.label ?? "nothing")")

        // Step 4: click a cell, Shift-click the fourth after it: five selected.
        // At 280 pt a narrow grid may show fewer than five cells, so step the
        // size down until five are on screen.
        for _ in 0..<6 where gridCells(library).count < 5 { chooseViewItem("Smaller Thumbnails", library) }
        let shown = gridCells(library)
        XCTAssertGreaterThanOrEqual(shown.count, 5, "fewer than five grid cells on screen: \(shown.map(\.name))")
        let range = Array(shown.prefix(5))
        guard let anchor = range.first, let end = range.last else { return }
        library.element(anchor.id).click()
        XCUIElement.perform(withKeyModifiers: .shift) { library.element(end.id).click() }
        var selected: [String] = []
        for _ in 0..<25 {
            selected = gridCells(library).filter(\.isSelected).map(\.name)
            if selected.count == 5 { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(selected, range.map(\.name), "Shift-click from \(anchor.name) to \(end.name) selected \(selected)")
        library.app.terminate()
    }

    // MARK: - Grid helpers

    private static let cellPrefix = "library.grid.cell."

    /// One grid cell as a snapshot read it.
    private struct GridCell {
        let id: String
        let label: String
        let value: String
        let frame: CGRect
        let isSelected: Bool

        /// "IMG_0007" from the cell's identifier (its photo id is the file's path or name).
        var name: String { id.range(of: "IMG_[0-9]+", options: .regularExpression).map { String(id[$0]) } ?? id }
        /// The shoot's every third photo is portrait (LibraryFixtures.shoot, LibraryFiles.writeShoot).
        var isPortrait: Bool { Int(name.dropFirst(4)).map { $0 % 3 == 0 } ?? false }
        var isReady: Bool { value.hasPrefix("ready") }

        /// The thumbnail's pixel size from "ready W×H …"; nil while it isn't ready.
        var size: (width: Int, height: Int)? {
            guard let match = value.range(of: "^ready [0-9]+×[0-9]+", options: .regularExpression) else { return nil }
            let numbers = value[match].dropFirst(6).split(separator: "×").compactMap { Int($0) }
            guard numbers.count == 2 else { return nil }
            return (numbers[0], numbers[1])
        }

        var longSide: Int? { size.map { max($0.width, $0.height) } }
    }

    /// The cells at least half inside the grid's scroll view, in layout order
    /// (rows top to bottom, each left to right).
    @MainActor private func gridCells(_ library: Journey) -> [GridCell] {
        guard let tree = try? library.app.windows.firstMatch.snapshot() else { return [] }
        var cells: [GridCell] = []
        Self.collect(tree, clip: tree.frame, into: &cells)
        return cells.sorted {
            abs($0.frame.minY - $1.frame.minY) > 1 ? $0.frame.minY < $1.frame.minY : $0.frame.minX < $1.frame.minX
        }
    }

    @MainActor private static func collect(_ node: XCUIElementSnapshot, clip: CGRect, into cells: inout [GridCell]) {
        let clip = node.elementType == .scrollView ? clip.intersection(node.frame) : clip
        if node.identifier.hasPrefix(cellPrefix) {
            let seen = node.frame.intersection(clip)
            if !seen.isNull, seen.width * 2 >= node.frame.width, seen.height * 2 >= node.frame.height {
                cells.append(GridCell(
                    id: node.identifier, label: node.label, value: (node.value as? String) ?? "",
                    frame: node.frame, isSelected: node.isSelected))
            }
            return
        }
        for child in node.children { collect(child, clip: clip, into: &cells) }
    }

    /// Within `seconds`, every visible cell reads `ready` at a long side over
    /// `longerThan`; returns the cells as last read.
    @MainActor private func expectAllReady(
        _ library: Journey, within seconds: TimeInterval, longerThan floor: Int = 0
    ) -> [GridCell] {
        let deadline = Date(timeIntervalSinceNow: seconds)
        var cells: [GridCell] = []
        repeat {
            cells = gridCells(library)
            if !cells.isEmpty, cells.allSatisfy({ ($0.longSide ?? 0) > floor }) { return cells }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        let late = cells.filter { ($0.longSide ?? 0) <= floor }.map { "\($0.name): \($0.value)" }
        XCTFail("within \(seconds) s, not every visible cell was ready over \(floor) px: \(late)")
        return cells
    }

    /// How many cells share the first row.
    private static func columns(_ cells: [GridCell]) -> Int {
        guard let top = cells.first?.frame.minY else { return 0 }
        return cells.filter { abs($0.frame.minY - top) <= 1 }.count
    }

    /// Opens View and chooses its enabled item `title`.
    @MainActor private func chooseViewItem(_ title: String, _ library: Journey) {
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let item = view.menuItems[title]
        XCTAssert(item.waitForExistence(timeout: 3), "the View menu has no \(title)")
        XCTAssert(item.isEnabled, "View > \(title) is disabled")
        item.click()
    }
}
