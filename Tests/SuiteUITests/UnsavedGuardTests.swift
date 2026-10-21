// UnsavedGuardTests.swift (adopt-kernel-unsaved-prompt UP-1, on since UP-3): the `.unsavedChangesGuard`
// modifier on an offscreen window with a fake document and a fake save. Cancel keeps the window; Don't Save closes
// it; Save closes it only when the save lands; a clean window closes with no sheet; a second close while asking
// adds no sheet; Return saves, Escape cancels and Command-D is Don't Save. The sheet's buttons are found by their
// ids (`<prefix>.close.<answer>`, UnsavedPrompt.answers) and clicked with `performClick`.
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

/// The fake document behind the guard: its dirty flag, what the save returns and how often it ran.
@MainActor
private final class FakeDocument {
    var dirty = true
    var saveLands = true
    var saves = 0

    var hooks: UnsavedHooks {
        UnsavedHooks(
            idPrefix: "fake", documentName: { "Poster" }, isDirty: { self.dirty },
            save: {
                self.saves += 1
                if self.saveLands { self.dirty = false }
                return self.saveLands
            })
    }

    /// An offscreen titled window hosting a guarded view, shown so a sheet can attach.
    func window() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 320, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: Text("Poster").unsavedChangesGuard(hooks))
        window.orderFront(nil)
        return window
    }
}

/// Spins the main run loop until `condition` holds, at most `seconds`; returns whether it held.
@MainActor
private func eventually(_ seconds: Double = 2, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() {
        if Date() > deadline { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}

/// The button with accessibility id `fake.close.<answer>` in the window's sheet, nil when there is none.
@MainActor
private func button(_ answer: String, in window: NSWindow) -> NSButton? {
    guard let root = window.attachedSheet?.contentView else { return nil }
    var pending: [NSView] = [root]
    while let view = pending.popLast() {
        if let found = view as? NSButton, found.accessibilityIdentifier() == "fake.close.\(answer)" { return found }
        pending.append(contentsOf: view.subviews)
    }
    return nil
}

@MainActor
@Suite("UnsavedGuard")
struct UnsavedGuardTests {
    @Test("Cancel keeps the window, still dirty")
    func cancelKeepsWindow() async {
        let document = FakeDocument()
        let window = document.window()
        window.performClose(nil)
        #expect(await eventually { window.attachedSheet != nil }, "a dirty window closed without a sheet")
        button("cancel", in: window)?.performClick(nil)
        #expect(await eventually { window.attachedSheet == nil }, "Cancel left the sheet up")
        #expect(window.isVisible, "Cancel closed the window")
        #expect(document.dirty && document.saves == 0)
    }

    @Test("Don't Save closes the window without saving")
    func dontSaveCloses() async {
        let document = FakeDocument()
        let window = document.window()
        window.performClose(nil)
        #expect(await eventually { window.attachedSheet != nil })
        button("dontSave", in: window)?.performClick(nil)
        #expect(await eventually { !window.isVisible }, "Don't Save left the window open")
        #expect(document.saves == 0)
    }

    @Test("Save closes the window once the save lands")
    func saveCloses() async {
        let document = FakeDocument()
        let window = document.window()
        window.performClose(nil)
        #expect(await eventually { window.attachedSheet != nil })
        button("save", in: window)?.performClick(nil)
        #expect(await eventually { !window.isVisible }, "a landed save left the window open")
        #expect(document.saves == 1)
    }

    @Test("A failed save keeps the window")
    func failedSaveKeepsWindow() async {
        let document = FakeDocument()
        document.saveLands = false
        let window = document.window()
        window.performClose(nil)
        #expect(await eventually { window.attachedSheet != nil })
        button("save", in: window)?.performClick(nil)
        #expect(await eventually { document.saves == 1 })
        #expect(await eventually { window.attachedSheet == nil })
        #expect(window.isVisible, "a failed save closed the window")
        #expect(document.dirty)
    }

    @Test("A clean window closes with no sheet")
    func cleanWindowCloses() async {
        let document = FakeDocument()
        document.dirty = false
        let window = document.window()
        window.performClose(nil)
        #expect(await eventually { !window.isVisible }, "a clean window didn't close")
        #expect(window.sheets.isEmpty, "a clean window asked before closing")
    }

    @Test("A second close while asking adds no sheet")
    func secondCloseAddsNoSheet() async {
        let document = FakeDocument()
        let window = document.window()
        window.performClose(nil)
        #expect(await eventually { window.attachedSheet != nil })
        window.performClose(nil)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(window.sheets.count == 1, "the second close added a sheet")
        button("cancel", in: window)?.performClick(nil)
    }

    @Test("Return saves, Escape cancels, Command-D is Don't Save")
    func keys() async {
        let document = FakeDocument()
        let window = document.window()
        window.performClose(nil)
        #expect(await eventually { window.attachedSheet != nil })
        let save = button("save", in: window), dontSave = button("dontSave", in: window)
        let cancel = button("cancel", in: window)
        #expect(save?.keyEquivalent == "\r")
        #expect(cancel?.keyEquivalent == "\u{1b}")
        #expect(dontSave?.keyEquivalent == "d")
        #expect(dontSave?.keyEquivalentModifierMask == .command)
        #expect(save?.title == UnsavedPrompt.title(of: .save))
        #expect(dontSave?.title == UnsavedPrompt.title(of: .dontSave))
        #expect(cancel?.title == UnsavedPrompt.title(of: .cancel))
        cancel?.performClick(nil)
    }
}
