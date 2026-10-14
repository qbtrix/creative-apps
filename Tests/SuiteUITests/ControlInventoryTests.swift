// ControlInventoryTests.swift: SuiteControlInventory catches what the Fake
// misses (a duplicate id), its document is sorted and round-trips through
// JSON with its roles, a ToolbarAction registers only with an identifier and
// with its tooltip as the reason, suiteReduceMotion follows the system until
// set, and nested .suiteProbes() publish one suite.controls and one
// suite.perf element in a hosted view's accessibility tree. macOS only.
import AppKit
import Foundation
import SuiteUI
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
        let view = Text(verbatim: "Canvas").suiteProbes(arguments: flag).suiteProbes(arguments: flag)
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let ids = Self.identifiers(in: host, depth: 0)
        #expect(ids.filter { $0 == SuiteControlsElement.identifier }.count == 1)
        #expect(ids.filter { $0 == SuitePerfElement.identifier }.count == 1)

        let quiet = NSHostingView(rootView: Text(verbatim: "Canvas").suiteProbes(arguments: []))
        quiet.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        quiet.layoutSubtreeIfNeeded()
        #expect(!Self.identifiers(in: quiet, depth: 0).contains(SuiteControlsElement.identifier))
    }

    /// Every accessibility identifier under `element`, depth first. Asked by
    /// selector, so any NSObject node answers whichever accessibility protocol it adopts.
    @MainActor static func identifiers(in element: Any, depth: Int) -> [String] {
        guard depth < 32, let node = element as? NSObject else { return [] }
        let own = ask(node, "accessibilityIdentifier") as? String
        let children = (ask(node, "accessibilityChildren") as? [Any] ?? [])
            .flatMap { identifiers(in: $0, depth: depth + 1) }
        return (own.map { $0.isEmpty ? [] : [$0] } ?? []) + children
    }

    @MainActor static func ask(_ node: NSObject, _ name: String) -> Any? {
        let selector = NSSelectorFromString(name)
        guard node.responds(to: selector) else { return nil }
        return node.perform(selector)?.takeUnretainedValue()
    }
}
