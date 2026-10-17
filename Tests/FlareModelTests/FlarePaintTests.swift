// FlarePaintTests.swift: inspector-timeline IT-2 on `.built`. A fill set on Ball is one "Undo Set Fill" over every
// shape; a bad hex refuses with a reason and changes nothing; a width set, a cap and a join are one entry each, so one
// undo restores only the last; a gradient fill reads as one and refuses a hex set; a successful set clears the error.
import FlareCore
@testable import FlareModel
import Testing

private let red = Fill.solid(FlareColor(r: 1, g: 59.0 / 255, b: 48.0 / 255))   // FF3B30

/// `document` on `.built` with `layerID` selected in the layers panel.
private func built(_ layerID: String?, in document: Document = FlareFixtures.bounce) -> FlareWorkspace {
    var w = FlareWorkspace(services: .built)
    w.load(document)
    if let layerID { w.selectLayer(layerID) }
    return w
}

private func shapes(_ layerID: String, in w: FlareWorkspace) -> [FlareShape] {
    w.document?.layers(of: .scene("scene-1"))?.first { $0.id == layerID }?.shapes ?? []
}

@Test func paintIsNilWithNothingSelectedAndReadsBallsFill() {
    #expect(built(nil).paint == nil)
    let w = built("ball")
    guard case .solid(let color)? = shapes("ball", in: w).first?.fill else { return #expect(Bool(false)) }
    #expect(w.paint?.fillHex == String(NewDocumentSpec.hex(color).dropFirst()))
    #expect(w.paint?.fillIsGradient == false)
}

@Test func setFillOnBallIsOneEntryAndEveryShapeTakesIt() throws {
    var w = built("ball")
    let before = w.document
    #expect(!shapes("ball", in: w).isEmpty)
    w.setFill(hex: "FF3B30")
    #expect(shapes("ball", in: w).allSatisfy { $0.fill == red })
    #expect(w.paint?.fillHex == "FF3B30" && w.paintError == nil)
    #expect(w.undoActionName == "Undo Set Fill")
    w.undo()
    #expect(w.document == before && !w.canUndo)
}

@Test func aBadHexRefusesWithAReasonAndChangesNothing() {
    var w = built("ball")
    let before = w.document
    w.setFill(hex: "FF3B3")
    #expect(w.paintError == "Use 6 hex digits, like FF3B30.")
    #expect(w.document == before && !w.canUndo)
    w.setStrokeColor(hex: "GG0000")
    #expect(w.paintError == "Use 6 hex digits, like FF3B30.")
    #expect(w.document == before && !w.canUndo)
    w.setFill(hex: "#FF3B30")
    #expect(w.paintError == nil && w.canUndo)
}

@Test func aStrokeWidthSetIsOneEntryAndOneUndoRestoresIt() {
    var w = built("ball")
    let before = w.document
    w.setStrokeWidth(4)
    #expect(w.paint?.strokeWidth == 4)
    #expect(shapes("ball", in: w).allSatisfy { $0.stroke?.width == 4 })
    #expect(w.undoActionName == "Undo Set Stroke")
    w.undo()
    #expect(w.document == before && !w.canUndo)
}

@Test func capThenJoinAreTwoEntriesAndOneUndoRestoresOnlyTheJoin() {
    var w = built("ball")
    w.setStrokeWidth(4)
    w.setStrokeCap(.round)
    let capped = w.document
    w.setStrokeJoin(.round)
    #expect(w.paint?.cap == .round && w.paint?.join == .round)
    w.undo()
    #expect(w.document == capped)
    #expect(w.paint?.cap == .round && w.paint?.join == Stroke().join && w.paint?.strokeWidth == 4)
    w.undo()
    #expect(w.paint?.cap == Stroke().cap && w.paint?.strokeWidth == 4)
}

@Test func strokeColorSetsEveryShapeAndKeepsTheWidth() {
    var w = built("ball")
    w.setStrokeWidth(3)
    w.setStrokeColor(hex: "00FF00")
    #expect(w.paint?.strokeHex == "00FF00" && w.paint?.strokeWidth == 3)
    #expect(w.undoActionName == "Undo Set Stroke")
}

@Test func aGradientFillReadsAsOneAndRefusesAHexSet() {
    var doc = FlareFixtures.bounce
    let gradient = Fill.linear(stops: [GradientStop(offset: 0, color: .black), GradientStop(offset: 1, color: .white)],
                               start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))
    if let i = doc.scenes.first?.layers.firstIndex(where: { $0.id == "ball" }) {
        for s in doc.scenes[0].layers[i].shapes.indices { doc.scenes[0].layers[i].shapes[s].fill = gradient }
    }
    var w = built("ball", in: doc)
    #expect(w.paint?.fillIsGradient == true && w.paint?.fillHex == nil)
    w.setFill(hex: "FF3B30")
    #expect(w.paintError == "Gradients can't be edited yet.")
    #expect(w.document == doc && !w.canUndo)
}

@Test func mixedFillsReadNilAndASetPaintsBoth() {
    var w = built(nil)
    w.selectLayer("ball")
    w.setFill(hex: "FF3B30")
    w.setSelection([StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0)),
                    StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))])
    #expect(w.paint != nil && w.paint?.fillHex == nil)
    w.setFill(hex: "00FF00")
    #expect(w.paint?.fillHex == "00FF00")
    #expect(w.undoActionName == "Undo Set Fill")
}

@Test func paintSettersWithNothingSelectedSayWhy() {
    var w = built(nil)
    w.setStrokeWidth(2)
    #expect(w.paintError == "Select a shape first.")
    #expect(!w.canUndo)
}
