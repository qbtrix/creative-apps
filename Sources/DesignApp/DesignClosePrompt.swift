// DesignClosePrompt.swift: the close prompt on a Design window's root (#275).
// An invisible view puts DesignCloseGuard in front of the window's delegate. A
// close (File > Close, Command-W, the title bar's close button) of a window
// whose Model has a `closePrompt` waits for a sheet that asks it: Save, Don't
// Save (Command-D) or Cancel. Save runs File > Save in that window, which is
// key by then, so a new file gets the Save panel; the window closes once the
// Model reads clean and stays open when the save fails (the window shows why)
// or the panel is cancelled. Don't Save closes; Cancel keeps the window. A clean
// window closes at once. An NSAlert, since SwiftUI drops alert buttons'
// identifiers and the journeys find them by `design.close.*`.
import AppKit
import DesignModel
import SwiftUI

struct DesignClosePrompt: ViewModifier {
    let model: DesignWorkspace

    func body(content: Content) -> some View {
        content.background(DesignCloseGuardHost(prompt: model.closePrompt))
    }
}

private struct DesignCloseGuardHost: NSViewRepresentable {
    let prompt: String?

    func makeNSView(context: Context) -> DesignCloseGuardView { DesignCloseGuardView() }

    func updateNSView(_ view: DesignCloseGuardView, context: Context) { view.update(prompt) }
}

/// Holds the window's current close prompt and keeps the guard on its window.
final class DesignCloseGuardView: NSView {
    private(set) var prompt: String?
    private let closeGuard = DesignCloseGuard()

    func update(_ prompt: String?) {
        self.prompt = prompt
        attach()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    /// Never takes a click from the window's content.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func attach() {
        guard let window, window.delegate !== closeGuard else { return }
        closeGuard.original = window.delegate
        closeGuard.view = self
        window.delegate = closeGuard
    }
}

/// The window's delegate in front of SwiftUI's: asks before an edited window closes and
/// hands every other delegate call to SwiftUI's.
@MainActor final class DesignCloseGuard: NSObject, NSWindowDelegate {
    /// SwiftUI's delegate; AppKit asks `responds(to:)` on the main thread.
    nonisolated(unsafe) weak var original: (any NSWindowDelegate)?
    weak var view: DesignCloseGuardView?
    /// The sheet is up, or its answer is closing the window.
    private var asking = false, answered = false

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if asking { return false }
        guard !answered, let prompt = view?.prompt else { return original?.windowShouldClose?(sender) ?? true }
        asking = true
        Task {
            let closes = await ask(prompt, in: sender)
            asking = false
            guard closes else { return }
            answered = true
            sender.performClose(nil)
            answered = false
        }
        return false
    }

    /// Shows the prompt on `window`; true when the window may close.
    private func ask(_ prompt: String, in window: NSWindow) async -> Bool {
        window.makeKeyAndOrderFront(nil)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = prompt
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save").setAccessibilityIdentifier("design.close.save")
        let discard = alert.addButton(withTitle: "Don't Save")
        discard.hasDestructiveAction = true
        discard.keyEquivalent = "d"
        discard.keyEquivalentModifierMask = .command
        discard.setAccessibilityIdentifier("design.close.dont-save")
        alert.addButton(withTitle: "Cancel").setAccessibilityIdentifier("design.close.cancel")
        switch await alert.beginSheetModal(for: window) {
        case .alertFirstButtonReturn: return await saved()
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }

    /// Runs File > Save in the key window and waits up to 2 s for the Model to read clean.
    private func saved() async -> Bool {
        guard let item = Self.saveItem(in: NSApp.mainMenu), let menu = item.menu else { return false }
        menu.performActionForItem(at: menu.index(of: item))
        for _ in 0..<40 {
            if view?.prompt == nil { return true }
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return false }
        }
        return false
    }

    /// The menu bar's Save (Command-S).
    private static func saveItem(in menu: NSMenu?) -> NSMenuItem? {
        for item in menu?.items ?? [] {
            if item.keyEquivalent == "s", item.keyEquivalentModifierMask == .command { return item }
            if let found = saveItem(in: item.submenu) { return found }
        }
        return nil
    }

    nonisolated override func responds(to selector: Selector!) -> Bool {
        if super.responds(to: selector) { return true }
        return original?.responds(to: selector) ?? false
    }

    nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
        if let original, original.responds(to: selector) { return original }
        return super.forwardingTarget(for: selector)
    }
}
