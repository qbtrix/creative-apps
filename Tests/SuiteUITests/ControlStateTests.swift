// ControlStateTests.swift (command-state CS-1, #3652): a toggle-style control
// reports whether it is on in `suite.controls`. An InspectorAction toggle that
// is on publishes `selected: true` and one that is off `false`; a plain button
// publishes no `selected` key at all, so every existing inventory encodes and
// compares as before, and a document written before the key existed still
// decodes. The picked SegmentedTabs segment and a keyed KeyframeButton report
// theirs too, and a live inventory keeps the state a view places. A toolbar
// action built with `isToggle` reports its state the same way on every bar
// (CS-1b); a plain one reports none. macOS only, like the rest of SuiteUI.
import Foundation
@testable import SuiteUI
import Testing

@Suite struct ControlStateTests {
    private static func json(_ entry: ControlEntry) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(entry), as: UTF8.self)
    }

    private static func original(on: Bool, help: String? = nil) -> ToolbarAction {
        ToolbarAction("Show Original", systemImage: "eye", isSelected: on, unavailableHelp: help,
                      identifier: "library.develop.original")
    }

    @Test func aToggleThatIsOnPublishesSelectedTrue() throws {
        let entry = try #require(InspectorAction.entry(Self.original(on: true), isToggle: true))
        #expect(entry.selected == true)
        #expect(try Self.json(entry).contains(#""selected":true"#))
    }

    @Test func aToggleThatIsOffPublishesSelectedFalse() throws {
        let entry = try #require(InspectorAction.entry(Self.original(on: false), isToggle: true))
        #expect(entry.selected == false)
        #expect(try Self.json(entry).contains(#""selected":false"#))
        // A toggle that can't act draws off, so it reports off.
        let blocked = try #require(InspectorAction.entry(Self.original(on: true, help: "Open a photo."), isToggle: true))
        #expect(blocked.selected == false && blocked.reason == "Open a photo.")
    }

    @Test func aPlainButtonPublishesNoSelectedKey() throws {
        let sync = ToolbarAction("Sync Settings", systemImage: "arrow.triangle.2.circlepath", identifier: "library.develop.sync")
        let entry = try #require(InspectorAction.entry(sync, isToggle: false))
        #expect(entry.selected == nil)
        #expect(entry == ControlEntry(id: "library.develop.sync", enabled: true))
        #expect(try !Self.json(entry).contains("selected"))
        // Even a plain action built selected publishes nothing: only a toggle has a state to report.
        let plain = try #require(InspectorAction.entry(Self.original(on: true), isToggle: false))
        #expect(plain.selected == nil)
        #expect(InspectorAction.entry(ToolbarAction("Untracked", systemImage: "eye"), isToggle: true) == nil)
    }

    private static func grid(on: Bool, help: String? = nil) -> ToolbarAction {
        ToolbarAction("Grid", systemImage: "grid", isSelected: on, unavailableHelp: help, identifier: "suite.view.grid",
                      isToggle: true)
    }

    @Test func aToolbarToggleReportsItsState() throws {
        // On a window toolbar (controlEntry), on the rail and on the floating palette alike.
        let entries: [(ToolbarAction) -> ControlEntry?] = [
            { $0.controlEntry() }, { ToolbarGroup.entry($0, style: .rail) }, { ToolbarGroup.entry($0, style: .floating) },
        ]
        for entry in entries {
            #expect(try #require(entry(Self.grid(on: true))).selected == true)
            #expect(try #require(entry(Self.grid(on: false))).selected == false)
            // A toggle that can't act draws off, so it reports off, still saying why.
            let blocked = try #require(entry(Self.grid(on: true, help: "Open a document.")))
            #expect(blocked.selected == false && blocked.enabled == false && blocked.reason != nil)
        }
        #expect(try Self.json(try #require(Self.grid(on: true).controlEntry())).contains(#""selected":true"#))
    }

    @Test func aPlainToolbarActionReportsNoSelectedKey() throws {
        // Built selected but not a toggle (a palette tool, a plain command): no key.
        let plain = ToolbarAction("Brush", systemImage: "paintbrush", isSelected: true, identifier: "suite.brush")
        #expect(!plain.isToggle)
        for entry in [plain.controlEntry(), ToolbarGroup.entry(plain, style: .rail),
                      ToolbarGroup.entry(plain, style: .floating)] {
            let found = try #require(entry)
            #expect(found.selected == nil)
            #expect(try !Self.json(found).contains("selected"))
        }
        #expect(ToolbarAction("Grid", systemImage: "grid", isToggle: true).controlEntry() == nil)
    }

    @Test func anOldDocumentWithoutTheKeyDecodes() throws {
        let old = #"{"controls":[{"enabled":true,"id":"a.crop"},{"enabled":false,"id":"b.blur","reason":"Select a layer first.","role":"primary"}]}"#
        let document = try JSONDecoder().decode(ControlDocument.self, from: Data(old.utf8))
        #expect(document.controls == [
            ControlEntry(id: "a.crop", enabled: true),
            ControlEntry(id: "b.blur", enabled: false, reason: "Select a layer first.", role: "primary"),
        ])
        #expect(document.controls.allSatisfy { $0.selected == nil })
        let state = #"{"enabled":true,"id":"c.original","selected":true}"#
        let toggle = try JSONDecoder().decode(ControlEntry.self, from: Data(state.utf8))
        #expect(toggle == ControlEntry(id: "c.original", enabled: true, selected: true))
    }

    @Test func onlyThePickedSegmentIsSelected() {
        let tabs = [InspectorOption(id: 0, title: "Adjust"), InspectorOption(id: 1, title: "Layers")]
        let entries = SegmentedTabs<Int>.segmentEntries(tabs, in: "suite.tabs", enabled: true, reason: nil, selection: 1)
        #expect(entries.map(\.selected) == [false, true])
        // Without a selection the segments report nothing, as before.
        #expect(SegmentedTabs<Int>.segmentEntries(tabs, in: "suite.tabs", enabled: true, reason: nil)
            .allSatisfy { $0.selected == nil })
    }

    @Test func theStopwatchIsOnOnceAnimatedAndTheDiamondOnceKeyed() {
        func state(_ key: KeyState) -> (Bool?, Bool?) {
            let pair = KeyframeButton.stateEntries("Opacity", id: "k", state: key, enabled: true)
            return (pair.stopwatch.selected, pair.diamond?.selected)
        }
        #expect(state(.idle) == (false, nil))
        #expect(state(.animated) == (true, false))
        #expect(state(.keyedHere) == (true, true))
    }

    @Test func theLiveInventoryKeepsThePlacedState() throws {
        let owner = UUID()
        var inventory = SuiteControlInventory()
        let off = ControlEntry(id: "library.develop.original", enabled: true, selected: false)
        inventory.place(off, replacing: nil, owner: owner)
        inventory.place(off.selecting(true), replacing: off, owner: owner)
        #expect(inventory.violations().isEmpty, "one view updating its state is not a duplicate")
        #expect(inventory.document().controls == [off.selecting(true)])
        #expect(inventory.json().contains(#""selected":true"#))
        let renamed = ControlEntry(id: "library.develop.compare", enabled: true)
        inventory.place(renamed, replacing: off.selecting(true), owner: owner)
        #expect(inventory.document().controls == [renamed])
        #expect(!inventory.json().contains("selected"))
        inventory.place(nil, replacing: renamed, owner: owner)
        #expect(inventory.document().controls.isEmpty)
    }
}
