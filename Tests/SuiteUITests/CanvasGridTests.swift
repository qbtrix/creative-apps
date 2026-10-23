// CanvasGridTests.swift: CanvasGrid's lines (CM-8, #530): a grid of n cells
// draws n - 1 lines each way at the zoom, and 0 or fewer cells, or a zoom
// that isn't a finite positive number, draw none.
// macOS only.
import CoreGraphics
import SuiteUI
import Testing

@Test func threeCellsDrawTwoLinesEachWay() {
    let lines = CanvasGrid.lines(rect: CGRect(x: 30, y: 60, width: 300, height: 150), cells: 3, zoom: 2)
    #expect(lines.vertical == [260, 460])
    #expect(lines.horizontal == [220, 320])
}

@Test func zeroCellsDrawNoGrid() {
    let rect = CGRect(x: 0, y: 0, width: 300, height: 150)
    for cells in [0, -1, Int.min] {
        let lines = CanvasGrid.lines(rect: rect, cells: cells, zoom: 1)
        #expect(lines.vertical.isEmpty && lines.horizontal.isEmpty)
    }
}

@Test func oneCellDrawsNoLines() {
    let lines = CanvasGrid.lines(rect: CGRect(x: 0, y: 0, width: 300, height: 150), cells: 1, zoom: 1)
    #expect(lines.vertical.isEmpty && lines.horizontal.isEmpty)
}

@Test func aNonFiniteRectOrZoomDrawsNoGrid() {
    let rect = CGRect(x: 0, y: 0, width: 300, height: 150)
    #expect(CanvasGrid.lines(rect: rect, cells: 3, zoom: .nan).vertical.isEmpty)
    let endless = CGRect(x: 0, y: 0, width: Double.infinity, height: 1)
    #expect(CanvasGrid.lines(rect: endless, cells: 3, zoom: 1).horizontal.isEmpty)
}

@Test func nCellsDrawNMinusOneLines() {
    for cells in 1...12 {
        let lines = CanvasGrid.lines(rect: CGRect(x: 0, y: 0, width: 90, height: 90), cells: cells, zoom: 1)
        #expect(lines.vertical.count == cells - 1 && lines.horizontal.count == cells - 1)
    }
}

@Test func aZoomThatIsNotPositiveDrawsNoGrid() {
    let rect = CGRect(x: 0, y: 0, width: 300, height: 150)
    for zoom: Double in [0, -2] {
        let lines = CanvasGrid.lines(rect: rect, cells: 3, zoom: zoom)
        #expect(lines.vertical.isEmpty && lines.horizontal.isEmpty)
    }
}
