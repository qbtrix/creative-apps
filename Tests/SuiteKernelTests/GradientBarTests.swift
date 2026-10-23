// GradientBarTests.swift (gradient-fill, #4047): the gradient editor's stop bar as numbers. The handles sit inside the
// bar, half a handle in from each end, a press reads back the offset it was drawn at and clamps past the ends, and the
// colour row names the selected stop. Its mutations: Tests/mutations/SuiteKernel.GradientBar.json.
import SuiteKernel
import Testing

@Suite struct GradientBarTests {
    static let blue = FillColor(r: 0, g: 0, b: 1), red = FillColor(r: 1, g: 0, b: 0)
    static let three = Fill.linear(
        stops: [GradientStop(offset: 0, color: blue), GradientStop(offset: 0.5, color: red), GradientStop(offset: 1, color: .white)],
        start: Point(x: 0, y: 0), end: Point(x: 100, y: 0))
    /// A 212-wide bar with 12 pt handles: a 200-wide run from 6 to 206.
    static let width = 212.0, handle = 12.0

    @Test func endHandlesSitInsideTheBar() {
        #expect(GradientBar.x(of: 0, width: Self.width, handle: Self.handle) == 6)
        #expect(GradientBar.x(of: 0.5, width: Self.width, handle: Self.handle) == 106)
        #expect(GradientBar.x(of: 1, width: Self.width, handle: Self.handle) == 206)
    }

    @Test func aPressReadsBackItsOffset() {
        for offset in [0, 0.25, 0.6, 1] {
            let x = GradientBar.x(of: offset, width: Self.width, handle: Self.handle)
            #expect(GradientBar.offset(at: x, width: Self.width, handle: Self.handle) == offset)
        }
        #expect(GradientBar.offset(at: 0, width: Self.width, handle: Self.handle) == 0)
        #expect(GradientBar.offset(at: 500, width: Self.width, handle: Self.handle) == 1)
        #expect(GradientBar.offset(at: 5, width: 10, handle: Self.handle) == 0, "a bar no wider than a handle reads 0")
    }

    @Test func theColorRowNamesTheSelectedStop() {
        #expect(GradientBar.stopLabel(1, of: Self.three) == "Stop 2 · 50%")
        #expect(GradientBar.stopLabel(2, of: Self.three) == "Stop 3 · 100%")
        #expect(GradientBar.stopLabel(3, of: Self.three) == "Color")
        #expect(GradientBar.stopLabel(0, of: .solid(Self.red)) == "Color")
    }
}
