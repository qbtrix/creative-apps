// FlareFilesKernelTests.swift: Flare's file state on the kernel's session (FlareFiles+Kernel.swift, AD-f1): the
// session is dirty only while the document isn't the saved one, a save ends the open scrub so undo lands on the
// saved document, autosave is the kernel's verdict with the 30 s delay, and the launch offer is the kernel's.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

private func scrubbing() -> (FlareWorkspace, Double) {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(FlareFixtures.bounce)
    workspace.selectLayer("shadow")
    let start = workspace.animatedProperties.first { $0.name == "x" }?.value ?? 0
    workspace.setProperty("x", to: start + 10, dragStart: start)
    return (workspace, start)
}

struct FlareFilesKernelTests {
    @Test func theSessionFollowsTheDocument() {
        var (workspace, _) = scrubbing()
        #expect(workspace.documentSession.isDirty)
        #expect(workspace.documentSession.currentToken != workspace.documentSession.savedToken)
        workspace.undo()
        #expect(workspace.documentSession.isDirty == false)
        #expect(FlareWorkspace(services: .fake()).documentSession.isDirty == false)
    }

    @Test func aSaveEndsTheScrubSoUndoLandsOnTheSave() throws {
        var (workspace, start) = scrubbing()
        let saved0 = workspace.saveData()
        let save = try #require(saved0)
        workspace.didSave(save, named: "Bounce.flare")
        let saved = workspace.document
        workspace.setProperty("x", to: start + 20, dragStart: start)
        #expect(workspace.isDirty)
        workspace.undo()
        #expect(workspace.document == saved)
        #expect(workspace.isDirty == false)
    }

    @Test func autosaveIsTheKernelsVerdict() {
        let (workspace, _) = scrubbing()
        #expect(workspace.kernelAutosaveDue(lastEdit: 100, now: 129.9) == false)
        #expect(workspace.kernelAutosaveDue(lastEdit: 100, now: 130))
        #expect(workspace.autosaveSession(lastEdit: 100).autosaveDue(
            now: Date(timeIntervalSinceReferenceDate: 130), delay: FlareWorkspace.autosaveDelay))
        var clean = workspace
        clean.undo()
        #expect(clean.kernelAutosaveDue(lastEdit: 100, now: 10_000) == false)
    }

    @Test func theLaunchOfferIsTheKernels() {
        let at = Date(timeIntervalSince1970: 1_000)
        let offer: SuiteKernel.RecoveryOffer = FlareWorkspace.recoveryOffer(savedAt: at)
        #expect(offer == SuiteKernel.RecoveryOffer(name: "Untitled", savedAt: at))
    }
}
