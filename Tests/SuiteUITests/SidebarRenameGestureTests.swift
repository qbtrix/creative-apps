// SidebarRenameGestureTests.swift: guards against #54 coming back. #54 was
// the rename double-click sitting on the whole row, so a double-click on a
// toggle flipped it twice and opened the rename field. The rename predicate
// (`SidebarRow.doubleClickRenames`) can stay right while the gesture moves
// back onto the row, so these tests read SidebarRow.swift and check where the
// double-click gesture is attached. macOS only.
import Foundation
import Testing

/// SidebarRow.swift's source: this file is Tests/SuiteUITests/<name>.swift,
/// so the package root is three levels up.
private func sidebarRowSource(from file: String = #filePath) throws -> String {
    let root = URL(fileURLWithPath: file).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appending(path: "Sources/SuiteUI/SidebarRow.swift"), encoding: .utf8)
}

/// The text from `start` up to `end`, or nil when either marker is missing.
private func region(of source: String, from start: String, to end: String) -> Substring? {
    guard let head = source.range(of: start), let tail = source.range(of: end, range: head.upperBound..<source.endIndex)
    else { return nil }
    return source[head.lowerBound..<tail.lowerBound]
}

private func occurrences(of needle: String, in text: some StringProtocol) -> Int {
    text.components(separatedBy: needle).count - 1
}

@Test func sidebarRowHasExactlyOneDoubleClickGesture() throws {
    let source = try sidebarRowSource()
    #expect(occurrences(of: "TapGesture(count: 2)", in: source) == 1)
    #expect(occurrences(of: "onTapGesture(count: 2", in: source) == 0)
}

@Test func rowBodyAndItsTogglesCarryNoDoubleClickGesture() throws {
    let source = try sidebarRowSource()
    let body = try #require(region(of: source, from: "public var body: some View {", to: "private var title: some View"))
    #expect(body.contains("ForEach(item.toggles)"), "the toggles moved out of body; point this test at them")
    #expect(!body.contains("TapGesture"), "a tap gesture on the row or its toggles lets a toggle double-click rename (#54)")
}

@Test func renameDoubleClickSitsOnTheTitleLabelOnly() throws {
    let source = try sidebarRowSource()
    let title = try #require(
        region(of: source, from: "private var title: some View", to: "public static func doubleClickRenames"))
    let label = try #require(title.range(of: "Label(item.title"))
    let gesture = try #require(title.range(of: "TapGesture(count: 2)"))
    #expect(label.upperBound <= gesture.lowerBound, "the rename gesture must follow the title Label")
    #expect(title[gesture.upperBound...].contains("beginRename(on: .title)"))
    #expect(!title.contains("beginRename(on: .toggle)"))
}
