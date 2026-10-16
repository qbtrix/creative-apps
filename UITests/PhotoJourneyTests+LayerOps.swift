// PhotoJourneyTests+LayerOps.swift: PJ-7, Duplicate Layer, Merge Down and
// Flatten Image from the Layer menu (photo-edit E-10;
// docs/blueprints/photo/features/photo-edit.md, Journey steps 3 and review
// note 3). On a fresh tools.png it presses Command-J ("Background copy" above
// Background, "Undo Duplicate Layer"), sets the copy's blend to Screen and its
// opacity to 60, presses Command-E (one "Background" layer, the canvas the
// same as before the merge within a small tolerance, "Undo Merge Down"), adds
// a layer, paints on it with the brush and flattens ("Undo Flatten Image").
// With one layer left, Merge Down and Flatten Image are disabled with their
// reasons. Last, it relaunches on `-PhotoFixture layered` (Paint, Curves 1,
// Background, top first) with Paint selected: Merge Down needs a pixel layer
// below. Undo steps are read from the top bar's Undo button, as
// PhotoJourneyTests does; a disabled menu item's reason is its help tag, shown
// by hovering it, as HaloLayersJourneyTests does. Photo's help tag reaches
// accessibility with no text (dev run 38835566584: a HelpTag beside Merge
// Down, no label, title or value), so the tag's text is read from its pixels
// with Vision when accessibility gives none. The list rows carry no
// identifier, so the copy's selection is read from its row: the blend and
// opacity just set show beside "Background copy". Merge Down and Flatten
// Image each report how soon "Merging…" showed (PB-16, report-only).
// Shots: `photo-layerops-*`.
import CoreGraphics
import ImageIO
import Vision
import XCTest

final class PhotoLayerOpsJourneyTests: XCTestCase {
    /// PJ-7: duplicate, merge down and flatten, then each one's refusal.
    @MainActor func testDuplicateMergeAndFlatten() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-layerops-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "tools.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.app.windows["tools.png"].waitForExistence(timeout: 30), "tools.png didn't open")
        let layers = photo.element("suite.sidebar").descendants(matching: .any)["photo.layers"]
        XCTAssert(layers.waitForExistence(timeout: 5), "the sidebar has no layer list (photo.layers)")
        let background = photo.app.staticTexts["Background"], copy = photo.app.staticTexts["Background copy"]
        XCTAssert(background.waitForExistence(timeout: 5), "the layer list doesn't list Background")
        photo.shot("layerops-opened")

        // 1. Command-J: "Background copy" above Background, "Undo Duplicate Layer".
        photo.press(character: "j", .command)
        expect("Undo Duplicate Layer", photo, "Command-J made no Duplicate Layer step")
        XCTAssert(copy.waitForExistence(timeout: 5), "Command-J listed no Background copy")
        expectHeader("2 layers", photo, "the header doesn't count two layers after Duplicate Layer")
        XCTAssert(waitUntil { copy.frame.minY < background.frame.minY }, "Background copy isn't above Background")
        photo.shot("layerops-duplicated")

        // 2. Blend Screen, opacity 60: the settings land on the copy, so the copy is the selected layer.
        let modes = openBlendMenu(photo)
        XCTAssert(modes.contains("Screen"), "the Blend Mode menu lists \(modes), no Screen")
        chooseOpenItem("Screen", photo)
        expect("Undo Blend Mode", photo, "choosing Screen made no Blend Mode step")
        typeValue("60", into: "photo.layer.opacity", photo)
        let meta = photo.app.staticTexts["Screen 60%"]
        XCTAssert(meta.waitForExistence(timeout: 5), "Screen and 60 didn't show as Screen 60% on a row")
        XCTAssert(
            abs(meta.frame.midY - copy.frame.midY) < 4,
            "Screen 60% isn't on Background copy's row (\(meta.frame), \(copy.frame)): the copy wasn't selected")
        photo.shot("layerops-screen-60")

        // 3. Command-E: one layer, Background; the picture is the same as before the merge.
        let before = steadyCanvas(photo)
        photo.press(character: "e", .command)
        reportMerging("merge-down", photo, until: photo.app.buttons["Undo Merge Down"])
        expect("Undo Merge Down", photo, "Command-E made no Merge Down step")
        XCTAssert(copy.waitForNonExistence(timeout: 5), "Merge Down left Background copy in the list")
        XCTAssert(background.exists, "Merge Down didn't keep Background")
        XCTAssertFalse(meta.exists, "the merged Background shows Screen 60%; it keeps its own Normal 100%")
        expectHeader("1 layer", photo, "the header doesn't count one layer after Merge Down")
        var share = 1.0
        XCTAssert(
            waitUntil {
                share = Self.differingShare(before, self.canvasPixels(photo))
                return share <= 0.005
            },
            "the canvas changed in the merge: \(share * 100)% of its pixels differ by more than 6 of 255")
        photo.shot("layerops-merged")

        // 4. New Layer, a brush stroke on it, Flatten Image: one layer, "Undo Flatten Image".
        photo.click("New Layer", in: .window)
        expect("Undo New Layer", photo, "New Layer made no undo step")
        let layer1 = photo.app.staticTexts["Layer 1"]
        XCTAssert(layer1.waitForExistence(timeout: 5), "New Layer listed no Layer 1")
        photo.element("suite.tools").buttons["Brush"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.7))
        expect("Undo Paint", photo, "the brush stroke on Layer 1 didn't paint")
        expectHeader("2 layers", photo, "the header doesn't count two layers before Flatten Image")
        photo.shot("layerops-painted")
        choose("Flatten Image", from: "Layer", photo)
        reportMerging("flatten", photo, until: photo.app.buttons["Undo Flatten Image"])
        expect("Undo Flatten Image", photo, "Layer > Flatten Image made no Flatten Image step")
        XCTAssert(layer1.waitForNonExistence(timeout: 5), "Flatten Image left Layer 1 in the list")
        XCTAssert(background.exists, "Flatten Image didn't leave one Background layer")
        expectHeader("1 layer", photo, "the header doesn't count one layer after Flatten Image")
        photo.shot("layerops-flattened")

        // 5. With one layer, Merge Down and Flatten Image say why they can't run.
        expectDisabled("Merge Down", in: "Layer", help: "There's no layer below to merge into.", photo)
        expectDisabled("Flatten Image", in: "Layer", help: "The image already has one layer.", photo)
        photo.shot("layerops-one-layer")

        // 6. On the layered fixture, Paint sits on the Curves 1 adjustment layer.
        photo.app.terminate()
        let layered = Journey("Photo", self, arguments: photoArguments(fixture: "layered"))
        XCTAssert(layered.element("photo.status.preview").waitForExistence(timeout: 30), "-PhotoFixture layered shows no Preview data pill")
        let layeredList = layered.element("suite.sidebar").descendants(matching: .any)["photo.layers"]
        XCTAssert(layeredList.waitForExistence(timeout: 5), "the sidebar has no layer list on the layered fixture")
        let paint = layered.app.staticTexts["Paint"], curves = layered.app.staticTexts["Curves 1"]
        XCTAssert(paint.waitForExistence(timeout: 5), "the layered fixture lists no Paint")
        XCTAssert(curves.exists, "the layered fixture lists no Curves 1")
        XCTAssert(waitUntil { paint.frame.minY < curves.frame.minY }, "Paint isn't above Curves 1")
        // Select Paint, the top layer, by key (Select Layer Above): a row click focuses the list,
        // whose highlight fails contrast. The fixture opens on Paint, so a press at the top does nothing.
        layered.press(character: "]", [.command, .option])
        expectDisabled("Merge Down", in: "Layer", help: "Merge Down needs a pixel layer below.", layered)
        layered.shot("layerops-adjustment-below")
    }

    // MARK: - Steps

    /// PB-16, report-only: polls from the merge key until `done` shows,
    /// counting the polls that find "Merging…" (`photo.edit.merging`, shown
    /// once a merge has run 100 ms) and when it first showed. Attached as
    /// "perf-report-<series>"; a quick merge never shows it, which isn't a failure.
    @MainActor private func reportMerging(_ series: String, _ photo: Journey, until done: XCUIElement) {
        let note = photo.element("photo.edit.merging")
        let pressed = Date()
        var (polls, seen, firstSeen) = (0, 0, Double?.none)
        while !done.exists, Date().timeIntervalSince(pressed) < 60 {
            polls += 1
            if note.exists {
                seen += 1
                firstSeen = firstSeen ?? Date().timeIntervalSince(pressed) * 1000
            }
        }
        let ms = String(format: "%.0f", Date().timeIntervalSince(pressed) * 1000)
        let line = "PB-16 PJ-7 \(series): samples=\(seen) of \(polls) polls, first-seen-ms="
            + "\(firstSeen.map { String(format: "%.0f", $0) } ?? "n/a") merge-ms=\(ms) report-only "
            + "(counted from the key press; no FrameProbe mark, Photo's window doesn't publish one)"
        print(line)
        let attachment = XCTAttachment(string: line)
        attachment.name = "perf-report-\(series)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits for the button titled `title`, such as the top bar's "Undo Merge Down".
    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    /// Waits for a label holding `text`, as the header's "tools.png, 800 × 600 px, sRGB · 1 layer".
    @MainActor private func expectHeader(_ text: String, _ photo: Journey, _ message: String) {
        let matching = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
        if matching.firstMatch.waitForExistence(timeout: 5) { return }
        let header = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", " px, sRGB"))
            .firstMatch
        XCTFail("\(message) (no label holds \(text); the header reads \(header.exists ? header.label : "nothing"))")
    }

    /// Picks the enabled `item` from the menu bar's `menu`.
    @MainActor private func choose(_ item: String, from menu: String, _ photo: Journey) {
        photo.app.menuBars.menuBarItems[menu].click()
        let entry = photo.app.menuBars.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 5), "the \(menu) menu has no \(item)")
        XCTAssert(entry.isEnabled, "\(menu) > \(item) is disabled")
        entry.click()
    }

    /// `menu`'s item `item` is disabled and the help tag hovering it shows
    /// reads `help`; the menu is closed again. The tag's text comes from
    /// accessibility when it has any, else from the tag's pixels.
    @MainActor private func expectDisabled(_ item: String, in menu: String, help: String, _ photo: Journey) {
        let bar = photo.app.menuBars.firstMatch.menuBarItems[menu]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(menu) menu")
        bar.click()
        let entry = bar.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the \(menu) menu has no \(item)")
        XCTAssertFalse(entry.isEnabled, "\(menu) > \(item) is enabled")
        entry.hover()
        let tags = photo.app.helpTags
        XCTAssert(tags.firstMatch.waitForExistence(timeout: 5), "hovering \(menu) > \(item) showed no help tag")
        var read: [String] = []
        let said = waitUntil {
            read = tags.allElementsBoundByIndex.map { self.helpText($0) }
            return read.contains { Self.says($0, help) }
        }
        if !said, tags.firstMatch.exists {
            let attachment = XCTAttachment(screenshot: tags.firstMatch.screenshot())
            attachment.name = "photo-layerops-help-tag"
            add(attachment)
        }
        XCTAssert(said, "\(menu) > \(item) doesn't say \(help); its help tag reads \(read)")
        photo.press(.escape)
        _ = photo.app.menus.firstMatch.waitForNonExistence(timeout: 2)
    }

    /// A help tag's text: its label, title and value, or, when they're all
    /// empty, the words Vision recognizes in a shot of it.
    @MainActor private func helpText(_ tag: XCUIElement) -> String {
        guard tag.exists else { return "" }
        let named = [tag.label, tag.title, (tag.value as? String) ?? ""].filter { !$0.isEmpty }
        if !named.isEmpty { return named.joined(separator: " ") }
        return Self.recognizedText(tag.screenshot().pngRepresentation)
    }

    /// Whether `text` holds `expected`, ignoring case, punctuation and
    /// spacing, so a recognized "There’s" or "Theres" matches "There's".
    private static func says(_ text: String, _ expected: String) -> Bool {
        func letters(_ string: String) -> String {
            String(string.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        }
        let wanted = letters(expected)
        return !wanted.isEmpty && letters(text).contains(wanted)
    }

    /// The lines of text Vision finds in a PNG shot, joined by spaces; the
    /// shot is drawn three times larger first, as a help tag's type is small.
    private static func recognizedText(_ png: Data) -> String {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            image.width > 0, image.height > 0
        else { return "" }
        let width = image.width * 3, height = image.height * 3
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return "" }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let large = context.makeImage() else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        guard (try? VNImageRequestHandler(cgImage: large, options: [:]).perform([request])) != nil else { return "" }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: " ")
    }

    /// Clicks the inspector's Blend Mode picker open and returns its menu's item titles.
    @MainActor private func openBlendMenu(_ photo: Journey) -> [String] {
        let types = [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) }
        let picker = photo.element("suite.inspector").descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND (identifier == %@ OR label == %@)", types, "photo.layer.blend", "Blend Mode")
        ).firstMatch
        XCTAssert(picker.waitForExistence(timeout: 5), "no Blend Mode menu (photo.layer.blend)")
        picker.click()
        let menu = photo.app.menus.firstMatch
        XCTAssert(menu.waitForExistence(timeout: 3), "clicking Blend Mode opened no menu")
        let items = menu.descendants(matching: .menuItem)
        XCTAssert(items.firstMatch.waitForExistence(timeout: 3), "the Blend Mode menu shows no items")
        return items.allElementsBoundByIndex.map { $0.title }
    }

    /// Clicks the open menu's item `title`; the menu closes.
    @MainActor private func chooseOpenItem(_ title: String, _ photo: Journey) {
        let item = photo.app.menus.firstMatch.descendants(matching: .menuItem)
            .matching(NSPredicate(format: "title == %@", title)).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the open menu has no \(title)")
        item.click()
        _ = photo.app.menus.firstMatch.waitForNonExistence(timeout: 2)
    }

    /// Types `value` into the panel number labelled `label`, or identified by it
    /// (the last element so labelled, after the section header and slider):
    /// click it, type, Return.
    @MainActor private func typeValue(_ value: String, into label: String, _ photo: Journey) {
        let panel = photo.element("suite.inspector")
        let matches = panel.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label))
        XCTAssert(matches.firstMatch.waitForExistence(timeout: 5), "no \(label) in the panel")
        let target = matches.element(boundBy: matches.count - 1)
        let name = target.label.isEmpty ? label : target.label
        target.click()
        let named = panel.textFields[name]
        let field = named.waitForExistence(timeout: 3) ? named : panel.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(label)'s number opened no field to type in")
        // Clear without Command-A (Photo's Select > All has it).
        field.click()
        photo.app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<16 { photo.app.typeKey(.delete, modifierFlags: []) }
        photo.app.typeText(value)
        photo.app.typeKey(.return, modifierFlags: [])
    }

    // MARK: - Canvas

    @MainActor private func canvasPixels(_ photo: Journey) -> Data {
        photo.element("suite.canvas").screenshot().pngRepresentation
    }

    /// The canvas once two shots half a second apart match (it renders off the
    /// main actor), or the last shot after five seconds.
    @MainActor private func steadyCanvas(_ photo: Journey) -> Data {
        var last = canvasPixels(photo)
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.5)
            let next = canvasPixels(photo)
            if next == last { break }
            last = next
        }
        return last
    }

    /// The share of pixels whose color channels differ by more than
    /// `tolerance` (of 255) between two PNG shots; 1 when they can't be compared.
    private static func differingShare(_ first: Data, _ second: Data, tolerance: Int = 6) -> Double {
        guard let a = rgba(first), let b = rgba(second), a.width == b.width, a.height == b.height,
            a.bytes.count == b.bytes.count, a.width > 0, a.height > 0
        else { return 1 }
        let count = a.width * a.height
        var differing = 0
        for pixel in 0..<count {
            let base = pixel * 4
            for channel in base..<(base + 3) where abs(Int(a.bytes[channel]) - Int(b.bytes[channel])) > tolerance {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(count)
    }

    /// A PNG decoded to 8-bit RGBA rows, `width * height * 4` bytes; nil if it doesn't decode.
    private static func rgba(_ png: Data) -> (width: Int, height: Int, bytes: [UInt8])? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (width, height, bytes) : nil
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
