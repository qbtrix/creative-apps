// DesignLoupeTests.swift (eyedropper DY-3): the loupe the Eyedropper shows at the pointer (DesignLoupe). Only
// with the Eyedropper on an open page and the pointer at a finite point; it sits at the pointer, reads the
// colour `sampledColor` reads there in the Model's `sampleSize` square, and picks onto
// the fill or, with the Stroke option or Option held (each inverting the other), the stroke. A pick goes to
// `applySample` at the same point, and its refusal comes back as a DesignRefusal. Linux and macOS.
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
        #expect(w.loupe(at: pt(120, 140), modifiers: [])?.point == pt(120, 140))
        #expect(w.loupe(at: pt(400, 30), modifiers: [])?.point == pt(400, 30))
        #expect(w.loupe(at: nil, modifiers: []) == nil, "the pointer left the artboard")
    }

    /// #3992: a NaN or infinite pointer never shows a loupe, so a click can't pass it to `applySample`.
    @Test func aNonFinitePointerShowsNoLoupe() {
        let w = Self.eyedropper()
        #expect(w.loupe(at: DesignPoint(x: .nan, y: 140), modifiers: []) == nil)
        #expect(w.loupe(at: DesignPoint(x: .infinity, y: 0), modifiers: []) == nil)
        #expect(w.loupe(at: DesignPoint(x: 0, y: -.infinity), modifiers: .option) == nil)
    }

    @Test func onlyTheEyedropperShowsTheLoupe() {
        var w = openDesign()
        #expect(w.loupe(at: pt(120, 140), modifiers: []) == nil, "the Move tool")
        w.selectTool(.rectangle)
        #expect(w.loupe(at: pt(120, 140), modifiers: []) == nil)
        var closed = DesignWorkspace()
        closed.selectTool(.eyedropper)
        #expect(closed.loupe(at: pt(120, 140), modifiers: []) == nil, "no design open")
    }

    @Test func optionTurnsThePickOntoTheStroke() {
        let w = Self.eyedropper()
        #expect(w.sampleToStroke == false, "a plain click picks the fill")
        #expect(w.loupe(at: pt(120, 140), modifiers: [])?.toStroke == false)
        #expect(w.loupe(at: pt(120, 140), modifiers: .option)?.toStroke == true)
        #expect(w.loupe(at: pt(120, 140), modifiers: [.option, .shift])?.toStroke == true)
    }

    /// #3993: the Stroke option makes a plain click pick the stroke, with no key held; Option then picks the fill.
    @Test func theStrokeOptionPicksTheStrokeWithoutAKey() {
        var w = Self.eyedropper()
        w.setSampleTarget(toStroke: true)
        #expect(w.sampleToStroke)
        #expect(w.loupe(at: pt(120, 140), modifiers: [])?.toStroke == true)
        #expect(w.loupe(at: pt(120, 140), modifiers: .option)?.toStroke == false)
        w.setSampleTarget(toStroke: false)
        #expect(w.loupe(at: pt(120, 140), modifiers: [])?.toStroke == false)
    }

    /// #3989: the sample size lives in the Model, and the loupe reads the square it names.
    @Test func theSampleSizeIsTheModels() {
        var w = Self.eyedropper()
        #expect(w.sampleSize == .point)
        w.setSampleSize(.fiveByFive)
        #expect(w.sampleSize == .fiveByFive)
        w.setSampleSize(.threeByThree)
        #expect(w.sampleSize == .threeByThree)
    }

    @Test func theLoupeReadsTheSampledColour() {
        var w = Self.eyedropper()
        for size in SampleSize.allCases {
            w.setSampleSize(size)
            let read = w.sampledColor(at: Point(x: 120, y: 140), size: size)
            let shown = w.loupe(at: pt(120, 140), modifiers: [])?.color
            let hex = shown.map {
                SampleRules.hex(FillColor(r: Double($0.red) / 255, g: Double($0.green) / 255, b: Double($0.blue) / 255, a: 1))
            }
            #expect(hex == read.map(SampleRules.hex))
        }
    }

    @Test func aPickGoesToTheAdapter() {
        var w = Self.eyedropper()
        let before = w
        // DY-5's apply: with nothing selected the pick refuses, as a DesignRefusal, and changes nothing.
        #expect(throws: DesignRefusal.nothingSelected) { try w.pick(at: pt(120, 140), toStroke: false) }
        #expect(w == before)
    }
}
