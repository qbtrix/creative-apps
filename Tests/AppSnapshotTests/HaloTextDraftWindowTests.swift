// HaloTextDraftWindowTests.swift: H-J22 step 5 (#2177) in the real Halo
// window, without XCUITest. It hosts HaloWindow (HostedHaloWindow) on
// `-HaloSample empty` with two text layers, Hello under the selected Text 2,
// starts editing Text 2's TEXT field, types Stale into its field editor
// without Return, then presses Text 1's row in the layer list. Spec: Text 1
// is selected, its field reads Hello, and Text 1 still holds Hello; the
// unreturned Stale never lands on the other layer. This is the app half of
// the journey's step 5, which went red (#2159) because XCUITest's click
// missed the row, not because the draft leaked. The timeline's name buttons
// and lanes carry `halo.timeline.name.<id>` / `.lane.<id>`, so the
// identifier audit finds them (#1789, #2159). macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct HaloTextDraftWindowTests {
        static let first = "comp-1-layer-1", second = "comp-1-layer-2"
        static let stringID = "halo.inspector.text.string"

        @Test(.timeLimit(.minutes(3))) func timelineNamesAndLanesHaveIdentifiers() async throws {
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "empty"]).project()
            project.newLayer(.text)
            let hosted = try await HostedHaloWindow(project)
            defer { hosted.close() }
            let found = hosted.frames(under: "halo.timeline.")
            #expect(found["halo.timeline.name.\(Self.first)"] != nil, "no name id in \(found.keys.sorted())")
            #expect(found["halo.timeline.lane.\(Self.first)"] != nil, "no lane id in \(found.keys.sorted())")
        }

        @Test(.timeLimit(.minutes(3))) func anUnreturnedDraftStaysOffTheNextLayer() async throws {
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "empty"]).project()
            project.newLayer(.text)
            project.setText("Hello")
            project.newLayer(.text)
            #expect(project.selectedLayerID == Self.second)
            let hosted = try await HostedHaloWindow(project)
            defer { hosted.close() }

            let editor = try #require(try await hosted.edit(Self.stringID), "the TEXT field didn't start editing")
            editor.selectAll(nil)
            editor.insertText("Stale", replacementRange: editor.selectedRange())
            try await Task.sleep(for: .milliseconds(200))
            #expect(hosted.value(of: Self.stringID) == "Stale")

            #expect(try await hosted.press("halo.layer.row.\(Self.first)"), "no row to press for \(Self.first)")
            try await Task.sleep(for: .milliseconds(300))

            #if DEBUG
            let after = try #require(HaloWindow.shownProject)
            #expect(after.selectedLayerID == Self.first, "the row click didn't select \(Self.first): \(after.selectedLayerID ?? "nil"), \(after.selectedText?.string ?? "nil")")
            #expect(after.selectedText?.string == "Hello", "Text 1 now holds \(after.selectedText?.string ?? "nil")")
            #endif
            #expect(hosted.value(of: Self.stringID) == "Hello", "the TEXT field reads \(hosted.value(of: Self.stringID) ?? "nil")")
        }
    }
}
#endif
