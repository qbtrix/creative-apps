// ChromeFakeTests.swift: the chrome Fakes (UC6 ToolPicking, UC13
// TransportStepping, UC14 StatusPillComposing) give the contracts' literal
// results and keep the gap each one has on purpose: the transport Fake never
// wraps and prints frames, the tool Fake never flags a shortcut used twice,
// the pill Fake prints the raw zoom. The three rules compile against their
// contracts; SuiteTransport and SuiteToolPicking give their Fakes' values
// until EC-5b and EC-8b, and SuiteStatusPills already gives today's text.
// No SwiftUI. macOS only.
import SuiteUI
import Testing

@Test func fakeTransportClampsAndNeverWraps() {
    let t = FakeTransportStepping()
    let end = TransportState(frame: 47, frameCount: 48, fps: 24, loops: true)
    #expect(t.stepped(end, by: 1).frame == 47)
    #expect(t.stepped(TransportState(frame: 0, frameCount: 48, fps: 24, loops: true), by: -1).frame == 0)
    #expect(t.stepped(TransportState(frame: 10, frameCount: 48, fps: 24), by: 2).frame == 12)
    #expect(t.toStart(end).frame == 0)
    #expect(t.toEnd(TransportState(frame: 3, frameCount: 48, fps: 24)).frame == 47)
    #expect(t.toEnd(TransportState(frame: 0, frameCount: 0, fps: 24)).frame == 0)
}

@Test func fakeTransportFacePrintsFrames() {
    let t = FakeTransportStepping()
    let paused = t.face(TransportState(frame: 12, frameCount: 48, fps: 24))
    #expect(paused == TransportFace(playTitle: "Play", unavailableHelp: nil, timecode: "12 / 48"))
    #expect(paused.timecodeHelp == nil)
    #expect(t.face(TransportState(frame: 12, frameCount: 48, fps: 24, isPlaying: true)).playTitle == "Pause")
    let empty = t.face(TransportState(frame: 0, frameCount: 0, fps: 24))
    #expect(empty.unavailableHelp == "Nothing to play.")
    #expect(empty.timecode == "0 / 0")
}

@Test func fakeToolPickingPicksEnabledToolsOnly() {
    let p = FakeToolPicking()
    let tools = [
        ToolFace(id: "erase", title: "Eraser", shortcut: "b", unavailableHelp: "Open a document first."),
        ToolFace(id: "brush", title: "Brush", shortcut: "B"),
        ToolFace(id: "hand", title: "Hand"),
    ]
    #expect(p.tool(forKey: "b", in: tools) == "brush")
    #expect(p.tool(forKey: "B", in: tools) == "brush")
    #expect(p.tool(forKey: "h", in: tools) == nil)
    #expect(p.help(for: tools[1]) == "Brush (B)")
    #expect(p.help(for: tools[2]) == "Hand")
    #expect(p.help(for: tools[0]) == "Open a document first.")
}

@Test func fakeToolPickingFlagsEmptyReasonsButNotDuplicates() {
    let p = FakeToolPicking()
    let tools = [
        ToolFace(id: "a", title: "A", shortcut: "b"),
        ToolFace(id: "b", title: "B", shortcut: "B"),
        ToolFace(id: "c", title: "C", unavailableHelp: ""),
    ]
    #expect(p.violations(in: tools) == ["c"])
}

@Test func fakeStatusPillsPrintRawZoom() {
    let pills = FakeStatusPillComposing().pills(
        zoom: 2, documentSize: PlaneExtent(width: 1920, height: 1080),
        trailing: [StatusPill(text: "Brush", style: .toggle(isOn: true)), StatusPill(text: "Low", style: .warning)])
    #expect(pills.map(\.text) == ["2.0×", "1920 × 1080", "Brush", "Low"])
    #expect(pills.map(\.style) == [.plain, .plain, .toggle(isOn: true), .warning])
}

@Test func stubsConformToTheirContracts() {
    let transport: any TransportStepping = SuiteTransport()
    let tools: any ToolPicking = SuiteToolPicking()
    let pills: any StatusPillComposing = SuiteStatusPills()
    #expect(transport.face(TransportState(frame: 1, frameCount: 2, fps: 1)).playTitle == "Play")
    #expect(tools.help(for: ToolFace(id: "x", title: "X")) == "X")
    #expect(pills.pills(zoom: 1, documentSize: PlaneExtent(width: 1, height: 1), trailing: []).count == 2)
}

@Test func stubToolPickingGivesItsFakesValues() {
    let tools = [ToolFace(id: "a", title: "A", shortcut: "a"), ToolFace(id: "b", title: "B", shortcut: "A")]
    #expect(SuiteToolPicking().tool(forKey: "A", in: tools) == "a")
    #expect(SuiteToolPicking().help(for: tools[1]) == "B (A)")
}

@Test func stubStatusPillsGiveTodaysText() {
    let pills = SuiteStatusPills().pills(
        zoom: 2, documentSize: PlaneExtent(width: 1920, height: 1080), trailing: [StatusPill(text: "Brush")])
    #expect(pills.map(\.text) == ["200%", "1920 × 1080", "Brush"])
    #expect(pills.first?.text == ViewerZoom.percentText(2))
    let odd = SuiteStatusPills().pills(zoom: .nan, documentSize: PlaneExtent(width: .infinity, height: .nan), trailing: [])
    #expect(odd.map(\.text) == ["–", "0 × 0"])
}
