// ProbeElementTests.swift: SuiteUI's ProbeElement, the hidden element a
// journey reads: it keeps the identifier, label and value it is given, fills
// its container unless `size` pins it, and the controls inventory built from
// a list keeps the last entry per id, sorted (what `halo.controls` and
// `library.controls` publish). macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct ProbeElementTests {
    @Test func itKeepsWhatItIsGiven() {
        let probe = ProbeElement("halo.file", label: "Edited", value: "Edited")
        #expect(probe.identifier == "halo.file" && probe.label == "Edited" && probe.value == "Edited")
        #expect(ProbeElement("halo.viewer.summary", label: "2 layers").value == nil)
    }

    @Test func aSizedProbeKeepsItsSize() {
        let host = NSHostingView(rootView: ProbeElement("x", label: "y", size: CGSize(width: 1, height: 1)))
        #expect(host.fittingSize == CGSize(width: 1, height: 1))
    }

    @Test func anInventoryFromEntriesKeepsTheLastPerIdSorted() throws {
        let inventory = SuiteControlInventory(entries: [
            ControlEntry(id: "b.export", enabled: false, reason: "No image"),
            ControlEntry(id: "a.crop", enabled: true),
            ControlEntry(id: "b.export", enabled: true),
        ])
        #expect(inventory.document().controls.map(\.id) == ["a.crop", "b.export"])
        #expect(inventory.document().controls.last?.enabled == true)
    }
}
