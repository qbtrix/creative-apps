// PhotoJourneyTests+Documents.swift: photo-documents' journeys PJ-1, PJ-1b,
// PJ-2 and PJ-4 (docs/blueprints/photo/features/photo-documents.md, Journey
// steps 1, 2, 3 and 5). PJ-1 saves a painted Multiply 50% layer on beach.png
// as a Photo Document through "Keep layers?" (into `-PhotoSaveTo`, no panel)
// and reopens it from Open Recent; PJ-1b saves into a locked folder: the
// alert, then "Not saved"; PJ-2 runs the unsaved prompt's Cancel and Don't
// Save, then Open Recent and Clear Menu; PJ-4 has the app save a real
// beach.ora, rewrites it four ways with a stored-zip writer (PhotoZip's
// layout) and opens each. Open Recent reads the focused window's list, so with
// every window closed a reopen relaunches Photo with no file first (the list
// is in the app's defaults). XCUITest reads no document-edited state, so
// "edited" is `photo.bar.saved`'s label. Shots: `photo-documents-<step>`.
import CoreGraphics
import ImageIO
import XCTest

final class PhotoDocumentsJourneyTests: XCTestCase {
    /// PJ-1: save a layered PNG as a Photo Document, close it, reopen it from Open Recent.
    @MainActor func testSaveLayeredDocumentAndReopen() throws {
        let (folder, beach) = try beachFolder("pj1")
        var photo = launch(photoArguments(open: beach, saveTo: folder), window: "beach.png")
        expectStatus("Saved", photo)
        photo.shot("documents-1-opened")

        // 2. New Layer, a stroke, Multiply at 50%: "Edited".
        openLayers(photo)
        newLayer(photo)
        paint(photo)
        chooseBlend("Multiply", photo)
        typeValue("50", into: "photo.layer.opacity", photo)
        expectRow("Layer 1", meta: "Multiply 50%", photo)
        expectStatus("Edited", photo)
        let edited = steadyCanvas(photo)
        photo.shot("documents-1-edited")

        // 3. File > Save asks Keep layers?; Save as Photo Document writes beach.ora.
        photo.press(character: "s", .command)
        let keep = alert(photo)
        XCTAssert(text("Keep layers?", in: keep).waitForExistence(timeout: 5), "Save asked no Keep layers?")
        let choices = ["document": "Save as Photo Document", "flatten": "Flatten into PNG", "cancel": "Cancel"]
        // An NSAlert's NSButton reads its text as `title` to XCUITest on macOS; `label` can be empty.
        for (id, title) in choices {
            let button = keep.buttons["photo.file.keep-layers.\(id)"].firstMatch
            XCTAssert(button.exists && (button.title == title || button.label == title),
                      "Keep layers? has no \(title) (photo.file.keep-layers.\(id)); it reads title \(button.title), label \(button.label)")
        }
        let says = "beach.png can keep only one flat layer. Save as Photo Document writes beach.ora next to it"
        XCTAssert(keep.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", says, says))
            .firstMatch.exists, "Keep layers? doesn't say it writes beach.ora next to beach.png")
        photo.shot("documents-1-keep-layers")
        keep.buttons["photo.file.keep-layers.document"].firstMatch.click()
        XCTAssert(photo.window(named: "beach.ora").waitForExistence(timeout: 30), "the window isn't titled beach.ora")
        expectStatus("Saved", photo)
        let saved = try Data(contentsOf: folder.appending(path: "beach.ora"))
        XCTAssertEqual(Array(saved.prefix(4)), [0x50, 0x4B, 0x03, 0x04], "beach.ora isn't a zip")
        let first = Self.entries(of: saved).first
        XCTAssertEqual(first?.name, "mimetype", "beach.ora's first entry")
        XCTAssertEqual(first.map { String(decoding: $0.data, as: UTF8.self) }, "image/openraster", "beach.ora's mimetype")
        photo.shot("documents-1-saved")

        // 4. Command-W closes with no prompt; Open Recent > beach.ora brings both layers back.
        photo.press(character: "w", .command)
        XCTAssert(photo.window(named: "beach.ora").waitForNonExistence(timeout: 10), "Command-W didn't close a saved window")
        photo.shot("documents-1-closed", screen: true)
        quit(photo)
        photo = launch(photoArguments(saveTo: folder), window: nil)
        openRecent("beach.ora", photo)
        XCTAssert(photo.window(named: "beach.ora").waitForExistence(timeout: 30), "Open Recent didn't reopen beach.ora")
        openLayers(photo)
        let header = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '2 layers'"))
        XCTAssert(header.firstMatch.waitForExistence(timeout: 10), "the image header doesn't count 2 layers")
        expectRow("Layer 1", meta: "Multiply 50%", photo)
        let share = Self.differingShare(edited, steadyCanvas(photo))
        XCTAssertLessThanOrEqual(share, 0.01, "the reopened canvas differs from the saved one in \(share * 100)% of its pixels")
        photo.shot("documents-1-reopened")

        // 5. Command-Z: nothing to undo, nothing to redo.
        photo.press(character: "z", .command)
        let edit = menu("Edit", photo)
        XCTAssert(edit.menuItems["Undo"].waitForExistence(timeout: 3), "the Edit menu has no plain Undo")
        for item in ["Undo", "Redo"] { XCTAssertFalse(edit.menuItems[item].isEnabled, "Edit > \(item) is enabled") }
        photo.shot("documents-1-nothing-to-undo", screen: true)
        photo.press(.escape)
    }

    /// PJ-1b: a save into a locked folder alerts and leaves "Not saved".
    @MainActor func testFailedSaveSaysNotSaved() throws {
        let (folder, beach) = try beachFolder("pj1b")
        let locked = folder.appending(path: "locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: locked.path)
        addTeardownBlock { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        let photo = launch(photoArguments(open: beach, saveTo: locked), window: "beach.png")
        newLayer(photo)
        paint(photo)
        photo.shot("documents-1b-edited")

        photo.press(character: "s", .command)
        alert(photo).buttons["photo.file.keep-layers.document"].firstMatch.click()
        let failed = alert(photo), prefix = "The image couldn't be saved: "
        let message = failed.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", prefix, prefix))
        XCTAssert(message.firstMatch.waitForExistence(timeout: 30), "a save into a locked folder showed no save alert")
        photo.shot("documents-1b-save-alert")
        failed.buttons["OK"].click()
        expectStatus("Not saved", photo)
        XCTAssertFalse(FileManager.default.fileExists(atPath: locked.appending(path: "beach.ora").path), "a failed save left a file")
        photo.shot("documents-1b-not-saved")
    }

    /// PJ-4: four bad documents, four ArchiveError messages, the window left empty.
    @MainActor func testOpenBadDocuments() throws {
        let (folder, beach) = try beachFolder("pj4")
        let maker = launch(photoArguments(open: beach, saveTo: folder), window: "beach.png")
        newLayer(maker)
        maker.press(character: "s", [.command, .shift])
        XCTAssert(maker.window(named: "beach.ora").waitForExistence(timeout: 30), "Save As wrote no beach.ora")
        quit(maker)
        let entries = Self.entries(of: try Data(contentsOf: folder.appending(path: "beach.ora")))
        func edited(_ from: String, _ to: String) -> Data {
            Self.storedZip(entries.map { entry -> (name: String, data: Data) in
                guard entry.name == "photo/document.json" else { return entry }
                let json = String(decoding: entry.data, as: UTF8.self)
                XCTAssert(json.contains(from), "photo/document.json holds no \(from)")
                return (entry.name, Data(json.replacingOccurrences(of: from, with: to).utf8))
            })
        }
        let cases: [(file: String, data: Data, message: String)] = [
            ("NotZip.ora", Data("not a zip".utf8), "It isn't a Photo Document or an image Photo can open."),
            ("Newer.ora", edited(#""format":1,"#, #""format":2,"#), "It was saved by a newer version of Photo. Update Photo to open it."),
            ("Missing.ora", Self.storedZip(entries.filter { $0.name != "data/layer-2.png" }), "It is damaged and can't be read."),
            ("Large.ora", edited(#""canvas":{"height":600,"width":800}"#, #""canvas":{"height":4000,"width":5000}"#),
             "It is larger than Photo can open: up to 16 megapixels."),
        ]
        for (index, item) in cases.enumerated() {
            let url = folder.appending(path: item.file)
            try item.data.write(to: url)
            let photo = launch(photoArguments(open: url), window: nil)
            let shown = alert(photo)
            XCTAssert(text(item.message, in: shown).waitForExistence(timeout: 30), "opening \(item.file) didn't say \(item.message)")
            photo.shot("documents-4-\(index + 1)")
            shown.buttons["OK"].click()
            XCTAssert(photo.app.windows["Photo"].waitForExistence(timeout: 5), "the window didn't stay empty after \(item.file)")
            XCTAssertFalse(photo.element("photo.bar.saved").exists, "a failed open left an image (photo.bar.saved)")
            photo.shot("documents-4-\(index + 1)-ok")
            photo.app.terminate()
        }
    }

    /// PJ-2: the unsaved prompt's Cancel and Don't Save, then Open Recent and Clear Menu.
    @MainActor func testUnsavedPromptAndOpenRecent() throws {
        let (_, beach) = try beachFolder("pj2")
        let original = try Data(contentsOf: beach)
        var photo = launch(photoArguments(open: beach), window: "beach.png")
        paint(photo)
        expectStatus("Edited", photo)
        photo.shot("documents-2-painted")

        // 2. Command-W asks; Cancel keeps the window, still Edited.
        let cancel = askToClose(photo, "photo.unsaved.cancel")
        cancel.click()
        XCTAssert(cancel.waitForNonExistence(timeout: 5), "Cancel left the unsaved alert up")
        XCTAssert(photo.window(named: "beach.png").exists, "Cancel closed the window")
        // The autosave, 5 s after the stroke, has usually run by now: "Edited, autosaved" is still edited.
        expectStatus("Edited", photo, prefix: true)
        photo.shot("documents-2-cancelled")

        // 3. Command-W, Don't Save closes; Open Recent's first entry reopens beach.png as it was on disk.
        askToClose(photo, "photo.unsaved.dontSave").click()
        XCTAssert(photo.window(named: "beach.png").waitForNonExistence(timeout: 10), "Don't Save didn't close the window")
        photo.shot("documents-2-closed", screen: true)
        XCTAssertEqual(try Data(contentsOf: beach), original, "Don't Save wrote beach.png")
        quit(photo)
        photo = launch(photoArguments(), window: nil)
        openRecent("beach.png", photo)
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "Open Recent didn't reopen beach.png")
        expectStatus("Saved", photo)
        let undo = photo.app.buttons["photo.bar.undo"]
        XCTAssert(undo.waitForExistence(timeout: 5) && !undo.isEnabled, "the reopened beach.png kept the stroke's undo")
        photo.shot("documents-2-reopened")

        // 4. Clear Menu leaves only Clear Menu, disabled.
        recentMenu(photo).menuItems["Clear Menu"].click()
        let items = recentMenu(photo).children(matching: .menuItem).allElementsBoundByIndex.filter { !$0.title.isEmpty }
        XCTAssertEqual(items.map(\.title), ["Clear Menu"], "Open Recent after Clear Menu")
        XCTAssertFalse(items.first?.isEnabled ?? true, "Clear Menu is enabled with nothing to clear")
        photo.shot("documents-2-recent-cleared", screen: true)
        photo.press(.escape)
    }

    // MARK: - Steps

    /// Launches Photo with `arguments` and waits for a window (titled `window` when given).
    @MainActor private func launch(_ arguments: [String], window: String?) -> Journey {
        let photo = Journey("Photo", self, arguments: arguments)
        XCTAssert((window.map { photo.window(named: $0) } ?? photo.app.windows.firstMatch).waitForExistence(timeout: 30), "no \(window ?? "Photo") window opened")
        return photo
    }

    /// Command-Q, as a person quits, so the app's defaults (Open Recent) are written.
    @MainActor private func quit(_ photo: Journey) {
        photo.press(character: "q", .command)
        if !photo.app.wait(for: .notRunning, timeout: 15) { photo.app.terminate() }
    }

    /// `photo.bar.saved`'s label reads `status`, or starts with it when
    /// `prefix` (SwiftUI values can read empty).
    @MainActor private func expectStatus(_ status: String, _ photo: Journey, prefix: Bool = false) {
        let saved = photo.element("photo.bar.saved")
        XCTAssert(saved.waitForExistence(timeout: 10), "no save status (photo.bar.saved)")
        let reads = { prefix ? saved.label.hasPrefix(status) : saved.label == status }
        for _ in 0..<25 where !reads() { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssert(reads(), "photo.bar.saved's label reads \(saved.label), not \(status)\(prefix ? "…" : "")")
    }

    /// Layer > New Layer by its key (Shift-Command-N): one "New Layer" step.
    @MainActor private func newLayer(_ photo: Journey) {
        photo.press(character: "n", [.command, .shift])
        expect("Undo New Layer", photo)
    }

    /// A Brush stroke across the canvas: one "Paint" step.
    @MainActor private func paint(_ photo: Journey) {
        photo.element("suite.tools").buttons["Brush"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.7))
        expect("Undo Paint", photo)
    }

    /// The sidebar's layer list (`photo.layers`) is up.
    @MainActor private func openLayers(_ photo: Journey) {
        let layers = photo.element("suite.sidebar").descendants(matching: .any)["photo.layers"]
        XCTAssert(layers.waitForExistence(timeout: 5), "the sidebar has no layer list (photo.layers)")
    }

    /// Waits for the button titled `title`, such as the window toolbar's "Undo Paint".
    @MainActor private func expect(_ title: String, _ photo: Journey) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "no \(title) button")
    }

    /// The Layers list shows `name` with `meta` (blend and opacity) on its row.
    @MainActor private func expectRow(_ name: String, meta: String, _ photo: Journey) {
        let row = photo.app.staticTexts[name], detail = photo.app.staticTexts[meta]
        XCTAssert(row.waitForExistence(timeout: 5) && detail.waitForExistence(timeout: 5) && abs(row.frame.midY - detail.frame.midY) < 4,
                  "no \(name) row reading \(meta)")
    }

    /// Picks `mode` from the inspector's Blend Mode menu (`photo.layer.blend`).
    @MainActor private func chooseBlend(_ mode: String, _ photo: Journey) {
        let types = [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) }
        let picker = photo.element("suite.inspector").descendants(matching: .any).matching(NSPredicate(format:
            "elementType IN %@ AND (identifier == 'photo.layer.blend' OR label == 'Blend Mode')", types)).firstMatch
        XCTAssert(picker.waitForExistence(timeout: 5), "no Blend Mode menu (photo.layer.blend)")
        picker.click()
        let item = photo.app.menus.firstMatch.descendants(matching: .menuItem).matching(NSPredicate(format: "title == %@", mode)).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the Blend Mode menu has no \(mode)")
        item.click()
        expect("Undo Blend Mode", photo)
    }

    /// Types `value` into the panel number labelled `label`, or identified by it: click it, clear it, type, Return.
    @MainActor private func typeValue(_ value: String, into label: String, _ photo: Journey) {
        let panel = photo.element("suite.inspector")
        let matches = panel.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label))
        XCTAssert(matches.firstMatch.waitForExistence(timeout: 5), "no \(label) in the panel")
        let target = matches.element(boundBy: matches.count - 1)
        let name = target.label.isEmpty ? label : target.label
        target.click()
        let field = panel.textFields[name].waitForExistence(timeout: 3) ? panel.textFields[name] : panel.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(label) opened no field")
        field.click()
        photo.app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<16 { photo.app.typeKey(.delete, modifierFlags: []) }
        photo.app.typeText(value)
        photo.app.typeKey(.return, modifierFlags: [])
    }

    /// Command-W on an edited window: the unsaved alert, checked, and its button `identifier`.
    @MainActor private func askToClose(_ photo: Journey, _ identifier: String) -> XCUIElement {
        photo.press(character: "w", .command)
        let ask = alert(photo)
        let question = "Do you want to save the changes made to the document “beach.png”?"
        XCTAssert(text(question, in: ask).waitForExistence(timeout: 10), "Command-W asked no unsaved-changes question")
        let ids = ["photo.unsaved.save", "photo.unsaved.dontSave", "photo.unsaved.cancel"]
        XCTAssert(ids.allSatisfy { ask.buttons[$0].exists }, "the unsaved alert lacks one of \(ids)")
        photo.shot(identifier == "photo.unsaved.cancel" ? "documents-2-unsaved-alert" : "documents-2-unsaved-again")
        return ask.buttons[identifier]
    }

    @MainActor private func menu(_ title: String, _ photo: Journey) -> XCUIElement {
        let item = photo.app.menuBars.firstMatch.menuBarItems[title]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(title) menu")
        item.click()
        return item
    }

    /// File > Open Recent's submenu, open.
    @MainActor private func recentMenu(_ photo: Journey) -> XCUIElement {
        let parent = menu("File", photo).menuItems["Open Recent"]
        XCTAssert(parent.waitForExistence(timeout: 3), "the File menu has no Open Recent")
        parent.hover()
        return parent.menus.firstMatch
    }

    /// File > Open Recent: `name` is the first entry; clicks it.
    @MainActor private func openRecent(_ name: String, _ photo: Journey) {
        let first = recentMenu(photo).children(matching: .menuItem).firstMatch
        XCTAssertEqual(first.title, name, "Open Recent's first entry")
        first.click()
    }

    /// A system alert: the window's sheet, or a dialog.
    @MainActor private func alert(_ photo: Journey) -> XCUIElement {
        let sheet = photo.app.sheets.firstMatch
        return sheet.waitForExistence(timeout: 10) ? sheet : photo.app.dialogs.firstMatch
    }

    /// The first element under `root` whose label or value is `string`.
    @MainActor private func text(_ string: String, in root: XCUIElement) -> XCUIElement {
        root.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", string, string)).firstMatch
    }

    /// The canvas with the pointer off it (no brush cursor), a second after it
    /// was last asked to draw (it renders off the main actor).
    @MainActor private func steadyCanvas(_ photo: Journey) -> Data {
        photo.element("photo.bar.saved").hover()
        Thread.sleep(forTimeInterval: 1)
        return photo.element("suite.canvas").screenshot().pngRepresentation
    }
    // MARK: - Files

    /// A fresh temp folder holding the kit's beach.png, removed after the test.
    @MainActor private func beachFolder(_ name: String) throws -> (URL, URL) {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-documents-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let beach = folder.appending(path: "beach.png")
        try writeTestPhoto(to: beach)
        return (folder, beach)
    }

    /// The entries of a zip of stored entries, in file order, read from their local headers.
    private static func entries(of data: Data) -> [(name: String, data: Data)] {
        let bytes = [UInt8](data)
        func u16(_ at: Int) -> Int { at >= 0 && at + 1 < bytes.count ? Int(bytes[at]) | Int(bytes[at + 1]) << 8 : 0 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }
        var found: [(name: String, data: Data)] = [], at = 0
        while at + 30 <= bytes.count, u32(at) == 0x0403_4B50 {
            let size = u32(at + 18), nameLength = u16(at + 26), start = at + 30 + nameLength + u16(at + 28)
            guard start + size <= bytes.count else { break }
            found.append((String(decoding: bytes[(at + 30)..<(at + 30 + nameLength)], as: UTF8.self), Data(bytes[start..<(start + size)])))
            at = start + size
        }
        return found
    }

    /// A zip of stored entries in the given order, laid out as PhotoZip writes one
    /// (PKWARE APPNOTE: local headers, the central directory, the end record).
    private static func storedZip(_ entries: [(name: String, data: Data)]) -> Data {
        var out: [UInt8] = [], central: [UInt8] = []
        func put(_ fields: [(Int, Int)], _ into: inout [UInt8]) {
            for (value, size) in fields { for byte in 0..<size { into.append(UInt8((value >> (8 * byte)) & 0xFF)) } }
        }
        for (name, data) in entries {
            let nameBytes = Array(name.utf8), bytes = [UInt8](data), crc = Int(crc32(bytes)), offset = out.count
            // Signature, version 1.0, no flags, stored, time 0, date 1980-01-01, CRC, sizes, name, no extra.
            put([(0x0403_4B50, 4), (10, 2), (0, 2), (0, 2), (0, 2), (0x21, 2), (crc, 4), (bytes.count, 4), (bytes.count, 4), (nameBytes.count, 2), (0, 2)], &out)
            out += nameBytes + bytes
            // The central record adds version made by 2.0, no comment, disk 0, no attributes, and the local offset.
            put([(0x0201_4B50, 4), (20, 2), (10, 2), (0, 2), (0, 2), (0, 2), (0x21, 2), (crc, 4), (bytes.count, 4), (bytes.count, 4),
                 (nameBytes.count, 2), (0, 2), (0, 2), (0, 2), (0, 2), (0, 4), (offset, 4)], &central)
            central += nameBytes
        }
        let centralOffset = out.count
        out += central
        put([(0x0605_4B50, 4), (0, 2), (0, 2), (entries.count, 2), (entries.count, 2), (central.count, 4), (centralOffset, 4), (0, 2)], &out)
        return Data(out)
    }

    /// The zip CRC-32 (reflected polynomial 0xEDB88320).
    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? 0xEDB8_8320 ^ (crc >> 1) : crc >> 1 }
        }
        return ~crc
    }

    // MARK: - Canvas

    /// The share of pixels whose color differs by more than 6 of 255 between two PNG shots,
    /// both drawn at 200 x 150; 1 when they can't be compared.
    private static func differingShare(_ first: Data, _ second: Data) -> Double {
        let (a, b) = (rgba(first), rgba(second))
        guard a.count == b.count, !a.isEmpty else { return 1 }
        let differing = stride(from: 0, to: a.count, by: 4).filter { at in
            (0..<3).contains { abs(Int(a[at + $0]) - Int(b[at + $0])) > 6 }
        }.count
        return Double(differing) / Double(a.count / 4)
    }

    /// A PNG drawn into 200 x 150 8-bit RGBA; empty if it doesn't decode.
    private static func rgba(_ png: Data) -> [UInt8] {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil), let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(data: nil, width: 200, height: 150, bitsPerComponent: 8, bytesPerRow: 800, space: space,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return [] }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 200, height: 150))
        guard let pixels = context.data else { return [] }
        return Array(UnsafeBufferPointer(start: pixels.assumingMemoryBound(to: UInt8.self), count: 200 * 150 * 4))
    }
}
