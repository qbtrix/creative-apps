// DesignLoupeTests.swift (eyedropper DY-3): the loupe the Eyedropper shows at the pointer (DesignLoupe). Only
// with the Eyedropper on an open page and the pointer over the artboard; it sits at the pointer, reads the
// colour `sampledColor` reads there (nil until DY-5's bodies), and Option turns the pick onto the stroke. A pick
// goes to `applySample` at the same point, and its refusal comes back as a DesignRefusal. Linux and macOS.
import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignLoupeTests {
    static func eyedropper() -> DesignWorkspace {
        var w = openDesign()
        w.selectTool(.eyedropper)
        return w
    }

    @Test func theLoupeFollowsThePointer() {
        let w = Self.eyedropper()
        #expect(w.loupe(at: pt(120, 140), modifiers: [], size: .point)?.point == pt(120, 140))
        #expect(w.loupe(at: pt(400, 30), modifiers: [], size: .point)?.point == pt(400, 30))
        #expect(w.loupe(at: nil, modifiers: [], size: .point) == nil, "the pointer left the artboard")
    }

    @Test func onlyTheEyedropperShowsTheLoupe() {
        var w = openDesign()
        #expect(w.loupe(at: pt(120, 140), modifiers: [], size: .point) == nil, "the Move tool")
        w.selectTool(.rectangle)
        #expect(w.loupe(at: pt(120, 140), modifiers: [], size: .point) == nil)
        var closed = DesignWorkspace()
        closed.selectTool(.eyedropper)
        #expect(closed.loupe(at: pt(120, 140), modifiers: [], size: .point) == nil, "no design open")
    }

    @Test func optionTurnsThePickOntoTheStroke() {
        let w = Self.eyedropper()
        #expect(w.loupe(at: pt(120, 140), modifiers: [], size: .point)?.toStroke == false)
        #expect(w.loupe(at: pt(120, 140), modifiers: .option, size: .point)?.toStroke == true)
        #expect(w.loupe(at: pt(120, 140), modifiers: [.option, .shift], size: .point)?.toStroke == true)
    }

    @Test func theLoupeReadsTheSampledColour() {
        let w = Self.eyedropper()
        for size in SampleSize.allCases {
            let read = w.sampledColor(at: Point(x: 120, y: 140), size: size)
            let shown = w.loupe(at: pt(120, 140), modifiers: [], size: size)?.color
            let hex = shown.map {
                SampleRules.hex(FillColor(r: Double($0.red) / 255, g: Double($0.green) / 255, b: Double($0.blue) / 255, a: 1))
            }
            #expect(hex == read.map(SampleRules.hex))
        }
    }

    @Test func aPickGoesToTheAdapter() {
        var w = Self.eyedropper()
        let before = w
        do {
            try w.pick(at: pt(120, 140), toStroke: false)
        } catch {
            // DY-1's stub refuses, changing nothing, until DY-5's apply.
            #expect(error == .notBuilt("Picking a color"))
            #expect(w.selectedPage == before.selectedPage)
        }
    }
}
