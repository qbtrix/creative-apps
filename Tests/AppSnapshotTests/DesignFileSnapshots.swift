// DesignFileSnapshots.swift: Design's window after a file is opened: a
// two-page sample built with the model API, written with fileData() and read
// back with open(), shown in the editor with its file name in the top bar and
// "Saved sample.design" on the status line. Writes design-opened-file-light.png
// and design-opened-file-dark.png; the editor is dark in both on purpose.
// macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignFileSnapshots {
    @Test func openedFile() throws {
        var sample = DesignWorkspace()
        sample.newFile()
        let box = DesignRect(x: 80, y: 80, width: 360, height: 220)
        let group = try sample.addNode(.group, frame: box, in: "node-1")
        try sample.addNode(.rectangle, frame: box, in: group)
        try sample.addNode(.ellipse, frame: DesignRect(x: 200, y: 120, width: 160, height: 160), in: group)
        sample.selectTool(.text)
        sample.drag(from: DesignPoint(x: 520, y: 120), to: DesignPoint(x: 520, y: 120))
        sample.endDrag()
        sample.setTextDraft("Welcome")
        sample.commitTextEdit()
        sample.addPage()
        try sample.renamePage("page-2", to: "Mobile")
        let data = try sample.fileData()

        var opened = DesignWorkspace()
        try opened.open(data)
        #expect(opened.pages == sample.pages && opened.pages.count == 2 && !opened.canUndo)
        #expect(opened.selectedPageID == "page-1" && opened.pages[0].nodes[0].children.count == 2)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignEditor(model: opened, documentName: "sample.design", note: "Saved sample.design", zoom: 0.5),
                name: "design-opened-file-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
