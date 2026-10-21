// UnsavedGuardTests.swift (adopt-kernel-unsaved-prompt UP-1, on since UP-3): the `.unsavedChangesGuard`
// modifier on an offscreen window with a fake document and a fake save. The close rules run through AppKit's
// real close path with a scripted answerer in `UnsavedHooks.ask`, so they need no sheet: Cancel keeps the window;
// Don't Save closes it; Save closes it only when the save lands; a clean window closes without asking; a second
// close while asking asks nothing more. The alert's buttons (ids `<prefix>.close.<answer>`, titles, Return, Escape,
// Command-D) are read off the NSAlert the sheet shows. One thin test puts the real sheet up and cancels it.
// The guard takes the window's delegate only once SwiftUI has built its view, a run-loop turn after the window is
// shown, so `FakeDocument.window()` waits for that before any test closes it; a close sent sooner closes the
// window with no question asked. Tests close with `requestClose` and press the sheet's button with `sendAction`,
// never `performClose` or `performClick`, whose nested event loops end the test host's run.
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

/// The fake document behind the guard: its dirty flag, what the save returns, how often it ran, and the
/// scripted answerer standing in for the sheet.
@MainActor
private final class FakeDocument {
    var dirty = true
    var saveLands = true
    var saves = 0
    /// The answer the fake asker gives; nil uses the real sheet.
    var answer: UnsavedPrompt.Answer?
    /// When set, the fake asker waits for `release` before answering (a question still up).
    var holds = false
    /// How often the guard asked.
    private(set) var asks = 0
    private var held: CheckedContinuation<Void, Never>?

    var hooks: UnsavedHooks {
        var hooks = UnsavedHooks(
            idPrefix: "fake", documentName: { "Poster" }, isDirty: { self.dirty },
            save: {
                self.saves += 1
                if self.saveLands { self.dirty = false }
                return self.saveLands
            })
        if let answer {
            hooks.ask = { _, _, _ in
                self.asks += 1
                if self.holds { await withCheckedContinuation { self.held = $0 } }
                return answer
            }
        }
        return hooks
    }

    /// Lets a held question answer.
    func release() {
        held?.resume()
        held = nil
    }

    /// An offscreen titled window hosting a guarded view, on screen so a close runs AppKit's real path.
    func window() async throws -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 320, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: Text("Poster").unsavedChangesGuard(hooks))
        window.orderFrontRegardless()
        try #require(window.isVisible, "the test window never reached the screen")
        let guarded = await eventually { window.delegate is UnsavedGuardDelegate }
        try #require(guarded, "the guard never took the window's delegate")
        return window
    }
}

/// Counts `window`'s closes (NSWindow.willCloseNotification).
@MainActor
private final class CloseWatch {
    private(set) var closes = 0
    nonisolated(unsafe) private var token: (any NSObjectProtocol)?

    init(_ window: NSWindow) {
        token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: nil
        ) { [weak self] _ in MainActor.assumeIsolated { self?.closes += 1 } }
    }

    deinit { token.map(NotificationCenter.default.removeObserver) }
}

/// What a click on the close button does, without the button's flash: `performClose` flashes it in a nested
/// event loop, which starts AppKit pulling window-server events, and once the test is back in the test host's
/// main run loop the next event stops that loop and the host exits mid-run with status 0.
@MainActor
private func requestClose(_ window: NSWindow) {
    if window.delegate?.windowShouldClose?(window) ?? true { window.close() }
}

/// Lets the main actor run until `condition` holds, at most `seconds`; returns whether it held.
@MainActor
private func eventually(_ seconds: Double = 2, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() {
        if Date() > deadline { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}

/// The button with accessibility id `fake.close.<answer>` under `root`, nil when there is none.
@MainActor
private func button(_ answer: String, under root: NSView?) -> NSButton? {
    var pending: [NSView] = root.map { [$0] } ?? []
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
    func cancelKeepsWindow() async throws {
        let document = FakeDocument()
        document.answer = .cancel
        let window = try await document.window()
        defer { window.close() }
        let watch = CloseWatch(window)
        requestClose(window)
        #expect(await eventually { document.asks == 1 }, "a dirty window closed without asking")
        try? await Task.sleep(for: .milliseconds(50))
        #expect(watch.closes == 0 && window.isVisible, "Cancel closed the window")
        #expect(document.dirty && document.saves == 0)
    }

    @Test("Don't Save closes the window without saving")
    func dontSaveCloses() async throws {
        let document = FakeDocument()
        document.answer = .dontSave
        let window = try await document.window()
        let watch = CloseWatch(window)
        requestClose(window)
        #expect(await eventually { watch.closes == 1 }, "Don't Save left the window open")
        #expect(document.asks == 1 && document.saves == 0)
    }

    @Test("Save closes the window once the save lands")
    func saveCloses() async throws {
        let document = FakeDocument()
        document.answer = .save
        let window = try await document.window()
        let watch = CloseWatch(window)
        requestClose(window)
        #expect(await eventually { watch.closes == 1 }, "a landed save left the window open")
        #expect(document.saves == 1)
    }

    @Test("A failed save keeps the window")
    func failedSaveKeepsWindow() async throws {
        let document = FakeDocument()
        document.answer = .save
        document.saveLands = false
        let window = try await document.window()
        defer { window.close() }
        let watch = CloseWatch(window)
        requestClose(window)
        #expect(await eventually { document.saves == 1 }, "Save didn't save")
        try? await Task.sleep(for: .milliseconds(50))
        #expect(watch.closes == 0 && window.isVisible, "a failed save closed the window")
        #expect(document.dirty)
    }

    @Test("A clean window closes without asking")
    func cleanWindowCloses() async throws {
        let document = FakeDocument()
        document.answer = .cancel
        document.dirty = false
        let window = try await document.window()
        let watch = CloseWatch(window)
        requestClose(window)
        #expect(watch.closes == 1, "a clean window didn't close")
        #expect(document.asks == 0, "a clean window asked before closing")
    }

    @Test("A second close while asking asks nothing more")
    func secondCloseAddsNoSheet() async throws {
        let document = FakeDocument()
        document.answer = .cancel
        document.holds = true
        let window = try await document.window()
        defer { window.close() }
        requestClose(window)
        #expect(await eventually { document.asks == 1 })
        requestClose(window)
        #expect(!(await UnsavedGuard.proceed(document.hooks, in: window)), "Open went on while the window asked")
        try? await Task.sleep(for: .milliseconds(50))
        #expect(document.asks == 1, "the second close asked again")
        document.release()
        #expect(await eventually { !UnsavedGuard.isAsking(in: window) })
        #expect(window.isVisible && document.dirty)
    }

    @Test("Return saves, Escape cancels, Command-D is Don't Save")
    func keys() {
        let alert = UnsavedGuard.alert(for: "Poster", prefix: "fake")
        #expect(alert.messageText == UnsavedPrompt.message(for: "Poster"))
        let root = alert.window.contentView
        let save = button("save", under: root), dontSave = button("dontSave", under: root)
        let cancel = button("cancel", under: root)
        #expect(alert.buttons == [save, dontSave, cancel].compactMap { $0 }, "the buttons aren't in answers order")
        #expect(save?.keyEquivalent == "\r")
        #expect(cancel?.keyEquivalent == "\u{1b}")
        #expect(dontSave?.keyEquivalent == "d")
        #expect(dontSave?.keyEquivalentModifierMask == .command)
        #expect(save?.title == UnsavedPrompt.title(of: .save))
        #expect(dontSave?.title == UnsavedPrompt.title(of: .dontSave))
        #expect(cancel?.title == UnsavedPrompt.title(of: .cancel))
    }

    @Test("A close puts the real sheet up and its Cancel takes it down")
    func realSheet() async throws {
        let document = FakeDocument()
        let window = try await document.window()
        defer { window.close() }
        requestClose(window)
        #expect(await eventually { window.attachedSheet != nil }, "a dirty window closed without a sheet")
        let cancel = button("cancel", under: window.attachedSheet?.contentView)
        #expect(cancel != nil, "the sheet has no Cancel button")
        if let cancel { cancel.sendAction(cancel.action, to: cancel.target) }
        #expect(await eventually { window.attachedSheet == nil }, "Cancel left the sheet up")
        #expect(window.isVisible && document.dirty && document.saves == 0)
    }
}

