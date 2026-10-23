// HaloFilesKernelTests.swift (AD-h1): Halo's file state on the kernel session.
// A save ends the open scrub, so undo after a later scrub lands on the saved
// document; a newer envelope is refused with its version, never opened.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteKernel
import Testing

@Test func aSaveEndsTheScrubSoUndoLandsOnTheSavedDocument() {
    var project = editProject()
    func scrub(_ x: Double) {
        project.edit("Change Position X", control: "halo.test", coalesceKey: "x") { doc in
            doc.compositions[0].layers[0].tracks["x"] = [HaloKeyframe(frame: 0, value: x)]
        }
    }
    scrub(10)
    project.didSave(name: "Spot", path: "/t/Spot.halo")
    let saved = project.document, steps = project.history.undo.count
    scrub(20)
    #expect(project.history.undo.count == steps + 1)
    #expect(project.saveStatus == "Edited")
    project.undo()
    #expect(project.document == saved)
}

@Test func aNewerEnvelopeIsRefusedWithItsVersion() {
    let newer = Data(#"{"format":"halo","project":{"compositions":[]},"version":3}"#.utf8)
    #expect(throws: HaloFileError.newerVersion(3)) { try FakeProjectFiles().decode(newer) }
    #expect(throws: HaloFileError.notAHaloFile) { try FakeProjectFiles().decode(Data(#"{"format":"halo"}"#.utf8)) }
}

@Test func theSessionIsDirtyOnlyWhileTheWorkIsNotOnDisk() {
    var project = editProject()
    #expect(project.session.isDirty && project.session.status == .unsaved)
    project.didSave(name: "Spot", path: "/t/Spot.halo")
    #expect(!project.session.isDirty && project.session.status == .saved)
    project.newLayer(.solid)
    project.didFailSave("The disk is full.")
    #expect(project.session.isDirty && project.session.status == .failed("The disk is full."))
}
