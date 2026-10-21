// UnsavedGuard.swift (adopt-kernel-unsaved-prompt UP-1 contract, UP-3 bodies): the one asker every editor uses
// before unsaved work goes away. The words and answers are the kernel's `UnsavedPrompt`; the dirty rule is the
// app's `DocumentSession`. `.unsavedChangesGuard` puts a delegate proxy in front of the hosting window's delegate,
// so a close (File > Close, Command-W, the close button) of a dirty window waits for a sheet: Save (Return),
// Don't Save (Command-D) or Cancel (Escape). The window closes only after Don't Save or a save that landed; a
// clean window closes at once, and a second close while the sheet is up adds no sheet. `proceed` asks the same
// sheet before Open, New or Quit replaces the document. An NSAlert, since SwiftUI drops alert buttons' ids and
// the journeys find them by `<prefix>.close.<answer>`. Design's and Photo's proven guard, now in one place.
// `UnsavedHooks.ask` is the one seam between the decision and the sheet: the app never sets it (the real sheet);
// a test sets a fake answerer, so the close and proceed rules run without a window server.
import AppKit
import SuiteKernel
import SwiftUI

/// What the guard reads from the app's document: its button id prefix, its name, its dirty state and its save.
public struct UnsavedHooks {
    /// The prefix of the sheet's button ids: "design" gives `design.close.save`, `design.close.dontSave`, ….
    public var idPrefix: String
    /// The document's name for the message; nil when there is nothing to ask about.
    public var documentName: @MainActor () -> String?
    /// Whether the document has edits no save has written (the app's DocumentSession).
    public var isDirty: @MainActor () -> Bool
    /// Saves the document; true only when the save landed.
    public var save: @MainActor () async -> Bool
    /// Puts the question to the user and returns the answer: the real sheet unless a test swaps it.
    var ask: UnsavedGuard.Ask = UnsavedGuard.sheet

    /// Hooks for one document window.
    public init(
        idPrefix: String, documentName: @escaping @MainActor () -> String?,
        isDirty: @escaping @MainActor () -> Bool, save: @escaping @MainActor () async -> Bool
    ) {
        self.idPrefix = idPrefix
        self.documentName = documentName
        self.isDirty = isDirty
        self.save = save
    }
}

/// Asks Save, Don't Save or Cancel before a dirty document is closed, replaced or quit.
public enum UnsavedGuard {
    /// Asks about the document `name` on `window` (modally when nil) with button ids under `prefix`.
    typealias Ask = @MainActor (_ name: String, _ prefix: String, _ window: NSWindow?) async -> UnsavedPrompt.Answer

    /// The windows with a sheet up: one sheet at a time per window.
    @MainActor private static var asking = Set<ObjectIdentifier>()

    /// Before Open, New or Quit replaces the document: true when it may go on.
    /// Clean, or no name: go on. Else the sheet on `window` (a modal alert when there is none): Save goes on only
    /// when the save lands, Don't Save goes on, Cancel stops. A window already asking stops.
    @MainActor public static func proceed(_ hooks: UnsavedHooks, in window: NSWindow?) async -> Bool {
        guard hooks.isDirty(), let name = hooks.documentName() else { return true }
        let key = window.map(ObjectIdentifier.init)
        if let key, !asking.insert(key).inserted { return false }
        defer { if let key { asking.remove(key) } }
        switch await hooks.ask(name, hooks.idPrefix, window) {
        case .save: return await hooks.save()
        case .dontSave: return true
        case .cancel: return false
        }
    }

    /// True while `window` shows the unsaved sheet.
    @MainActor static func isAsking(in window: NSWindow) -> Bool { asking.contains(ObjectIdentifier(window)) }

    /// The button id for `answer`: `<prefix>.close.save`, `.dontSave` or `.cancel`.
    nonisolated static func identifier(_ answer: UnsavedPrompt.Answer, prefix: String) -> String {
        switch answer {
        case .save: "\(prefix).close.save"
        case .dontSave: "\(prefix).close.dontSave"
        case .cancel: "\(prefix).close.cancel"
        }
    }

    /// The warning alert in the kernel's words, its buttons in `UnsavedPrompt.answers` order.
    @MainActor static func alert(for name: String, prefix: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = UnsavedPrompt.message(for: name)
        alert.informativeText = UnsavedPrompt.informativeText
        for answer in UnsavedPrompt.answers {
            let button = alert.addButton(withTitle: UnsavedPrompt.title(of: answer))
            button.setAccessibilityIdentifier(identifier(answer, prefix: prefix))
            switch answer {
            case .save:
                button.keyEquivalent = "\r"
            case .dontSave:
                button.hasDestructiveAction = true
                button.keyEquivalent = "d"
                button.keyEquivalentModifierMask = .command
            case .cancel:
                button.keyEquivalent = "\u{1b}"
            }
        }
        return alert
    }

    /// The real asker: the alert as a sheet on `window`, or modally when there is none; the button pressed.
    @MainActor static func sheet(name: String, prefix: String, window: NSWindow?) async -> UnsavedPrompt.Answer {
        let alert = alert(for: name, prefix: prefix)
        let response: NSApplication.ModalResponse
        if let window {
            window.makeKeyAndOrderFront(nil)
            response = await alert.beginSheetModal(for: window)
        } else {
            response = alert.runModal()
        }
        return UnsavedPrompt.answer(
            forButton: response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
    }
}

extension View {
    /// Puts the guard in front of the hosting window's delegate, so close, Command-W and the close button ask.
    public func unsavedChangesGuard(_ hooks: UnsavedHooks) -> some View {
        background(UnsavedGuardHost(hooks: hooks))
    }
}

/// The invisible view that carries the hooks to the window.
private struct UnsavedGuardHost: NSViewRepresentable {
    let hooks: UnsavedHooks

    func makeNSView(context: Context) -> UnsavedGuardView { UnsavedGuardView(hooks: hooks) }

    func updateNSView(_ view: UnsavedGuardView, context: Context) { view.update(hooks) }
}

/// Holds the window's current hooks and keeps the delegate proxy on its window (a window's delegate is weak).
final class UnsavedGuardView: NSView {
    private let proxy: UnsavedGuardDelegate

    init(hooks: UnsavedHooks) {
        proxy = UnsavedGuardDelegate(hooks: hooks)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    func update(_ hooks: UnsavedHooks) {
        proxy.hooks = hooks
        attach()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    /// Never takes a click from the window's content.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func attach() {
        guard let window, window.delegate !== proxy else { return }
        proxy.original = window.delegate
        window.delegate = proxy
    }
}

/// The window's delegate in front of the original (SwiftUI's): asks before a dirty window closes and hands every
/// other delegate call to the original.
@MainActor final class UnsavedGuardDelegate: NSObject, NSWindowDelegate {
    /// The original delegate; AppKit asks `responds(to:)` on the main thread.
    nonisolated(unsafe) weak var original: (any NSWindowDelegate)?
    var hooks: UnsavedHooks
    /// A close is waiting on the sheet.
    private var pending = false

    init(hooks: UnsavedHooks) { self.hooks = hooks }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if pending || UnsavedGuard.isAsking(in: sender) { return false }
        guard hooks.isDirty(), hooks.documentName() != nil else {
            return original?.windowShouldClose?(sender) ?? true
        }
        pending = true
        let hooks = hooks
        Task {
            let closes = await UnsavedGuard.proceed(hooks, in: sender)
            pending = false
            // The same should-close check performClose makes, without its close-button flash: the flash runs a
            // nested event loop, which in a `swift test` host ends the host's main run loop and the test run.
            guard closes, original?.windowShouldClose?(sender) ?? true else { return }
            sender.close()
        }
        return false
    }

    nonisolated override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || original?.responds(to: selector) == true
    }

    nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
        original?.responds(to: selector) == true ? original : super.forwardingTarget(for: selector)
    }
}
