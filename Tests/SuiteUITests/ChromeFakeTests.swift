// ChromeFakeTests.swift: the editor-chrome Fakes (UC6 ToolPicking, UC13
// TransportStepping, UC14 StatusPillComposing) give their literal results and
// keep the gap each one has on purpose: the transport Fake never wraps and
// prints frames with no tooltip, the tool Fake never flags a shortcut used
// twice, the pill Fake prints the raw zoom. The three rules are stubs with
// their final signatures (EC-1): SuiteTransport and SuiteToolPicking give
// their Fakes' values, SuiteStatusPills today's ViewerStatusBar text. EC-5b,
// EC-6b and EC-8b replace the stub expectations. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let brush = ToolFace(id: "brush", title: "Brush", shortcut: "B")
private let blur = ToolFace(id: "blur", title: "Blur", shortcut: "b")
private let crop = ToolFace(id: "crop", title: "Crop", shortcut: "C", unavailableHelp: "Open a photo to crop.")
private let hand = ToolFace(id: "hand", title: "Hand")
private let empty = ToolFace(id: "empty", title: "Empty", unavailableHelp: "")

@Test func fakeTransportClampsAtTheEndsEvenWhileLooping() {
    let t = FakeTransportStepping()
    let atEnd = TransportState(frame: 47, frameCount: 48, fps: 24, loops: true)
    #expect(t.stepped(atEnd, by: 1).frame == 47)
    #expect(t.stepped(TransportState(frame: 0, frameCount: 48, fps: 24, loops: true), by: -1).frame == 0)
    #expect(t.stepped(TransportState(frame: 10, frameCount: 48, fps: 24), by: 2).frame == 12)
    #expect(t.stepped(TransportState(frame: 10, frameCount: 48, fps: 24), by: .max).frame == 47)
    #expect(t.stepped(TransportState(frame: 10, frameCount: 48, fps: 24), by: .min).frame == 0)
    #expect(t.toStart(atEnd).frame == 0)
    #expect(t.toEnd(TransportState(frame: 3, frameCount: 48, fps: 24)).frame == 47)
    #expect(t.toEnd(TransportState(frame: 0, frameCount: 0, fps: 24)).frame == 0)
}

@Test func fakeTransportFacePrintsFramesWithNoTooltip() {
    let t = FakeTransportStepping()
    let face = t.face(TransportState(frame: 12, frameCount: 48, fps: 24, isPlaying: true))
    #expect(face == TransportFace(playTitle: "Pause", unavailableHelp: nil, timecode: "12 / 48", timecodeHelp: nil))
    let none = t.face(TransportState(frame: 0, frameCount: 0, fps: 24))
    #expect(none.playTitle == "Play")
    #expect(none.unavailableHelp == "Nothing to play.")
    #expect(none.timecode == "0 / 0")
}

@Test func fakeToolPickingPicksOnlyAnEnabledToolByKey() {
    let p = FakeToolPicking()
    #expect(p.tool(forKey: "b", in: [brush, crop]) == "brush")
    #expect(p.tool(forKey: "B", in: [brush, crop]) == "brush")
    #expect(p.tool(forKey: "c", in: [brush, crop]) == nil)
    #expect(p.tool(forKey: "h", in: [hand]) == nil)
    #expect(p.help(for: brush) == "Brush (B)")
    #expect(p.help(for: blur) == "Blur (B)")
    #expect(p.help(for: hand) == "Hand")
    #expect(p.help(for: crop) == "Open a photo to crop.")
}

@Test func fakeToolPickingFlagsAnEmptyReasonButNoDuplicateShortcut() {
    #expect(FakeToolPicking().violations(in: [brush, blur, crop, empty]) == ["empty"])
    #expect(FakeToolPicking().violations(in: [brush, blur]).isEmpty)
}

@Test func fakeStatusPillsPrintTheRawZoom() {
    let warn = StatusPill(text: "Low memory", style: .warning)
    let onion = StatusPill(text: "Onion", style: .toggle(isOn: true))
    let pills = FakeStatusPillComposing().pills(zoom: 2, documentSize: PlaneExtent(width: 1920, height: 1080),
                                                trailing: [onion, warn])
    #expect(pills == [StatusPill(text: "2.0×"), StatusPill(text: "1920 × 1080"), onion, warn])
    #expect(pills.first?.style == .plain)
}

@Test func suiteTransportStubGivesTheFakesValues() {
    let stub: any TransportStepping = SuiteTransport()
    let fake = FakeTransportStepping()
    for state in [TransportState(frame: 47, frameCount: 48, fps: 24, loops: true),
                  TransportState(frame: 0, frameCount: 48, fps: 24, isPlaying: true),
                  TransportState(frame: 0, frameCount: 0, fps: 0)] {
        #expect(stub.stepped(state, by: 1) == fake.stepped(state, by: 1))
        #expect(stub.stepped(state, by: -1) == fake.stepped(state, by: -1))
        #expect(stub.toStart(state) == fake.toStart(state))
        #expect(stub.toEnd(state) == fake.toEnd(state))
        #expect(stub.face(state) == fake.face(state))
    }
}

@Test func suiteToolPickingStubGivesTheFakesValues() {
    let stub: any ToolPicking = SuiteToolPicking()
    let tools = [brush, blur, crop, hand, empty]
    #expect(stub.tool(forKey: "b", in: tools) == "brush")
    #expect(stub.tool(forKey: "c", in: tools) == nil)
    #expect(tools.map(stub.help(for:)) == tools.map(FakeToolPicking().help(for:)))
    #expect(stub.violations(in: tools) == ["empty"])
}

@Test func suiteStatusPillsStubGivesTodaysText() {
    let stub: any StatusPillComposing = SuiteStatusPills()
    let onion = StatusPill(text: "Onion", style: .toggle(isOn: false))
    let pills = stub.pills(zoom: 2, documentSize: PlaneExtent(width: 1920, height: 1080), trailing: [onion])
    #expect(pills == [StatusPill(text: "200%"), StatusPill(text: "1920 × 1080"), onion])
    #expect(pills.first?.text == ViewerZoom.percentText(2))
    #expect(stub.pills(zoom: .nan, documentSize: PlaneExtent(width: .infinity, height: 10), trailing: [])
        == [StatusPill(text: "–"), StatusPill(text: "0 × 10")])
}
