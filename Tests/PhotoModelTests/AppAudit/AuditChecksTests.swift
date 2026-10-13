// AuditChecksTests.swift: what each app audit check lets pass, beside the
// seeded violation AuditCoreTests proves it flags: the edge cases found while
// calibrating on the macOS runner (window buttons, popovers, nested and
// touching controls, like-for-like peers, large text, text off the window or
// behind a sheet).
// Runs on Linux and macOS (docs/blueprints/app-audit.md).
import Testing

private typealias Node = AppAudit.Node

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> AppAudit.Rect {
    AppAudit.Rect(x: x, y: y, width: w, height: h)
}

private func button(_ name: String, _ frame: AppAudit.Rect, enabled: Bool = true) -> Node {
    Node(type: "button", frame: frame, identifier: name, name: name, isEnabled: enabled)
}

private func count(
    _ check: any AppAudit.Check, _ nodes: [Node], window: AppAudit.Rect = rect(0, 20, 300, 180),
    paint: [(rect: AppAudit.Rect, grey: UInt8)] = []
) -> AppAudit.Report {
    AppAudit.report(check, on: AppAudit.Fixture(nodes: nodes, window: window, paint: paint))
}

@Test func windowButtonsAreTheSystemsToName() {
    let close = Node(type: "button", frame: rect(8, 24, 16, 16), identifier: "_XCUI:CloseWindow")
    let triangle = Node(type: "disclosureTriangle", frame: rect(8, 50, 15, 26), identifier: "NSOutlineViewDisclosureButtonKey")
    #expect(count(AppAudit.Unnamed(), [close, triangle]).counts["unnamed"] == 0)
    #expect(count(AppAudit.Identifier(), [button("Undo", rect(40, 30, 40, 20))]).counts["identifier"] == 0)
}

@Test func pixelChecksSkipTheWindowBehindAModal() {
    let text = Node(type: "staticText", frame: rect(10, 40, 60, 14), name: "dimmed")
    var fixture = AppAudit.Fixture(nodes: [text], paint: [(rect(12, 42, 30, 10), 0xAA)])
    #expect(AppAudit.report(AppAudit.TextContrast(), on: fixture).counts["contrast"] == 1)
    fixture.nodes.append(Node(type: "sheet", frame: rect(100, 30, 150, 100)))
    #expect(AppAudit.report(AppAudit.TextContrast(), on: fixture).counts["contrast"] == 0)
}

@Test func popoverMayHangOutsideTheWindowButNotTheDisplay() {
    let popover = Node(type: "popover", frame: rect(250, 40, 60, 60), children: [button("hangs", rect(260, 50, 50, 20))])
    #expect(count(AppAudit.Offscreen(), [popover], window: rect(0, 20, 240, 180)).counts["offscreen"] == 0)
}

@Test func scrolledOutControlsAndRowsAreSkippedButClippedRowsAreNot() {
    let list = Node(type: "scrollView", frame: rect(0, 40, 200, 100), children: [
        Node(type: "outlineRow", frame: rect(0, 900, 200, 20)), button("half", rect(0, 130, 200, 20)),
    ])
    let clipped = Node(type: "outlineRow", frame: rect(-40, 150, 100, 20))
    let report = count(AppAudit.Offscreen(), [list, clipped])
    #expect(report.violations.map(\.element) == ["outlineRow ''"])
}

@Test func touchingNestedDisabledOrLayeredControlsDontOverlap() {
    var outer = button("outer", rect(100, 40, 80, 30))
    outer.children = [button("inner", rect(110, 45, 20, 20))]
    let sheet = Node(type: "sheet", frame: rect(0, 30, 300, 150), children: [button("sheet", rect(200, 100, 40, 20))])
    let report = count(AppAudit.Overlap(), [
        button("a", rect(10, 40, 40, 20)), button("b", rect(48, 40, 40, 20)),  // 2 pt of overlap
        outer, button("off", rect(105, 42, 40, 20), enabled: false), sheet, button("under", rect(210, 100, 40, 20)),
    ])
    #expect(report.counts["overlap"] == 0)
}

@Test func dimmedDisabledControlPassesAndIsSampled() {
    let report = count(
        AppAudit.DisabledDim(), [button("on", rect(10, 40, 40, 20)), button("off", rect(60, 40, 40, 20), enabled: false)],
        paint: [(rect(15, 45, 10, 10), 0x55), (rect(65, 45, 10, 10), 0xBB)])
    #expect(report.counts["disabled-dim"] == 0)
    #expect(report.samples.map(\.element) == ["button 'off'"])
}

@Test func disabledControlWithNoPeerOfItsTypeIsNotJudged() {
    let box = Node(type: "checkBox", frame: rect(10, 40, 40, 20), identifier: "c", name: "c")
    let report = count(
        AppAudit.DisabledDim(), [box, button("off", rect(60, 40, 40, 20), enabled: false)],
        paint: [(rect(15, 45, 10, 10), 0x55), (rect(65, 45, 10, 10), 0x55)])
    #expect(report.samples.isEmpty)
}

@Test func disabledControlMeetsAPeerOfItsOwnWidth() {
    // An icon-only Undo between a titled button with a dark title and an
    // icon-only Redo: it is judged against Redo, whose icon it matches.
    let report = count(
        AppAudit.DisabledDim(),
        [button("Open", rect(10, 40, 80, 20)), button("Undo", rect(95, 40, 30, 20), enabled: false),
         button("Redo", rect(170, 40, 30, 20))],
        paint: [(rect(15, 45, 60, 10), 0x00), (rect(100, 45, 10, 10), 0x88), (rect(175, 45, 10, 10), 0x88)])
    #expect(report.violations.first?.detail.hasSuffix("for enabled button 'Redo'") == true)
}

@Test func smallTextNeedsFourAndAHalfLargeTextThree() {
    let report = count(
        AppAudit.TextContrast(),
        [Node(type: "staticText", frame: rect(10, 30, 40, 12), name: "fails"),
         Node(type: "staticText", frame: rect(60, 30, 40, 12), name: "passes"),
         Node(type: "staticText", frame: rect(110, 30, 60, 24), name: "large")],
        paint: [(rect(12, 32, 20, 8), 0x77), (rect(62, 32, 20, 8), 0x76), (rect(112, 34, 30, 16), 0x90)])
    #expect(report.violations.map(\.element) == ["staticText 'fails'"])
    #expect(report.samples.map(\.measure.limit) == [4.5, 4.5, 3])
}

@Test func textInADisabledControlOrOffTheWindowIsNotMeasured() {
    var off = button("off", rect(10, 30, 40, 12), enabled: false)
    off.children = [Node(type: "staticText", frame: rect(10, 30, 40, 12), name: "Undo")]
    let gone = Node(type: "staticText", frame: rect(-60, 30, 50, 12), name: "clipped")
    let report = count(AppAudit.TextContrast(), [off, gone], paint: [(rect(12, 32, 20, 8), 0xDD)])
    #expect(report.samples.isEmpty)
}
