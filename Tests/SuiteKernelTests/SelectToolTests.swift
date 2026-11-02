// SelectToolTests.swift: SuiteKernel's shared Select tool rule (#6012): click replaces, Shift-click toggles, an
// empty click clears (Shift keeps), a box replaces or with Shift joins, and `release` routes a press to one of them.
import SuiteKernel
import Testing

struct SelectToolTests {
    /// Three 10 x 10 squares on a row at x 0, 20, 40.
    struct Board: SelectTarget {
        var selectPicks = Selection<String>()
        let boxes = [("a", 0.0), ("b", 20.0), ("c", 40.0)]
        func layerHit(at p: Point) -> String? { boxes.last { p.x >= $0.1 && p.x <= $0.1 + 10 && p.y >= 0 && p.y <= 10 }?.0 }
        func layerHits(in r: Rect) -> [String] {
            boxes.filter { r.maxX >= $0.1 && r.minX <= $0.1 + 10 && r.maxY >= 0 && r.minY <= 10 }.map(\.0)
        }
        mutating func setSelectPicks(_ picks: Selection<String>) { selectPicks = picks }
    }

    @Test func clickReplacesShiftTogglesEmptyClears() {
        let one = SelectTool.click(Selection(["a"]), hit: "b", extending: false)
        #expect(one.ordered == ["b"])
        let two = SelectTool.click(one, hit: "c", extending: true)
        #expect(two.ordered == ["b", "c"])
        #expect(SelectTool.click(two, hit: "b", extending: true).ordered == ["c"])
        #expect(SelectTool.click(two, hit: nil, extending: false).ordered.isEmpty)
        #expect(SelectTool.click(two, hit: nil, extending: true).ordered == ["b", "c"])
    }

    @Test func boxReplacesOrWithShiftJoins() {
        let start = Selection(["c"])
        #expect(SelectTool.box(start, found: ["a", "b"], extending: false).ordered == ["a", "b"])
        #expect(SelectTool.box(start, found: ["a", "c"], extending: true).ordered == ["c", "a"])
        #expect(SelectTool.box(start, found: [], extending: false).ordered.isEmpty)
    }

    @Test func releaseRoutesClickOrBox() {
        var board = Board()
        #expect(SelectTool.release(&board, from: Point(x: 25, y: 5), to: Point(x: 25.5, y: 5), extending: false))
        #expect(board.selectPicks.ordered == ["b"])
        #expect(SelectTool.release(&board, from: Point(x: -5, y: -5), to: Point(x: 22, y: 3), extending: true))
        #expect(board.selectPicks.ordered == ["b", "a"])
        #expect(SelectTool.release(&board, from: Point(x: 25, y: 5), to: Point(x: 25, y: 5), extending: false))
        #expect(board.selectPicks.ordered == ["b"])
        #expect(SelectTool.release(&board, from: Point(x: 100, y: 100), to: Point(x: 100, y: 100), extending: false))
        #expect(board.selectPicks.ordered.isEmpty)
        #expect(!SelectTool.release(&board, from: Point(x: 100, y: 100), to: Point(x: 100, y: 100), extending: false))
    }
}
