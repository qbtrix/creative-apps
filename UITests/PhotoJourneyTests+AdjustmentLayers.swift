// PhotoJourneyTests+AdjustmentLayers.swift: PJ-9 testAdjustmentLayer
// (photo-adjustment-layers AL-8; docs/blueprints/photo/features/
// photo-adjustment-layers.md, Journey steps 1). On a fresh tools.png, in the
// Layers tab, Layer > New Adjustment Layer > Curves adds "Curves 1" above
// Background (its `photo.layer.<id>.kind` reads "Adjustment layer"),
// selected: the Adjust tab shows only Curves under the header "Curves 1",
// "Adjusts the layers below", and the step is "Undo New Adjustment Layer".
// The curve's midpoint dragged up changes the canvas as one "Undo Curves"
// step; the row's eye hides it and the canvas is the opened one again. A new
// layer above takes a brush stroke; showing the adjustment again changes the
// canvas but not the stroke, so the stroke is unadjusted. Send Backward once
// makes the adjustment the bottom row, Send Backward is then disabled and the
// row reads "Nothing below to adjust."; opacity 0 leaves the canvas as it was
// (the adjustment already adjusts nothing) and Command-Z undoes it. Background
// selected reads "Image", "Adjusts the whole image". Last, the error: a brush
// drag with the adjustment selected says "Select an image layer in the Layers
// tab to paint on." and changes nothing. Layers are picked by key (Select
// Layer Above/Below), as testTier1Layers does. Shots: `photo-adjlayer-*`.
import CoreGraphics
import ImageIO
import XCTest

extension PhotoJourneyTests {
    /// PJ-9: an adjustment layer added, edited, hidden, reordered, faded and refused as a paint target.
    @MainActor func testAdjustmentLayer() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-adjlayer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "tools.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.app.windows["tools.png"].waitForExistence(timeout: 30), "tools.png didn't open")
        let layersTab = photo.app.radioButtons["Layers"], adjustTab = photo.app.radioButtons["Adjust"]
        XCTAssert(layersTab.waitForExistence(timeout: 5), "no Layers tab")
        layersTab.click()
        let background = photo.app.staticTexts["Background"], curves = photo.app.staticTexts["Curves 1"]
        XCTAssert(background.waitForExistence(timeout: 5), "the Layers tab doesn't list Background")
        let opened = adjSteadyCanvas(photo)
        photo.shot("adjlayer-opened")

        // 1. Layer > New Adjustment Layer > Curves: "Curves 1", an adjustment layer above Background.
        adjChooseAdjustmentLayer("Curves", photo)
        adjExpect("Undo New Adjustment Layer", photo, "New Adjustment Layer > Curves made no undo step")
        XCTAssert(curves.waitForExistence(timeout: 5), "New Adjustment Layer > Curves listed no Curves 1")
        XCTAssert(adjWaitUntil { curves.frame.minY < background.frame.minY }, "Curves 1 isn't above Background")
        let kind = photo.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@ AND label == %@",
            "photo.layer.", ".kind", "Adjustment layer")).firstMatch
        XCTAssert(kind.waitForExistence(timeout: 5), "no photo.layer.<id>.kind reads Adjustment layer")
        XCTAssert(abs(kind.frame.midY - curves.frame.midY) < 12, "the Adjustment layer kind isn't on Curves 1's row")
        photo.shot("adjlayer-added")
        adjustTab.click()
        adjExpectHeader("Curves 1", "Adjusts the layers below", photo)
        XCTAssert(photo.element("photo.curves").waitForExistence(timeout: 5), "the Adjust tab shows no Curves")
        for other in ["Exposure", "Black", "Hue"] {
            XCTAssertFalse(photo.app.sliders[other].exists, "the Adjust tab of Curves 1 shows \(other)")
        }
        photo.shot("adjlayer-adjust-tab")

        // 2. The curve's midpoint up: the canvas differs, one Curves step.
        photo.drag(on: "photo.curves", from: CGVector(dx: 0.5, dy: 0.5), to: CGVector(dx: 0.5, dy: 0.25))
        adjExpect("Undo Curves", photo, "the curve drag made no Curves step")
        XCTAssert(adjWaitUntil { Self.adjShare(opened, self.adjCanvas(photo)) > 0.05 }, "the curve didn't change the canvas")
        photo.shot("adjlayer-curved")

        // 3. The eye hides it: the canvas is the opened one again.
        layersTab.click()
        photo.click("Hide Curves 1", in: .window)
        adjExpect("Undo Hide Layer", photo, "Curves 1's eye didn't hide it")
        adjExpectCanvas(like: opened, photo, "hiding Curves 1 didn't give back the opened canvas")
        photo.shot("adjlayer-hidden")

        // 4. New Layer above, a brush stroke; shown again, the adjustment leaves the stroke alone.
        photo.click("New Layer", in: .window)
        adjExpect("Undo New Layer", photo, "New Layer made no undo step")
        let layer1 = photo.app.staticTexts["Layer 1"]
        XCTAssert(layer1.waitForExistence(timeout: 5), "New Layer listed no Layer 1")
        XCTAssert(adjWaitUntil { layer1.frame.minY < curves.frame.minY }, "Layer 1 isn't above Curves 1")
        photo.element("suite.tools").buttons["Brush"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.7))
        adjExpect("Undo Paint", photo, "the brush stroke on Layer 1 didn't paint")
        let painted = adjSteadyCanvas(photo)
        photo.shot("adjlayer-painted")
        photo.click("Show Curves 1", in: .window)
        adjExpect("Undo Show Layer", photo, "Curves 1's eye didn't show it again")
        XCTAssert(adjWaitUntil { Self.adjShare(painted, self.adjCanvas(photo)) > 0.05 }, "showing Curves 1 didn't adjust the canvas")
        let shown = adjSteadyCanvas(photo)
        let strokeBefore = Self.adjPixel(painted) ?? [], strokeAfter = Self.adjPixel(shown) ?? []
        XCTAssert(
            strokeBefore.count == 3 && strokeAfter.count == 3
                && zip(strokeBefore, strokeAfter).allSatisfy { abs($0 - $1) <= 6 },
            "Curves 1 below Layer 1 adjusted its stroke (\(strokeBefore) became \(strokeAfter))")
        photo.shot("adjlayer-stroke-unadjusted")

        // 5. Curves 1 selected, Send Backward once: the bottom row, nothing below to adjust.
        photo.app.typeKey("[", modifierFlags: [.command, .option])
        adjChoose("Send Backward", from: "Layer", photo)
        adjExpect("Undo Reorder Layers", photo, "Send Backward made no Reorder Layers step")
        XCTAssert(adjWaitUntil { curves.frame.minY > background.frame.minY }, "Curves 1 isn't the bottom row")
        let nothing = photo.app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", "Nothing below to adjust.", "Nothing below to adjust.")).firstMatch
        XCTAssert(nothing.waitForExistence(timeout: 5), "Curves 1's row doesn't read Nothing below to adjust.")
        let bar = photo.app.menuBars.firstMatch.menuBarItems["Layer"]
        bar.click()
        let send = bar.menuItems["Send Backward"]
        XCTAssert(send.waitForExistence(timeout: 3), "the Layer menu has no Send Backward")
        XCTAssertFalse(send.isEnabled, "Send Backward is enabled on the bottom layer")
        photo.shot("adjlayer-bottom-menu", screen: true)
        photo.press(.escape)
        photo.shot("adjlayer-bottom")

        // 6. Opacity 0: the canvas as it was; Command-Z undoes it.
        let bottom = adjSteadyCanvas(photo)
        adjTypeValue("0", into: "Opacity", photo)
        adjExpect("Undo Layer Opacity", photo, "typing 0 into Opacity made no Layer Opacity step")
        XCTAssert(photo.app.staticTexts["Normal 0%"].waitForExistence(timeout: 5), "Curves 1 doesn't read Normal 0%")
        adjExpectCanvas(like: bottom, photo, "opacity 0 changed the canvas")
        photo.shot("adjlayer-opacity-0")
        photo.app.typeKey("z", modifierFlags: .command)
        adjExpect("Redo Layer Opacity", photo, "Command-Z didn't undo the opacity")
        XCTAssert(photo.app.staticTexts["Normal 0%"].waitForNonExistence(timeout: 5), "Command-Z left Curves 1 at 0%")
        photo.shot("adjlayer-opacity-undone")

        // 7. Background selected: the Adjust tab adjusts the whole image.
        photo.app.typeKey("]", modifierFlags: [.command, .option])
        adjustTab.click()
        adjExpectHeader("Image", "Adjusts the whole image", photo)
        photo.shot("adjlayer-image")

        // 8. Error: the brush on the adjustment layer says why and changes nothing.
        photo.app.typeKey("[", modifierFlags: [.command, .option])
        adjExpectHeader("Curves 1", "Adjusts the layers below", photo)
        let before = adjSteadyCanvas(photo)
        photo.element("suite.tools").buttons["Brush"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.3, dy: 0.6), to: CGVector(dx: 0.7, dy: 0.4))
        let message = photo.element("photo.status.message")
        XCTAssert(message.waitForExistence(timeout: 5), "a brush drag on Curves 1 showed no status message")
        XCTAssert(
            message.label.contains("Select an image layer in the Layers tab to paint on."),
            "the status line reads \(message.label), not the paint refusal")
        XCTAssert(photo.app.buttons["Undo Reorder Layers"].exists, "the refused brush drag made an undo step")
        adjExpectCanvas(like: before, photo, "the refused brush drag changed the canvas")
        photo.shot("adjlayer-paint-refused")
    }

    // MARK: Adjustment layer steps

    /// Layer > New Adjustment Layer > `kind`, through the submenu.
    @MainActor func adjChooseAdjustmentLayer(_ kind: String, _ photo: Journey) {
        let bar = photo.app.menuBars.firstMatch.menuBarItems["Layer"]
        XCTAssert(bar.waitForExistence(timeout: 5), "no Layer menu")
        bar.click()
        let submenu = bar.menuItems["New Adjustment Layer"]
        XCTAssert(submenu.waitForExistence(timeout: 5), "the Layer menu has no New Adjustment Layer")
        submenu.hover()
        let item = submenu.menuItems[kind]
        XCTAssert(item.waitForExistence(timeout: 5), "New Adjustment Layer offers no \(kind)")
        XCTAssert(item.isEnabled, "New Adjustment Layer > \(kind) is disabled")
        item.click()
    }

    /// The Adjust tab's header (`photo.adjust.header`) reads `title` over `info`.
    @MainActor private func adjExpectHeader(_ title: String, _ info: String, _ photo: Journey) {
        let header = photo.element("photo.adjust.header")
        XCTAssert(header.waitForExistence(timeout: 5), "the Adjust tab has no header (photo.adjust.header)")
        var read = ""
        let reads = adjWaitUntil {
            let parts = [header] + header.descendants(matching: .any).allElementsBoundByIndex
            read = parts.flatMap { [$0.label, ($0.value as? String) ?? ""] }.filter { !$0.isEmpty }.joined(separator: " | ")
            return read.contains(title) && read.contains(info)
        }
        XCTAssert(reads, "the Adjust header reads \(read), not \(title) over \(info)")
    }

    /// Waits for the button titled `title`, such as the top bar's "Undo Curves".
    @MainActor func adjExpect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    /// Picks the enabled `item` from the menu bar's `menu`.
    @MainActor private func adjChoose(_ item: String, from menu: String, _ photo: Journey) {
        let bar = photo.app.menuBars.firstMatch.menuBarItems[menu]
        bar.click()
        let entry = bar.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 5), "the \(menu) menu has no \(item)")
        XCTAssert(entry.isEnabled, "\(menu) > \(item) is disabled")
        entry.click()
    }

    /// Types `value` into the panel number labelled `label`: click it, clear without Command-A, type, Return.
    @MainActor private func adjTypeValue(_ value: String, into label: String, _ photo: Journey) {
        let panel = photo.element("suite.inspector")
        let matches = panel.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
        XCTAssert(matches.firstMatch.waitForExistence(timeout: 5), "no \(label) in the panel")
        matches.element(boundBy: matches.count - 1).click()
        let named = panel.textFields[label]
        let field = named.waitForExistence(timeout: 3) ? named : panel.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(label)'s number opened no field to type in")
        field.click()
        photo.app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<16 { photo.app.typeKey(.delete, modifierFlags: []) }
        photo.app.typeText(value)
        photo.app.typeKey(.return, modifierFlags: [])
    }

    // MARK: Adjustment layer canvas

    @MainActor private func adjCanvas(_ photo: Journey) -> Data {
        photo.element("suite.canvas").screenshot().pngRepresentation
    }

    /// The canvas once two shots half a second apart match, or the last after five seconds.
    @MainActor private func adjSteadyCanvas(_ photo: Journey) -> Data {
        var last = adjCanvas(photo)
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.5)
            let next = adjCanvas(photo)
            if next == last { break }
            last = next
        }
        return last
    }

    /// The canvas comes to match `reference` (at most 0.5% of pixels off by more than 6 of 255).
    @MainActor private func adjExpectCanvas(like reference: Data, _ photo: Journey, _ message: String) {
        var share = 1.0
        let same = adjWaitUntil {
            share = Self.adjShare(reference, self.adjCanvas(photo))
            return share <= 0.005
        }
        XCTAssert(same, "\(message): \(share * 100)% of its pixels differ")
    }

    /// The share of pixels whose color differs by more than 6 of 255; 1 when the shots can't be compared.
    static func adjShare(_ first: Data, _ second: Data) -> Double {
        guard let a = adjRGBA(first), let b = adjRGBA(second), a.width == b.width, a.height == b.height,
            a.bytes.count == b.bytes.count, a.width > 0, a.height > 0
        else { return 1 }
        var differing = 0
        for pixel in 0..<(a.width * a.height) {
            let base = pixel * 4
            if (base..<(base + 3)).contains(where: { abs(Int(a.bytes[$0]) - Int(b.bytes[$0])) > 6 }) { differing += 1 }
        }
        return Double(differing) / Double(a.width * a.height)
    }

    /// The RGB of the shot's middle pixel, where the journey's strokes cross; nil if it doesn't decode.
    static func adjPixel(_ png: Data) -> [Int]? {
        guard let image = adjRGBA(png), image.width > 0, image.height > 0 else { return nil }
        let base = ((image.height / 2) * image.width + image.width / 2) * 4
        guard base + 2 < image.bytes.count else { return nil }
        return (base..<(base + 3)).map { Int(image.bytes[$0]) }
    }

    /// A PNG decoded to 8-bit RGBA rows; nil if it doesn't decode.
    static func adjRGBA(_ png: Data) -> (width: Int, height: Int, bytes: [UInt8])? {
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
    @MainActor func adjWaitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<10 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return condition()
    }
}
