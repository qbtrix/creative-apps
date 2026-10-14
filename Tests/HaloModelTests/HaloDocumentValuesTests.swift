// HaloDocumentValuesTests.swift: the contract's document values and refusal
// types: the messages a refused edit or file shows, the drag preview's
// offsetting, the undo titles and a document's round trip through Codable.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import Testing

@Test func refusalMessagesReadAsTheWindowShowsThem() {
    #expect(HaloEditError.notANumber(.rotation).message == "Rotation needs a number.")
    #expect(HaloEditError.parentCycle("Ball").message == "Ball can't follow a layer that follows it.")
    #expect(HaloFileError.tooLarge.message.contains("64 MB"))
    #expect(HaloFileError.newerVersion(2).message.contains("format 2"))
    let refusal = HaloRefusal(control: "halo.timeline", message: HaloEditError.inPointAfterOut.message)
    #expect(refusal.message == "The in point must come before the out point.")
}

private func item(_ id: String) -> HaloDrawItem {
    HaloDrawItem(
        layerID: id, kind: .solid, bounds: HaloLayerRect(x: 0, y: 0, width: 10, height: 10),
        matrix: .translation(x: 5, y: 0), opacity: 1, color: HaloLayerKind.solid.defaultColor, blendMode: .normal)
}

@Test func offsettingMovesOnlyTheNamedLayer() {
    let list = HaloDrawList(width: 100, height: 100, frame: 0, items: [item("a"), item("b")])
    let moved = list.offsetting("b", by: HaloPoint(x: 100, y: -20))
    #expect(moved.items.first?.matrix == list.items.first?.matrix)
    #expect(moved.items.last?.matrix == .translation(x: 105, y: -20))
    #expect(list.offsetting("missing", by: HaloPoint(x: 1, y: 1)) == list)
}

@Test func undoTitlesNameTheNewestStep() {
    var history = HaloHistory()
    #expect(history.undoTitle == nil)
    #expect(history.redoTitle == nil)
    history.undo.append(HaloHistoryEntry(name: "New Composition", before: HaloDocumentState()))
    history.undo.append(HaloHistoryEntry(name: "New Layer", before: HaloDocumentState()))
    history.redo.append(HaloHistoryEntry(name: "Change Opacity", before: HaloDocumentState()))
    #expect(history.undoTitle == "Undo New Layer")
    #expect(history.redoTitle == "Redo Change Opacity")
}

@Test func aDocumentWithTwoCompositionsRoundTrips() throws {
    var project = HaloProject()
    project.newComposition()
    project.newLayer(.solid)
    project.newLayer(.text)
    project.newComposition(CompositionSettings(name: "Outro", width: 640, height: 480, framesPerSecond: 24, durationSeconds: 2))
    project.newLayer(.null)
    project.updateSelectedComposition { comp in
        comp.playheadFrame = 12
        comp.layers[0].tracks[HaloProperty.x.rawValue] = [HaloKeyframe(frame: 0, value: 1), HaloKeyframe(frame: 24, value: 9)]
    }
    let document = HaloDocumentState(
        compositions: project.compositions, selectedCompositionID: project.selectedCompositionID,
        selectedLayerID: project.selectedLayerID, nextCompositionNumber: 3, nextLayerNumber: 4)
    let data = try JSONEncoder().encode(document)
    let decoded = try JSONDecoder().decode(HaloDocumentState.self, from: data)
    #expect(decoded.compositions.count == 2)
    #expect(decoded == document)
}
