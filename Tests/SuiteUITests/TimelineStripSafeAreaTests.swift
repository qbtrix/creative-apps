// TimelineStripSafeAreaTests.swift: guards against #1034 coming back. A color
// `.background` ignores every safe-area edge unless told otherwise, so under a
// floating sidebar the selected track row's highlight, and the button's frame
// with it, reached 208 pt left of the strip. Every background in
// TimelineStrip.swift must respect the safe area. Reads the source, like
// SidebarRenameGestureTests. macOS only.
import Foundation
import Testing

@Test func timelineStripBackgroundsRespectTheSafeArea() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(contentsOf: root.appending(path: "Sources/SuiteUI/TimelineStrip.swift"), encoding: .utf8)
    let lines = source.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    let backgrounds = lines.filter { $0.contains(".background(") }
    #expect(backgrounds.count >= 2, "the track rows' highlights moved; point this test at them")
    for line in backgrounds {
        #expect(line.contains("ignoresSafeAreaEdges: []"), "a background ignores the safe area (#1034): \(line)")
    }
}
