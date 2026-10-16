// ShellGeometryTests.swift: the window shell's geometry rules on synthetic
// layouts: a fitting one passes, and each broken rule gives exactly one
// violation naming both regions. Runs on Linux and macOS
// (docs/blueprints/suiteui/features/editor-in-window.md, EW-4).
import Testing

private func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> AppAudit.Rect {
    AppAudit.Rect(x: x, y: y, width: width, height: height)
}

/// A 1024 × 737 window: sidebar, viewport over the status line, inspector,
/// the palette inside the viewport clear of the rulers and the artboard.
private let window = rect(0, 31, 1024, 737)
private let fitting: [String: AppAudit.Rect] = [
    "sidebar": rect(0, 83, 220, 685),
    "viewport": rect(220, 83, 500, 657),
    "status": rect(220, 740, 500, 28),
    "inspector": rect(720, 83, 304, 685),
    "ruler.top": rect(220, 83, 500, 16),
    "ruler.leading": rect(220, 83, 16, 657),
    "tools": rect(252, 99, 40, 300),
    "artboard": rect(300, 120, 400, 500),
]
private let minimums: [String: (width: Double, height: Double)] = ["viewport": (480, 400), "inspector": (304, 0)]
private let apart = [
    ("sidebar", "viewport"), ("viewport", "inspector"), ("sidebar", "inspector"), ("viewport", "status"),
]
private let clear = [("tools", "ruler.top"), ("tools", "ruler.leading"), ("tools", "artboard")]

private func check(_ changes: [String: AppAudit.Rect]) -> [String] {
    ShellGeometry.violations(
        window: window, regions: fitting.merging(changes) { $1 }, minimums: minimums, apart: apart, clear: clear)
}

@Test func fittingLayoutHasNoViolations() {
    #expect(check([:]) == [])
}

@Test func regionOnePointOutsideTheWindow() {
    let found = check(["inspector": rect(721, 83, 304, 685)])
    #expect(found.count == 1)
    #expect(found.first?.contains("inspector") == true)
    #expect(found.first?.contains("window") == true)
}

@Test func overlapOfTwoPointsIsAViolation() {
    let found = check(["sidebar": rect(0, 83, 222, 685)])
    #expect(found.count == 1)
    #expect(found.first?.contains("sidebar") == true)
    #expect(found.first?.contains("viewport") == true)
}

@Test func overlapOfOnePointOrLessIsAHairline() {
    #expect(check(["sidebar": rect(0, 83, 221, 685)]) == [])
    #expect(check(["status": rect(220, 739.5, 500, 28.5)]) == [])
}

@Test func regionUnderItsMinimum() {
    let found = check(["inspector": rect(740, 83, 284, 685), "viewport": rect(220, 83, 520, 657)])
    #expect(found.count == 1)
    #expect(found.first?.contains("inspector") == true)
    #expect(found.first?.contains("304") == true)
}

@Test func paletteOverARuler() {
    let found = check(["tools": rect(230, 99, 40, 300)])
    #expect(found.count == 1)
    #expect(found.first?.contains("tools") == true)
    #expect(found.first?.contains("ruler.leading") == true)
}

@Test func paletteOverAGrownArtboard() {
    let found = check(["artboard": rect(280, 120, 420, 500)])
    #expect(found.count == 1)
    #expect(found.first?.contains("tools") == true)
    #expect(found.first?.contains("artboard") == true)
}

@Test func touchingIsClear() {
    #expect(check(["artboard": rect(292, 120, 408, 500)]) == [])
}

@Test func missingRegionIsNamed() {
    var regions = fitting
    regions["status"] = nil
    let found = ShellGeometry.violations(
        window: window, regions: regions, minimums: minimums, apart: apart, clear: clear)
    #expect(found == ["status is missing (viewport–status)"])
}

@Test func containerNameAppearsInTheMessage() {
    let found = ShellGeometry.violations(
        window: rect(0, 31, 1024, 737), regions: ["window": rect(0, 20, 1024, 748)],
        minimums: [:], apart: [], clear: [], container: "visible frame")
    #expect(found.count == 1)
    #expect(found.first?.contains("visible frame") == true)
}
