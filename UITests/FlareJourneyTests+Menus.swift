// FlareJourneyTests+Menus.swift: J1 and the keyboard (draw-key-save DK-13).
// J1 opens every menu on `-FlareFixture bounce` and checks section 3.4's
// items (docs/blueprints/flare.md): Object and Animate hold exactly theirs;
// File, Edit, View and Window are system menus AppKit adds to, so each holds
// its 3.4 items in order and every one of them once. Open Sample lists
// Bounce, Character, Button and Keyed Ball, and each one opens: Character
// shows Body in LAYERS, Bounce Ball, Shadow and Background, Button drops
// Ball. testKeys presses the menu keys
// on bounce: End reads 47, Home 0, → steps one, Space plays and pauses, and
// ⌘Z undoes the sidebar's New Layer. One shot per step.
import XCTest

final class FlareMenuJourneys: XCTestCase {
    /// Section 3.4's items, by menu; Undo and Redo match by prefix (their step names follow).
    static let menus: [(menu: String, items: [String], exact: Bool)] = [
        ("File", ["New", "Open…", "Open Recent", "Open Sample", "Save", "Save As…", "Export…", "Close"], false),
        ("Edit", ["Undo", "Redo", "Cut", "Copy", "Paste", "Duplicate", "Delete", "Select All", "Deselect"], false),
        ("View", ["Zoom In", "Zoom Out", "Fit", "Actual Size", "Onion Skin", "Motion Path", "Show Rulers",
                  "Show Guides", "Clear Guides"], false),
        // Finish Path is Return's item for the mouse (#1893).
        ("Object", ["Convert to Symbol", "Edit Symbol", "Exit Symbol", "Bring Forward", "Send Backward",
                    "Finish Path"], true),
        ("Animate", ["Play/Pause", "Loop", "Next Frame", "Previous Frame", "Next Keyframe", "Previous Keyframe",
                     "Go to Start", "Go to End", "Add Keyframe", "Remove Keyframe", "Auto-Key", "Insert Frame",
                     "Remove Frame", "Add Label", "Easing", "Animate with Assist…"], true),
        ("Window", ["Interactions"], false),
    ]

    /// J1: every menu opens and lists section 3.4's items; nothing is hidden.
    @MainActor func testEveryMenuOpens() {
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        flare.openEachMenu()
        for (menu, items, exact) in Self.menus {
            let titles = flare.menuTitles(menu)
            if exact {
                XCTAssertEqual(titles, items, "the \(menu) menu doesn't hold exactly section 3.4's items")
                continue
            }
            let mine = titles.filter { title in items.contains { title == $0 || title.hasPrefix($0 + " ") } }
            XCTAssertEqual(mine.count, items.count, "the \(menu) menu doesn't hold section 3.4's \(items): \(titles)")
            for (title, item) in zip(mine, items) {
                XCTAssert(title == item || title.hasPrefix(item + " "), "the \(menu) menu's \(item) is out of order: \(titles)")
            }
        }
        XCTAssertEqual(
            flare.menuTitles("File", submenu: "Open Sample"), ["Bounce", "Character", "Button", "Keyed Ball"],
            "File > Open Sample doesn't list the samples")
        XCTAssertEqual(
            flare.menuTitles("Animate", submenu: "Easing"),
            ["Linear", "Ease", "Ease In", "Ease Out", "Ease In-Out", "Hold"], "Animate > Easing isn't the presets")
        XCTAssert(flare.menuTitles("File", submenu: "Open Recent").contains("Clear Menu"), "Open Recent has no Clear Menu")

        let sidebar = flare.element("suite.sidebar")
        flare.openSample("Character")
        XCTAssert(sidebar.staticTexts["Body"].waitForExistence(timeout: 10), "Open Sample > Character didn't open it")
        XCTAssert(sidebar.staticTexts["Ball"].waitForNonExistence(timeout: 5), "Character kept bounce's Ball")
        flare.shot("open-sample-character")
        flare.openSample("Bounce")
        for layer in ["Ball", "Shadow", "Background"] {
            XCTAssert(sidebar.staticTexts[layer].waitForExistence(timeout: 10), "Open Sample > Bounce shows no \(layer)")
        }
        flare.shot("open-sample-bounce")
        flare.openSample("Button")
        XCTAssert(sidebar.staticTexts["Ball"].waitForNonExistence(timeout: 10), "Open Sample > Button didn't open it")
        flare.shot("open-sample-button")
    }

    /// The keys live on the menu items: Home, End, →, Space and ⌘Z act from the keyboard.
    @MainActor func testKeys() {
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let frame = flare.element("flare.timeline.frame")
        XCTAssert(frame.waitForExistence(timeout: 10), "no frame readout (flare.timeline.frame)")
        flare.press(.end, step: "keys-end")
        XCTAssert(wait { frame.label == "47 / 48" }, "End left the frame at \(frame.label)")
        flare.press(.home, step: "keys-home")
        XCTAssert(wait { frame.label == "0 / 48" }, "Home left the frame at \(frame.label)")
        flare.press(.rightArrow, step: "keys-step")
        XCTAssert(wait { frame.label == "1 / 48" }, "→ didn't step one frame: \(frame.label)")

        flare.press(.space)
        Thread.sleep(forTimeInterval: 1)
        flare.press(.space, step: "keys-play-pause")
        let paused = frame.label
        XCTAssertNotEqual(paused, "1 / 48", "Space didn't play")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(frame.label, paused, "the second Space didn't pause")

        let sidebar = flare.element("suite.sidebar")
        let add = sidebar.buttons["New Layer"]
        XCTAssert(add.waitForExistence(timeout: 5), "the sidebar has no New Layer")
        add.click()
        XCTAssert(sidebar.staticTexts["Layer 1"].waitForExistence(timeout: 5), "New Layer added no Layer 1")
        flare.press(character: "z", .command, step: "keys-undo")
        XCTAssert(sidebar.staticTexts["Layer 1"].waitForNonExistence(timeout: 5), "⌘Z didn't undo New Layer")
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func wait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}

extension Journey {
    /// The item titles of `menu`, or of its `submenu` (opened by hovering
    /// it), read with the menu open; separators left out. Closes the menu.
    @MainActor func menuTitles(_ menu: String, submenu: String? = nil) -> [String] {
        let bar = app.menuBars.firstMatch.menuBarItems[menu]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(menu) menu")
        bar.click()
        var items = bar.menus.firstMatch.children(matching: .menuItem)
        if let submenu {
            let parent = items[submenu]
            XCTAssert(parent.waitForExistence(timeout: 3), "the \(menu) menu has no \(submenu)")
            parent.hover()
            items = parent.menus.firstMatch.children(matching: .menuItem)
        }
        _ = items.firstMatch.waitForExistence(timeout: 3)
        let titles = items.allElementsBoundByIndex.map(\.title).filter { !$0.isEmpty }
        press(.escape)
        if submenu != nil { press(.escape) }
        return titles
    }

    /// File > Open Sample > `title`: the easing journey opens Keyed Ball this way.
    @MainActor func openSample(_ title: String) {
        app.menuBars.menuBarItems["File"].click()
        let parent = app.menuBars.menuItems["Open Sample"]
        XCTAssert(parent.waitForExistence(timeout: 5), "File has no Open Sample")
        parent.hover()
        let item = parent.menuItems[title]
        XCTAssert(item.waitForExistence(timeout: 5), "File > Open Sample has no \(title)")
        item.click()
    }
}
