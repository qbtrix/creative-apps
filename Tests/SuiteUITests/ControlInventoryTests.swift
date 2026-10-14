// ControlInventoryTests.swift: SuiteControlInventory catches what the Fake
// misses (a duplicate id), its document is sorted and round-trips through
// JSON with its roles, a ToolbarAction registers only with an identifier and
// with its tooltip as the reason, suiteReduceMotion follows the system until
// set, and nested .suiteProbes() place one suite.controls and one suite.perf
// element in a hosted view, counted through SuiteProbeElementsKey: SwiftUI
// builds the accessibility tree only for an assistive client, so walking it
// here found nothing. macOS only.
import AppKit
import Foundation
@testable import SuiteUI
import SwiftUI
import Testing

@Suite struct ControlInventoryTests {
    @Test func aDuplicateIdAndADisabledEntryWithNoReasonAreViolations() {
        var inventory = SuiteControlInventory()
        inventory.register(ControlEntry(id: "b.export", enabled: true))
        inventory.register(ControlEntry(id: "b.export", enabled: true))
        inventory.register(ControlEntry(id: "a.crop", enabled: false))
        inventory.register(ControlEntry(id: "c.blur", enabled: false, reason: "Select a layer first."))
        #expect(inventory.violations() == ["a.crop", "b.export"])

        var fake = FakeControlInventory()
        fake.register(ControlEntry(id: "b.export", enabled: true))
        fake.register(ControlEntry(id: "b.export", enabled: true))
        #expect(fake.violations().isEmpty)
    }

    @Test func oneViewReRegisteringIsNotADuplicateAndLeavingClearsIt() {
        var inventory = SuiteControlInventory()
        let first = UUID(), second = UUID()
        inventory.register(ControlEntry(id: "x.undo", enabled: true), owner: first)
        inventory.register(ControlEntry(id: "x.undo", enabled: false, reason: "Nothing to undo."), owner: first)
        #expect(inventory.violations().isEmpty)
        #expect(inventory.document().controls == [ControlEntry(id: "x.undo", enabled: false, reason: "Nothing to undo.")])
        inventory.register(ControlEntry(id: "x.undo", enabled: true), owner: second)
        #expect(inventory.violations() == ["x.undo"])
        inventory.unregister("x.undo", owner: second)
        #expect(inventory.violations().isEmpty)
        inventory.unregister("x.undo")
        #expect(inventory.document().controls.isEmpty)
    }

    @Test func theDocumentIsSortedAndRoundTripsWithItsRole() throws {
        var inventory = SuiteControlInventory()
        for id in ["m.save", "a.open", "z.export"] {
            inventory.register(ControlEntry(id: id, enabled: true, role: id == "z.export" ? "primary" : nil))
        }
        #expect(inventory.document().controls.map(\.id) == ["a.open", "m.save", "z.export"])
        let decoded = try JSONDecoder().decode(ControlDocument.self, from: inventory.encoded())
        #expect(decoded == inventory.document())
        #expect(decoded.controls.last?.role == "primary")
        #expect(SuiteControlInventory().json() == #"{"controls":[]}"#)
    }

    @Test func aToolbarActionRegistersOnlyWithAnIdentifier() {
        let unavailable = ToolbarAction(
            "Export", systemImage: "square.and.arrow.up", unavailableHelp: "Open a document to export.",
            identifier: "suite.export")
        let entry = unavailable.controlEntry(role: "primary")
        #expect(entry == ControlEntry(id: "suite.export", enabled: false, reason: unavailable.help, role: "primary"))
        let ready = ToolbarAction("Brush", systemImage: "paintbrush", shortcut: "b", identifier: "suite.brush")
        #expect(ready.controlEntry() == ControlEntry(id: "suite.brush", enabled: true))
        #expect(ToolbarAction("Brush", systemImage: "paintbrush").controlEntry() == nil)
    }

    @Test func suiteReduceMotionFollowsTheSystemUntilSet() {
        var environment = EnvironmentValues()
        #expect(environment.suiteReduceMotion == environment.accessibilityReduceMotion)
        environment.suiteReduceMotion = true
        #expect(environment.suiteReduceMotion)
    }

    @MainActor @Test func nestedProbesPublishOneOfEachElement() {
        let flag = [SuiteFrameProbe.launchFlag]
        let nested = Self.placed(Text(verbatim: "Canvas").suiteProbes(arguments: flag).suiteProbes(arguments: flag))
        #expect(nested.filter { $0 == SuiteControlsElement.identifier }.count == 1)
        #expect(nested.filter { $0 == SuitePerfElement.identifier }.count == 1)
        #expect(nested.count == 2)
        #expect(Self.placed(Text(verbatim: "Canvas").suiteProbes(arguments: [])).isEmpty)
    }

    /// The probe elements `view` places once hosted in a window and laid out.
    @MainActor static func placed(_ view: some View) -> [String] {
        let seen = PlacedProbes()
        let host = NSHostingView(rootView: view.onPreferenceChange(SuiteProbeElementsKey.self) { ids in
            MainActor.assumeIsolated { seen.ids = ids }
        })
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        return seen.ids
    }
}

@MainActor private final class PlacedProbes {
    var ids: [String] = []
}
