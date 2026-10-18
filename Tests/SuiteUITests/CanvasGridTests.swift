// CanvasGridTests.swift: CanvasGrid's line math (CM-8, #530). n cells draw
// n - 1 interior lines each way at the zoom, none at the rect's edges, and 0
// or fewer cells draw none. macOS only.
import CoreGraphics
import SuiteUI
import Testing

@Test func threeCellsDrawTwoLinesEachWay() {
    let lines = CanvasGrid.lines(in: CGRect(x: 0, y: 0, width: 300, height: 150), cells: 3, zoom: 1)
    #expect(lines.vertical == [100, 200])
    #expect(lines.horizontal == [50, 100])
}

@Test func nCellsDrawNMinusOneLines() {
    for cells in 1...12 {
        let lines = CanvasGrid.lines(in: CGRect(x: 0, y: 0, width: 90, height: 90), cells: cells, zoom: 1)
        #expect(lines.vertical.count == cells - 1)
        #expect(lines.horizontal.count == cells - 1)
    }
}

@Test func zeroOrNegativeCellsDrawNone() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    #expect(CanvasGrid.lines(in: rect, cells: 0, zoom: 1) == .empty)
    #expect(CanvasGrid.lines(in: rect, cells: -4, zoom: 1) == .empty)
}

@Test func linesSitInsideTheRectAtTheZoom() {
    let lines = CanvasGrid.lines(in: CGRect(x: 10, y: 20, width: 40, height: 80), cells: 4, zoom: 2)
    #expect(lines.vertical == [40, 60, 80])
    #expect(lines.horizontal == [80, 120, 160])
}

@Test func aZoomThatIsNotPositiveDrawsNone() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    #expect(CanvasGrid.lines(in: rect, cells: 3, zoom: 0) == .empty)
    #expect(CanvasGrid.lines(in: rect, cells: 3, zoom: .nan) == .empty)
}
