// InspectorSectionTests.swift: the identifier an InspectorSection's header
// carries, so journeys and the app audit find it (#262). macOS only.
import SuiteUI
import SwiftUI
import Testing

@Test func sectionHeaderIdentifierIsTheTitleInLowerCaseHyphenated() {
    #expect(InspectorSection<EmptyView>.headerIdentifier("Metadata") == "suite.inspector.section.metadata")
    #expect(InspectorSection<EmptyView>.headerIdentifier("Tool Options") == "suite.inspector.section.tool-options")
    #expect(InspectorSection<EmptyView>.headerIdentifier("Hue/Saturation") == "suite.inspector.section.hue-saturation")
}

@Test func distinctSectionTitlesGetDistinctIdentifiers() {
    let titles = ["Composition", "Layers", "Layer", "Frame", "Fill", "Align"]
    #expect(Set(titles.map(InspectorSection<EmptyView>.headerIdentifier)).count == titles.count)
}
