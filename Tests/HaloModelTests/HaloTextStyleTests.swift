// HaloTextStyleTests.swift (text-style TS-9, slice TS-halo): Halo's text layers take the kernel's text style
// through the catalog. An old project, whose text has no style, opens with the standard face and re-saves byte
// for byte; a face, italic, alignment, line height and tracking set through the catalog round-trip through the
// file; two lines measure two lines high, and a taller line height makes them taller. Every check runs through
// the catalog's ids and the file, so it reads the same before and after the bodies. Linux and macOS.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloTextStyleTests {
    let catalog = HaloProject.catalog

    /// The old-format composition file, whose "Name" layer is text with no style (`Fixtures/comp-30fps.halo`).
    static func oldFile() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/comp-30fps.halo"))
    }

    /// The old file open with its text layer selected, its words set to `words` when given.
    static func textProject(_ words: String? = nil) throws -> HaloProject {
        var state = try LiveProjectFiles().decode(oldFile())
        state.selectedCompositionID = "comp-1"
        state.selectedLayerID = "comp-1-layer-2"
        if let words, let l = state.compositions[0].layers.firstIndex(where: { $0.id == "comp-1-layer-2" }) {
            state.compositions[0].layers[l].text?.string = words
        }
        return HaloProject(services: .fake, document: state)
    }

    /// `text.read`'s result for the selected text layer.
    func read(_ project: inout HaloProject) throws -> JSONValue {
        try catalog.run("text.read", params: .object([:]), on: &project).result
    }

    /// One field of `text.read`'s result, by key path ("paragraph.lineHeight").
    static func field(_ style: JSONValue, _ path: String) -> JSONValue? {
        path.split(separator: ".").reduce(Optional(style)) { value, key in
            guard case .object(let fields)? = value else { return nil }
            return fields[String(key)] ?? nil
        }
    }

    /// The selected text layer's stored box height.
    static func height(_ project: HaloProject) -> Double? { project.selectedLayer?.text?.height }

    @Test func oldProjectsUnchanged() throws {
        let data = try Self.oldFile()
        let files = LiveProjectFiles()
        var project = try Self.textProject()
        let style = try read(&project)
        #expect(Self.field(style, "family") == .string("System"))
        #expect(Self.field(style, "weight") == .number(400))
        #expect(Self.field(style, "italic") == .bool(false))
        #expect(Self.field(style, "size") == .number(24), "the style's size isn't the layer's font size")
        #expect(Self.field(style, "paragraph.lineHeight") == .number(1.2))
        let saved = try files.encode(files.decode(data))
        #expect(saved == data, "an old project changed bytes on save")
        #expect(!String(decoding: saved, as: UTF8.self).contains("\"style\""), "a default style was written")
    }

    @Test func styleRoundTrips() throws {
        var project = try Self.textProject()
        let steps: [(String, JSONValue, String)] = [
            ("text.set-font", .object(["family": .string("Georgia"), "weight": .number(700)]), "Font"),
            ("text.set-italic", .object(["on": .bool(true)]), "Italic"),
            ("text.set-alignment", .object(["alignment": .string("center")]), "Alignment"),
            ("text.set-line-height", .object(["value": .number(1.5)]), "Line Height"),
            ("text.set-tracking", .object(["value": .number(50)]), "Letter Spacing"),
        ]
        for (id, params, step) in steps {
            #expect(try catalog.run(id, params: params, on: &project).undoStep == step, "\(id) isn't one step")
        }
        let style = try read(&project)
        #expect(Self.field(style, "family") == .string("Georgia"))
        #expect(Self.field(style, "weight") == .number(700))
        #expect(Self.field(style, "italic") == .bool(true))
        #expect(Self.field(style, "paragraph.alignment") == .string("center"))
        #expect(Self.field(style, "paragraph.tracking") == .number(50))
        let saved = try project.fileData()
        #expect(String(decoding: saved, as: UTF8.self).contains("\"style\""))
        var opened = HaloProject(services: .fake, document: try LiveProjectFiles().decode(saved))
        opened.selectLayer("comp-1-layer-2")
        #expect(try read(&opened) == style, "the style didn't survive the file")
        _ = try catalog.run("edit.undo", params: .object([:]), on: &project)
        #expect(Self.field(try read(&project), "paragraph.tracking") == .number(0))
    }

    @Test func linesAddHeight() throws {
        var one = try Self.textProject("Hello")
        var two = try Self.textProject("Hello\nHalo")
        // Centring changes no height, so it only remeasures each box at the file's 24 px and line height 1.2.
        let center: JSONValue = .object(["alignment": .string("center")])
        _ = try catalog.run("text.set-alignment", params: center, on: &one)
        _ = try catalog.run("text.set-alignment", params: center, on: &two)
        let single = try #require(Self.height(one)), double = try #require(Self.height(two))
        #expect(abs(single - 24) < 1e-9, "one line isn't one em high")
        #expect(abs(double - 24 * 2.2) < 1e-9, "two lines don't measure two lines high")
        _ = try catalog.run("text.set-line-height", params: .object(["value": .number(2)]), on: &two)
        #expect(abs((Self.height(two) ?? 0) - 24 * 3) < 1e-9, "a taller line height didn't add height")
    }

    @Test func needsATextLayer() throws {
        var project = HaloCommandCatalogTests.ballSelected()
        #expect(catalog.availability("text.set-font", on: project) == .unavailable("Select a text layer first."))
        #expect(throws: (any Error).self) {
            try catalog.run("text.set-tracking", params: .object(["value": .number(10)]), on: &project)
        }
        #expect(catalog.spec("text.set-size")?.title == "Change Text Size", "Halo's own size command was replaced")
    }
}
