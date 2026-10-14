// FlareFilesTests.swift: opening and saving .flare files in FlareWorkspace (FlareFiles.swift): open through `load`,
// save data, the file name, the dirty flag and the alert text for each FormatError (docs/blueprints/flare.md, section
// 3.3). Also the model half of the open budgets, QB-L9 and QB-L12 (docs/review-rubric.md, section 6): showing the
// progress state is instant, and the main-thread part of an open stays under two refreshes for a large document.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import Testing

#if DEBUG
private let progressBudget = Duration.milliseconds(10)
private let mainThreadBudget = Duration.milliseconds(160)
#else
private let progressBudget = Duration.milliseconds(1)
private let mainThreadBudget = Duration.milliseconds(16)
#endif

private func opened(_ document: Document, named name: String = "Bounce.flare") throws -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    try workspace.open(FlareFormat.encode(document), named: name)
    return workspace
}

/// 300 layers of 6 tracks of 3 keys (5,400 keys) holding a 40-point path each: the `crowd` scale.
private let large: Document = {
    let tracks = ["x", "y", "rotation", "opacity", "scaleX", "scaleY"]
    let layers = (0..<300).map { i in
        let points = (0..<40).map { Point(x: Double($0), y: Double(($0 * 7 + i) % 50)) }
        let path = FlarePath(polyline: points, closed: false)
        return Layer(id: "layer-\(i)", name: "Layer \(i)", shapes: [FlareShape(points: [], closed: false, path: path)],
                     tracks: Dictionary(uniqueKeysWithValues: tracks.map { p in
                         (p, (0..<3).map { Keyframe(frame: $0 * 50, value: Double($0 + i)) })
                     }))
    }
    return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", durationFrames: 300, layers: layers)])
}()

struct FlareFilesTests {
    @Test func openShowsTheDocumentByName() throws {
        let workspace = try opened(FlareFixtures.bounce)
        #expect(workspace.document == FlareFixtures.bounce)
        #expect(workspace.selectedSceneID == FlareFixtures.bounce.scenes.first?.id)
        #expect(workspace.fileName == "Bounce.flare")
        #expect(workspace.title == "Bounce")
        #expect(workspace.isDirty == false)
        #expect(workspace.loadState == .idle)
        #expect(workspace.canUndo == false)
    }

    @Test func badDataThrowsAndKeepsTheDocument() throws {
        var workspace = try opened(FlareFixtures.bounce)
        workspace.addLayer()
        let before = workspace.document
        #expect(throws: FormatError.self) { try workspace.open(Data("not json".utf8), named: "Junk.flare") }
        #expect(workspace.document == before)
        #expect(workspace.fileName == "Bounce.flare")
        #expect(workspace.isDirty)
        #expect(workspace.canUndo)
        #expect(workspace.loadState == .failed("This file isn't a Flare animation."))
        workspace.dismissFileError()
        #expect(workspace.loadState == .idle)
    }

    @Test(arguments: [
        (FormatError.notAFlareFile, "This file isn't a Flare animation."),
        (.malformed("not a JSON object"), "This file isn't a Flare animation."),
        (.unsupportedVersion(2), "This file was made by a newer Flare (format 2). Update Flare to open it."),
        (.tooLarge("file is 70000000 bytes, limit 67108864"), "This file is larger than Flare can open (64 MB)."),
        (.invalid("layer ids repeat."), "This file is damaged: layer ids repeat."),
        (.invalid(""), "This file is damaged."),
    ])
    func eachFormatErrorHasSection33Text(error: FormatError, text: String) {
        #expect(error.message == text)
    }

    @Test func realBadFilesGiveTheirMessages() {
        let newer = Data(#"{"format": "flare", "version": 2, "document": {}}"#.utf8)
        let other = Data(#"{"format": "vector", "version": 1}"#.utf8)
        for (data, text) in [(newer, "This file was made by a newer Flare (format 2). Update Flare to open it."),
                             (other, "This file isn't a Flare animation.")] {
            var workspace = FlareWorkspace(services: .fake())
            #expect(throws: FormatError.self) { try workspace.open(data, named: "x.flare") }
            #expect(workspace.document == nil)
            #expect(workspace.loadState == .failed(text))
        }
    }

    @Test func saveThenOpenIsByteIdentical() throws {
        var first = try opened(FlareFixtures.bounce)
        let saved = first.saveData()
        let save = try #require(saved)
        let second = try opened(FlareFormat.decode(save.data))
        #expect(second.document == FlareFixtures.bounce)
        var copy = second
        let again = copy.saveData()
        #expect(again?.data == save.data)
    }

    @Test func editsMakeItDirtyAndSavingCleansIt() throws {
        var workspace = try opened(FlareFixtures.bounce)
        workspace.addLayer()
        #expect(workspace.isDirty)
        let saved = workspace.saveData()
        let save = try #require(saved)
        #expect(workspace.isDirty, "dirty until the write is done")
        workspace.didSave(save, named: "Bounce copy.flare")
        #expect(workspace.isDirty == false)
        #expect(workspace.title == "Bounce copy")
        workspace.undo()
        #expect(workspace.isDirty, "undo past the save is an unsaved change")
        workspace.redo()
        #expect(workspace.isDirty == false)
    }

    @Test func anEditDuringTheWriteStaysDirty() throws {
        var workspace = try opened(FlareFixtures.bounce)
        let saved = workspace.saveData()
        let save = try #require(saved)
        workspace.addLayer()
        workspace.didSave(save, named: "Bounce.flare")
        #expect(workspace.isDirty)
    }

    @Test func aFailedWriteKeepsTheChangesAndSaysWhy() throws {
        var workspace = try opened(FlareFixtures.bounce)
        workspace.addLayer()
        workspace.saveFailed("The disk is full.")
        #expect(workspace.saveError == "Flare couldn't save this animation: The disk is full.")
        #expect(workspace.isDirty)
        #expect(workspace.fileName == "Bounce.flare")
        workspace.dismissFileError()
        #expect(workspace.saveError == nil)
    }

    @Test func savingNothingSaysThereIsNothing() {
        var workspace = FlareWorkspace(services: .fake())
        let save = workspace.saveData()
        #expect(save == nil)
        #expect(workspace.saveError == "Flare couldn't save this animation: there's no animation open.")
    }

    @Test func aNewDocumentIsUntitledAndClean() throws {
        var workspace = try opened(FlareFixtures.bounce)
        workspace.newDocument()
        #expect(workspace.fileName == nil)
        #expect(workspace.title == "Untitled")
        #expect(workspace.isDirty == false)
    }

    @Test func progressShowsAtOnceAndOpenFinishesOffTheDecode() async throws {
        var workspace = try opened(FlareFixtures.bounce)
        let clock = ContinuousClock()
        let shown = clock.measure { workspace.beginOpen() }
        #expect(workspace.loadState == .loading)
        #expect(shown <= progressBudget, "QB-L9: progress \(shown), budget \(progressBudget)")
        let data = try FlareFormat.encode(large)
        let result = await Task.detached { FlareWorkspace.decodeFile(data) }.value
        var costs: [Duration] = []
        for _ in 0..<5 {
            var copy = workspace
            costs.append(clock.measure { copy.finishOpen(result, named: "Crowd.flare") })
            #expect(copy.document == large)
            #expect(copy.loadState == .idle)
        }
        let quietest = costs.min() ?? mainThreadBudget * 2
        print("FlareFiles finishOpen min \(quietest) budget \(mainThreadBudget)")
        #expect(quietest <= mainThreadBudget, "QB-L12: main-thread part of an open")
    }

    @Test func dirtyCheckOnALargeDocumentIsCheap() throws {
        var workspace = try opened(large, named: "Crowd.flare")
        workspace.selectLayer("layer-299")
        workspace.toggleLayerFlag("layer-299", .visible)
        let clock = ContinuousClock()
        var dirty = false
        let cost = clock.measure { for _ in 0..<10 { dirty = workspace.isDirty } }
        #expect(dirty)
        print("FlareFiles isDirty x10 \(cost) budget \(progressBudget)")
        #expect(cost <= progressBudget * 10, "the top bar reads isDirty on every draw")
    }
}
