// FlareFillHelpTests.swift (gradient-fill FG-2): the FILL switch's reason and its intent. The reason is the kernel's
// `fillHelp`: with no shape the paint's "no shape" text; with Ball selected it says fill editing isn't built while the
// catalog has no fill commands, the catalog calls the command unavailable, and a gesture changes nothing. `.inspector(.runFill(_))` is one stable identifier whatever it carries.
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareFillHelpTests {
    @Test func noShapeSaysSelectOne() {
        var w = FlareWorkspace(services: .built)
        w.load(FlareFixtures.bounce)
        #expect(w.fillHelp == FlareWorkspace.noShape)
    }

    @Test func aShapeSaysEditingIsNotBuiltUntilTheCommandsAre() {
        var w = FlareWorkspace(services: .built)
        w.load(FlareFixtures.bounce)
        w.selectLayer("ball")
        #expect(FlareWorkspace.catalog.spec("fill.type") == nil, "FG-5 adds the fill commands and retires this reason")
        #expect(w.fillHelp == FlareWorkspace.fillNotBuilt)
        #expect(FlareWorkspace.catalog.availability("fill.type", on: w).why != nil)
        let before = w.document
        w.runFill(.type(.radial))
        #expect(w.document == before, "A gesture the help disables changes nothing")
    }

    @Test func runFillIsOneIntentWithATitle() {
        let linear = FlareIntent.inspector(.runFill(.type(.linear)))
        let angle = FlareIntent.inspector(.runFill(.angle(45, drag: nil)))
        #expect(linear.identifier == "flare.inspector.runFill")
        #expect(angle.identifier == linear.identifier)
        #expect(linear.title == "Edit Fill")
        #expect(FlareIntent.examples.contains(.inspector(.runFill(.type(.solid)))))
    }
}
