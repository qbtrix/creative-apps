// FacetTests.swift: SuiteUI's Facet box and BodyTally. A Facet set to an equal
// value writes nothing, so a body that read it is not invalidated; a new value
// fires the read's change once. A BodyTally counts each view type on its own.
// macOS only.
#if canImport(AppKit)
import Observation
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor @Suite struct FacetTests {
    @Test func anEqualSetFiresNoChange() {
        let facet = Facet(3)
        nonisolated(unsafe) var changes = 0
        withObservationTracking { _ = facet.value } onChange: { changes += 1 }
        #expect(facet.set(3) == false)
        #expect(changes == 0)
        #expect(facet.set(4))
        #expect(changes == 1)
        #expect(facet.value == 4)
    }

    @Test func aTallyCountsEachViewOnItsOwn() {
        let tally = BodyTally()
        tally.ran(Text.self)
        tally.ran(Text.self)
        tally.ran(Color.self)
        #expect(tally.runs(of: Text.self) == 2)
        #expect(tally.runs(of: Color.self) == 1)
        #expect(tally.runs(of: EmptyView.self) == 0)
    }
}
#endif
