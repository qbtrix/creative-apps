// SuiteJourneyTests.swift: SuiteUI's own journeys (blueprint suiteui 4.1).
// SuiteUI has no app, so each one launches Library with `-SuiteGallery <page>`,
// which makes the window's whole body the component gallery, and shoots and
// audits under `suiteui` (`Journey(name:)`), so gallery shots never count under
// `library`. Each feature adds its own `SuiteJourneyTests+<Area>.swift`; the
// Journey template in project.yml compiles them all into this bundle, with
// SuiteControlInventory so a journey can judge `suite.controls` by the live rules.
// SJ25 measures every listed control against its hit size; the perf gates
// live in SuiteJourneyTests+Budgets.swift.
import XCTest

final class SuiteJourneyTests: XCTestCase {
    /// SJ25 (QB-S20): on every gallery page, the index included, every
    /// `suite.controls` entry's element is at least its hit size on both
    /// sides (`hitSize(of:)`). A page with no controls passes with a count of
    /// 0; each page attaches its count as "hit-sizes-<page>".
    @MainActor func testEveryControlMeetsHitSize() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index", "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        let rowPrefix = "suite.gallery.index."
        let rows = expectHitSizes(gallery, page: "index").map(\.id).filter { $0.hasPrefix(rowPrefix) }
        XCTAssertFalse(rows.isEmpty, "the index lists no pages")
        for row in rows {
            let page = String(row.dropFirst(rowPrefix.count))
            gallery.element(row).click()
            XCTAssert(gallery.element("suite.gallery.\(page)").waitForExistence(timeout: 10), "no root suite.gallery.\(page)")
            expectHitSizes(gallery, page: page)
            gallery.element("suite.gallery.back").click()
            XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 10), "\(page) didn't go back to the index")
        }
    }

    /// SJ0: the index opens every page; each page's root is there, and its
    /// `suite.controls` lists every `suite.gallery.*` control on screen with
    /// no dead control or duplicate id. An unknown page names itself.
    @MainActor func testGalleryOpensEveryPage() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index", "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.shot("index-open")
        let rowPrefix = "suite.gallery.index."
        let index = expectControlsListed(gallery, page: "index")
        let rows = (index?.controls ?? []).map(\.id).filter { $0.hasPrefix(rowPrefix) }
        XCTAssertFalse(rows.isEmpty, "the index lists no pages")
        for row in rows {
            let page = String(row.dropFirst(rowPrefix.count))
            gallery.element(row).click()
            XCTAssert(gallery.element("suite.gallery.\(page)").waitForExistence(timeout: 10), "no root suite.gallery.\(page)")
            gallery.shot("\(page)-open")
            expectControlsListed(gallery, page: page)
            gallery.element("suite.gallery.back").click()
            XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 10), "\(page) didn't go back to the index")
        }
        gallery.app.terminate()

        let unknown = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "nosuch"])
        let message = unknown.app.staticTexts["No gallery page named nosuch."]
        XCTAssert(message.waitForExistence(timeout: 30), "no empty state naming the unknown page")
        XCTAssert(unknown.element("suite.gallery.unknown").exists, "the unknown page has no suite.gallery.unknown root")
        unknown.shot("nosuch-unknown")
    }

    /// Every control on screen with a `suite.gallery.` identifier is in
    /// `suite.controls`, and a SuiteControlInventory rebuilt from the
    /// document has no violations. Registration follows the page's
    /// appearance, so the document gets two seconds to catch up. Returns it.
    @discardableResult
    @MainActor private func expectControlsListed(_ gallery: Journey, page: String) -> ControlDocument? {
        var missing: [String] = []
        var document: ControlDocument?
        for _ in 0..<10 {
            document = gallery.controls()
            let listed = Set(document?.controls.map(\.id) ?? [])
            missing = galleryControls(gallery).filter { !listed.contains($0) }.sorted()
            // Every page lists at least its back button or, on the index, its rows.
            if missing.isEmpty, document?.controls.isEmpty == false { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssert(missing.isEmpty, "\(page): on screen but not in suite.controls: \(missing)")
        var inventory = SuiteControlInventory()
        for entry in document?.controls ?? [] { inventory.register(entry) }
        XCTAssertEqual(inventory.violations(), [], "\(page): suite.controls has dead or duplicate controls")
        return document
    }

    /// Every entry of the page's `suite.controls` has an element at least
    /// `hitSize(of:)` wide and high. Registration follows the page's
    /// appearance, so the document gets two seconds to match the window.
    /// Returns the entries.
    @discardableResult
    @MainActor private func expectHitSizes(_ gallery: Journey, page: String) -> [ControlEntry] {
        var entries: [ControlEntry] = []
        var sizes: [String: CGSize] = [:]
        for _ in 0..<10 {
            entries = gallery.controls()?.controls ?? []
            sizes = controlSizes(gallery, ids: Set(entries.map(\.id)))
            if !entries.isEmpty, entries.allSatisfy({ sizes[$0.id] != nil }) { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        for entry in entries {
            guard let size = sizes[entry.id] else {
                XCTFail("\(page): \(entry.id) is in suite.controls but has no element")
                continue
            }
            let hit = Self.hitSize(of: entry.id)
            // Frames come from the accessibility tree, which can round to half a point.
            XCTAssert(
                size.width + 0.5 >= hit && size.height + 0.5 >= hit,
                "\(page): \(entry.id) is \(size.width) x \(size.height) pt, under its \(hit) x \(hit) pt hit (QB-S20)")
        }
        let count = XCTAttachment(string: "\(page): \(entries.count) controls measured")
        count.name = "hit-sizes-\(page)"
        count.lifetime = .keepAlways
        add(count)
        return entries
    }

    /// The least hit, in points, of the control `id`: 20 (docs/design.md,
    /// Symbols and controls), or the token table's hit for the kind its last
    /// segment names, as `suite.gallery.inspector.chip-onion` names a chip.
    static func hitSize(of id: String) -> Double {
        let name = id.split(separator: ".").last.map(String.init) ?? id
        let kind = tokenHits.first { name == $0.kind || name.hasPrefix($0.kind + "-") }
        return kind?.hit ?? 20
    }

    /// The hits docs/design.md's Sizes table names (QB-S20). Matching is by
    /// whole word, so `keyframe-…` is never read as `key-…`. Handle and
    /// anchor hits (12) are canvas marks, not elements: SJ10's log proves them.
    private static let tokenHits: [(kind: String, hit: Double)] = [
        ("curve-handle", 28),  // SuiteSize.curveHandleHit
        ("keyframe", 28),      // SuiteSize.keyframeButton
        ("preset", 28),        // SuiteSize.presetHit
        ("chip", 28),          // SuiteSize.chip
        ("pill", 24),          // SuiteSize.pillHit
        ("key", 16),           // SuiteSize.timelineKeyframeHit: a timeline key diamond
    ]

    /// The size of each element in `ids`, from one window snapshot: a control
    /// type's element when the id is on several, else the largest.
    @MainActor private func controlSizes(_ gallery: Journey, ids: Set<String>) -> [String: CGSize] {
        guard let tree = try? gallery.app.windows.firstMatch.snapshot() else { return [:] }
        var found: [String: (control: Bool, size: CGSize)] = [:]
        var pending: [any XCUIElementSnapshot] = [tree]
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children)
            guard ids.contains(node.identifier) else { continue }
            let control = Self.controlTypes.contains(node.elementType)
            let size = node.frame.size
            if let old = found[node.identifier] {
                let keepsOld = old.control && !control
                    || old.control == control && old.size.width * old.size.height >= size.width * size.height
                if keepsOld { continue }
            }
            found[node.identifier] = (control, size)
        }
        return found.mapValues { $0.size }
    }

    /// The identifiers of the window's controls that start with `suite.gallery.`.
    @MainActor private func galleryControls(_ gallery: Journey) -> Set<String> {
        guard let tree = try? gallery.app.windows.firstMatch.snapshot() else {
            XCTFail("no window snapshot")
            return []
        }
        var found: Set<String> = []
        var pending: [any XCUIElementSnapshot] = [tree]
        while let node = pending.popLast() {
            if node.identifier.hasPrefix("suite.gallery."), Self.controlTypes.contains(node.elementType) {
                found.insert(node.identifier)
            }
            pending.append(contentsOf: node.children)
        }
        return found
    }

    /// The element types a person acts on; page roots and logs are not controls.
    private static let controlTypes: Set<XCUIElement.ElementType> = [
        .button, .toolbarButton, .checkBox, .radioButton, .switch, .toggle, .slider, .stepper, .popUpButton,
        .menuButton, .comboBox, .textField, .searchField, .segmentedControl, .colorWell, .link, .tab,
        .incrementArrow, .decrementArrow, .disclosureTriangle,
    ]
}
