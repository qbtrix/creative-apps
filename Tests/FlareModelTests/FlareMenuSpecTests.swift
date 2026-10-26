// FlareMenuSpecTests.swift (command-state CS-12): the spec each Flare control is built on. An intent with a
// command id names a command the catalog has, and its control's spec is that command; one without gets a window
// spec under its identifier. Either spec is on exactly while the window gives no reason.
import SuiteKernel
import Testing
@testable import FlareModel

struct FlareMenuSpecTests {
    @Test(arguments: FlareIntent.examples.filter { $0.commandID != nil })
    func commandIDIsCatalogued(_ intent: FlareIntent) throws {
        let id = try #require(intent.commandID)
        #expect(FlareWorkspace.catalog.spec(id) != nil, "\(intent.identifier) runs \(id), which the catalog lacks")
        #expect(FlareWorkspace.menuSpec(for: intent).id == id)
    }

    @Test func controlsRunTheirCommands() {
        let ids = [FlareIntent.file(.new), .edit(.cut), .edit(.bringForward), .timeline(.setLabel(nil)), .timeline(.step(-1)),
                   .timeline(.removeKeys), .timeline(.selectAllKeys)].map { FlareWorkspace.menuSpec(for: $0).id }
        #expect(ids == ["file.new", "edit.cut", "object.bring-forward", "frame.label", "animate.previous-frame",
                        "timeline.delete-keys", "timeline.select-all-keys"])
    }

    @Test func windowOnlyIntentGetsAWindowSpec() {
        let intent = FlareIntent.view(.zoomIn)
        #expect(intent.commandID == nil)
        let spec = FlareWorkspace.menuSpec(for: intent)
        #expect(spec.id == intent.identifier && spec.title == intent.title)
    }

    @Test(arguments: [FlareIntent.file(.new), .view(.fit)])
    func onExactlyWithoutAReason(_ intent: FlareIntent) {
        let spec = FlareWorkspace.menuSpec(for: intent)
        #expect(spec.availability(nil).why == nil)
        #expect(spec.availability("Open an animation first.").why == "Open an animation first.")
    }
}
