// DesignJourneyTests.swift: Design driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Design's features land, and replace the skipped
// test with the real journey when its issue is built. Design's window is an
// editor shell, so it is found by its tool rail and panel, and the buttons by
// the whole window.
import Foundation
import XCTest

final class DesignJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Design", self).expectEditorShell()
    }

    @MainActor func testNewFileAndEveryTool() {
        let design = Journey("Design", self)
        design.click("New File", in: .window, step: "new-file")
        design.clickEachTool()
    }

    @MainActor func testEveryMenuOpens() {
        let design = Journey("Design", self)
        design.app.typeKey("n", modifierFlags: .command)
        design.openEachMenu()
    }

    /// PROBE (not part of the slice): open a file, draw, undo name, save to the -DesignSaveTo path, close the
    /// window and New File with no window focused.
    @MainActor func testProbeOpenDrawSaveAndNewFileWithNoWindow() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "design-probe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let desktop = #"{"children":[],"fill":{"blue":255,"green":255,"red":255},"frame":{"height":1024,"width":1440,"x":0,"y":0},"id":"node-1","isHidden":false,"isLocked":false,"kind":"frame","name":"Desktop","text":""}"#
        let json = #"{"pages":[{"frameHeight":1024,"frameWidth":1440,"id":"page-1","name":"Page 1","nodes":["# + desktop + #"]},{"frameHeight":800,"frameWidth":600,"id":"page-2","name":"Mobile","nodes":[]}],"version":1}"#
        let file = folder.appending(path: "journey.design")
        let saved = folder.appending(path: "saved.design")
        try Data(json.utf8).write(to: file)
        let design = Journey("Design", self, arguments: ["-DesignOpenFile", file.path, "-DesignSaveTo", saved.path])
        XCTAssert(design.app.windows["journey.design"].waitForExistence(timeout: 30), "journey.design didn't open")
        design.shot("probe-opened")

        design.element("suite.tools").buttons["Rectangle"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.3, dy: 0.3), to: CGVector(dx: 0.6, dy: 0.6), step: "probe-drawn")
        XCTAssert(design.app.buttons["Undo Add Rectangle"].waitForExistence(timeout: 5), "no Undo Add Rectangle")
        design.click("Save", in: .window, step: "probe-saved")
        var text = ""
        for _ in 0..<20 {
            if let data = try? Data(contentsOf: saved) { text = String(decoding: data, as: UTF8.self); break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssert(text.contains("\"kind\":\"rectangle\"") && text.contains("\"version\":1"), "Save wrote: \(text)")
        XCTAssert(design.app.windows["saved.design"].waitForExistence(timeout: 5), "title didn't become saved.design")

        design.app.typeKey("w", modifierFlags: .command)
        for _ in 0..<20 where design.app.windows.count > 0 { Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertEqual(design.app.windows.count, 0, "the window didn't close")
        design.app.typeKey("n", modifierFlags: .command)
        XCTAssert(design.app.windows["Untitled"].waitForExistence(timeout: 15), "New File with no window opened none")
        XCTAssert(design.element("suite.tools").waitForExistence(timeout: 5), "no tool rail in the new window")
        design.shot("probe-new-window")
    }

    @MainActor func testDrawShapesAddTextAndSave() throws {
        throw XCTSkip("journey arrives with #198 (draw), #199 (text) and #202 (save)")
    }
}
