// SuiteSheetTests.swift: SuiteUI's SuiteSheet (#3964), the one titled sheet
// frame with Cancel and one default action. The default button is the host's
// MenuCommand on Return; a host reason, or the command's own unavailability,
// disables it and becomes its help. Hosted, Cancel and the action list under
// the ids the host passed, the disabled one with its reason. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor @Suite struct SuiteSheetTests {
    @Test func theDefaultButtonIsTheHostsCommandOnReturn() {
        var ran = 0
        let resize = MenuCommand("Resize", help: "Resample every layer.") { ran += 1 }
        let shown = SuiteSheet<EmptyView>.defaultCommand(resize, reason: nil)
        #expect(shown.title == "Resize" && shown.shortcut == .defaultAction)
        #expect(shown.isEnabled && shown.help == "Resample every layer.")
        shown.perform()
        #expect(ran == 1)
    }

    @Test func aHostReasonDisablesTheDefaultAndSaysWhy() {
        let resize = MenuCommand("Resize", help: "Resample every layer.") {}
        let shown = SuiteSheet<EmptyView>.defaultCommand(resize, reason: "Type each side as a whole number of pixels.")
        #expect(!shown.isEnabled && shown.help == "Type each side as a whole number of pixels.")
        let off = MenuCommand("Restore…", help: "Restore…: There are no backups yet.", isEnabled: false) {}
        let still = SuiteSheet<EmptyView>.defaultCommand(off, reason: nil)
        #expect(!still.isEnabled && still.help == "Restore…: There are no backups yet.")
    }

    /// Cancel, the action and the message carry the host's ids; the disabled action lists its reason.
    @Test func hostedSheetRegistersTheHostsIDs() {
        let store = SuiteControlStore()
        let sheet = SuiteSheet(
            "Image Size", message: "Now 640 × 480 px.", messageID: "test.sheet.message",
            cancelID: "test.sheet.cancel", onCancel: {},
            action: MenuCommand("Resize", help: "Resample every layer.") {}, actionID: "test.sheet.resize",
            reason: "Type each side as a whole number of pixels."
        ) {
            Text(verbatim: "Fields")
        }
        host(sheet.environment(\.suiteControlStore, store))
        let controls = store.inventory.document().controls
        let cancel = controls.first { $0.id == "test.sheet.cancel" }
        let resize = controls.first { $0.id == "test.sheet.resize" }
        #expect(cancel?.enabled == true)
        #expect(resize?.enabled == false && resize?.reason == "Type each side as a whole number of pixels.")
        #expect(resize?.role == "primary")
        #expect(store.inventory.violations().isEmpty, "\(store.inventory.violations())")
    }

    @MainActor private func host(_ view: some View) {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
    }
}
