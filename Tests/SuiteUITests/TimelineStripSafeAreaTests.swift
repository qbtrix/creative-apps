// TimelineStripSafeAreaTests.swift: guards against #1034 coming back. A color
// `.background` ignores every safe-area edge unless told otherwise, so under a
// floating sidebar the selected track row's highlight, and the button's frame
// with it, reached 208 pt left of the strip. Every color background in every
// Sources/SuiteUI/Timeline*.swift (the strip is cut into several files) must
// say `ignoresSafeAreaEdges:`. Reads the sources, like
// SidebarRenameGestureTests. macOS only.
import Foundation
import Testing

/// Each `.background(...)` call in `source` whose argument names a color and
/// doesn't pass `ignoresSafeAreaEdges:`. Comment lines are skipped, and a call
/// may span several lines.
private func colorBackgroundsIgnoringTheSafeArea(in source: String) -> [String] {
    let code = source.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
    var found: [String] = []
    var rest = code[...]
    while let start = rest.range(of: ".background(") {
        var depth = 1
        var end = start.upperBound
        while end < rest.endIndex, depth > 0 {
            if rest[end] == "(" { depth += 1 } else if rest[end] == ")" { depth -= 1 }
            end = rest.index(after: end)
        }
        let call = String(rest[start.lowerBound..<end])
        if call.contains("Color"), !call.contains("ignoresSafeAreaEdges:") { found.append(call) }
        rest = rest[end...]
    }
    return found
}

/// Every Sources/SuiteUI/Timeline*.swift, by file name.
private func timelineSources() throws -> [String: String] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let folder = root.appending(path: "Sources/SuiteUI")
    let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        .filter { $0.hasPrefix("Timeline") && $0.hasSuffix(".swift") }
    var sources: [String: String] = [:]
    for name in names {
        sources[name] = try String(contentsOf: folder.appending(path: name), encoding: .utf8)
    }
    return sources
}

@Test func timelineStripBackgroundsRespectTheSafeArea() throws {
    let sources = try timelineSources()
    for name in ["TimelineStrip.swift", "TimelineLane.swift", "TimelineRuler.swift", "TimelinePlayhead.swift"] {
        #expect(sources[name] != nil, "\(name) moved; point this test at the strip's files")
    }
    let backgrounds = sources.values.map { $0.components(separatedBy: ".background(").count - 1 }.reduce(0, +)
    #expect(backgrounds >= 2, "the track rows' highlights moved; point this test at them")
    for (name, source) in sources.sorted(by: { $0.key < $1.key }) {
        for call in colorBackgroundsIgnoringTheSafeArea(in: source) {
            Issue.record("\(name): a color background ignores the safe area (#1034): \(call)")
        }
    }
}

@Test func theSafeAreaGuardCatchesAColorBackgroundWithoutEdges() {
    let source = """
        .background(SuiteColor.accent.opacity(0.08))
        .background(
            isOn ? Color.red : Color.clear
        )
        // .background(Color.clear)
        .background(Color.clear, ignoresSafeAreaEdges: [])
        .background(Capsule().fill(.thinMaterial))
        """
    let found = colorBackgroundsIgnoringTheSafeArea(in: source)
    #expect(found.count == 2)
    #expect(found.first == ".background(SuiteColor.accent.opacity(0.08))")
}
