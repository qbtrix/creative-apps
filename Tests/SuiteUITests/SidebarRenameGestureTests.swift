// SidebarRenameGestureTests.swift: guards against #54 coming back. #54 was
// the rename double-click sitting on the whole row, so a double-click on a
// toggle flipped it twice and opened the rename field. The rename predicate
// (`SidebarRow.doubleClickRenames`) can stay right while the gesture moves
// back onto the row, so these tests read SidebarRow.swift and check where the
// double-click gesture is attached. macOS only.
//
// A spelling check alone misses a gesture written another way (#308): a named
// `some Gesture`, a helper modifier that hides `TapGesture`, or a modifier
// that grows the title label's hit area over the toggles or the blank space.
// So the row body and the title may only call the modifiers and views they
// call today, the title label's chain is pinned, and a rename can start from
// one call site only. A new modifier there fails a test until it is added to
// an allowlist below, which is the place to ask whether it can start a rename
// from a toggle or the blank space.
import Foundation
import Testing

/// SidebarRow.swift's source without comments: this file is
/// Tests/SuiteUITests/<name>.swift, so the package root is three levels up.
private func sidebarRowSource(from file: String = #filePath) throws -> String {
    let root = URL(fileURLWithPath: file).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let text = try String(contentsOf: root.appending(path: "Sources/SuiteUI/SidebarRow.swift"), encoding: .utf8)
    return text.split(separator: "\n", omittingEmptySubsequences: false)
        .map { line in line.range(of: "//").map { line[..<$0.lowerBound] } ?? line }
        .joined(separator: "\n")
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

/// `text` with all whitespace removed, so `TapGesture(count:2)` matches
/// however it is spaced.
private func squeezed(_ text: some StringProtocol) -> String {
    String(text.filter { !$0.isWhitespace })
}

/// What `text` calls: `modifiers` are the names after a `.` that take
/// arguments or a trailing closure (`.badge(`, `.onDoubleClick {`), `calls`
/// the other names followed by `(` or `{` (views, functions, and the keywords
/// that precede a brace).
private func callNames(in text: some StringProtocol) -> (modifiers: Set<String>, calls: Set<String>) {
    let chars = Array(text)
    var modifiers: Set<String> = []
    var calls: Set<String> = []
    var index = 0
    while index < chars.count {
        let char = chars[index]
        guard char.isLetter || char == "_" else {
            index += 1
            continue
        }
        let start = index
        while index < chars.count, chars[index].isLetter || chars[index].isNumber || chars[index] == "_" { index += 1 }
        let name = String(chars[start..<index])
        var next = index
        while next < chars.count, chars[next].isWhitespace { next += 1 }
        guard next < chars.count, chars[next] == "(" || chars[next] == "{" else { continue }
        var previous = start - 1
        while previous >= 0, chars[previous].isWhitespace { previous -= 1 }
        if previous >= 0, chars[previous] == "." { modifiers.insert(name) } else { calls.insert(name) }
    }
    return (modifiers, calls)
}

@Test func sidebarRowHasExactlyOneDoubleClickGesture() throws {
    let source = squeezed(try sidebarRowSource())
    #expect(occurrences(of: "TapGesture(count:2", in: source) == 1)
    #expect(occurrences(of: "onTapGesture(", in: source) == 0)
    #expect(occurrences(of: "someGesture", in: source) == 0, "a named gesture can be attached anywhere in the row (#308)")
}

@Test func renameStartsFromOneCallSiteOnly() throws {
    let source = try sidebarRowSource()
    #expect(occurrences(of: "beginRename", in: source) == 2, "beginRename is declared once and used once, by the title label")
    let flat = squeezed(source)
    #expect(occurrences(of: "draft=item.title", in: flat) == 1)
    #expect(occurrences(of: "editing=true", in: flat) == 1)
    let begin = try #require(region(of: source, from: "private func beginRename", to: "private func commitRename"))
    #expect(squeezed(begin).contains("draft=item.title"), "only beginRename opens the rename field")
}

@Test func rowBodyAndItsTogglesCarryNoDoubleClickGesture() throws {
    let source = try sidebarRowSource()
    let body = try #require(region(of: source, from: "public var body: some View {", to: "private var title: some View"))
    #expect(body.contains("ForEach(item.toggles)"), "the toggles moved out of body; point this test at them")
    for word in ["Gesture", "beginRename", "draft", "editing"] {
        #expect(!body.contains(word), "body uses \(word): the row or a toggle could start a rename (#54)")
    }
    let names = callNames(in: body)
    let modifiers: Set = [
        "toggleStyle", "buttonStyle", "labelStyle", "foregroundStyle", "disabled", "help", "accessibilityLabel", "badge",
    ]
    let calls: Set = ["View", "HStack", "Spacer", "ForEach", "Toggle", "Binding", "Label"]
    #expect(names.modifiers.subtracting(modifiers).isEmpty, "new modifier in body: can it rename from a toggle? (#54)")
    #expect(names.calls.subtracting(calls).isEmpty, "new view or call in body: can it rename from a toggle? (#54)")
}

@Test func renameDoubleClickSitsOnTheTitleLabelOnly() throws {
    let source = try sidebarRowSource()
    let title = try #require(
        region(of: source, from: "private var title: some View", to: "public static func doubleClickRenames"))
    #expect(
        squeezed(title).contains(
            "Label(item.title,systemImage:item.systemImage).contentShape(Rectangle())"
                + ".simultaneousGesture(TapGesture(count:2).onEnded{beginRename(on:.title)})}"),
        "the rename gesture must sit right on the plain title Label, with nothing after it")
    #expect(!title.lowercased().contains("toggle"), "the title must not draw the toggles inside its hit area (#308)")
    #expect(!title.contains("beginRename(on: .toggle)"))
    let names = callNames(in: title)
    let modifiers: Set = [
        "focused", "onSubmit", "onExitCommand", "onChange", "contentShape", "simultaneousGesture", "onEnded",
    ]
    let calls: Set = [
        "View", "nil", "else", "focused", "TextField", "Binding", "commitRename", "Label", "Rectangle", "TapGesture",
        "beginRename",
    ]
    #expect(
        names.modifiers.subtracting(modifiers).isEmpty,
        "new modifier on the title: does it grow the rename hit area over the toggles or blank space? (#308)")
    #expect(names.calls.subtracting(calls).isEmpty, "new view or call in the title: can it rename elsewhere? (#308)")
}
