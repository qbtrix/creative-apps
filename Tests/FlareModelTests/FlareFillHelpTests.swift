// FlareFillHelpTests.swift (gradient-fill FG-2): the FILL switch's reason and its intent. The reason is the kernel's
// `fillHelp`: with no shape the paint's "no shape" text; with Ball selected none, the catalog calls the command
// available, and a gesture changes the document (FG-5). `.inspector(.runFill(_))` is one stable identifier whatever it carries.
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareFillHelpTests {
    @Test func noShapeSaysSelectOne() {
        var w = FlareWorkspace(services: .built)
        w.load(FlareFixtures.bounce)
        #expect(w.fillHelp == FlareWorkspace.noShape)
    }

    @Test func aShapeCanEditItsFill() {
        var w = FlareWorkspace(services: .built)
        w.load(FlareFixtures.bounce)
        w.selectLayer("ball")
        #expect(FlareWorkspace.catalog.spec("fill.type") != nil)
        #expect(w.fillHelp == nil)
        #expect(FlareWorkspace.catalog.availability("fill.type", on: w).why == nil)
        let before = w.document
        w.runFill(.type(.radial))
        #expect(w.document != before && w.paintError == nil && w.undoName == "Fill Type")
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
