// PhotoTextInspectorTests.swift: the Text section's chips (Weight, Style,
// Alignment) each carry their own accessibility identifier, so journeys and
// the app audit find every chip by identifier (fault #262: XCUITest reads
// SwiftUI values as empty strings). macOS only.
import PhotoModel
import SuiteUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoTextInspectorTests {
    @Test func everyChipHasItsOwnIdentifier() {
        let weights = PhotoTextInspector.weights([(400, false), (700, false), (700, true)])
        let groups: [[String?]] = [
            PhotoTextInspector.alignments.map(\.identifier),
            PhotoTextInspector.slants.map(\.identifier),
            weights.map(\.identifier),
        ]
        for ids in groups {
            #expect(ids.allSatisfy { $0?.hasPrefix("photo.text.") == true }, "a chip has no identifier: \(ids)")
            #expect(Set(ids).count == ids.count, "two chips share an identifier: \(ids)")
        }
        #expect(PhotoTextInspector.alignments.map(\.identifier) == [
            "photo.text.alignment.leading", "photo.text.alignment.center",
            "photo.text.alignment.trailing", "photo.text.alignment.justified",
        ])
    }
}
