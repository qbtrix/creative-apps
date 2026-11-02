// MenuCommand+TextField.swift (editor-menus, #4830): the one way an editor's
// Edit item gives way to a focused text field. An app that replaces the
// system's pasteboard or undo group wraps its item, `item.givingWay(to: .copy)`:
// while a text field (the window's field editor) or an editable text view is
// the key window's first responder, the item stays enabled and sends the
// field's own copy:, down the responder chain, so ⌘X, ⌘C, ⌘V, ⌘A, ⌘Z and ⇧⌘Z
// act on the text; otherwise it is the app's item, as the app built it.
// SuiteModel's TextFieldEditRouting decides; SuiteTextFocus re-reads the first
// responder on every window update (NSWindow.didUpdateNotification), so the
// menu re-reads as focus moves, and the action reads it again when it runs.
import AppKit
import SuiteModel
import SwiftUI

/// The key window's text focus, kept current from every window update.
@MainActor @Observable public final class SuiteTextFocus {
    public static let shared = SuiteTextFocus()
    public private(set) var focus = TextFocus.none
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { SuiteTextFocus.shared.refresh() }
        }
    }

    /// What the key window's first responder is now: a field editor or text view, or nothing textual.
    public static func probe() -> TextFocus {
        guard let text = NSApp.keyWindow?.firstResponder as? NSText else { return .none }
        return TextFocus(isText: true, isEditable: text.isEditable, isFieldEditor: text.isFieldEditor)
    }

    /// Runs `command`'s item: the focused field's own action, else the app's while its item can run.
    public static func run(_ command: TextEditCommand, item: MenuCommand) {
        let now = TextFieldEditRouting.item(command, focus: probe(), appEnabled: item.isEnabled, appHelp: item.help)
        switch now.route {
        case .field(let action): _ = NSApp.sendAction(Selector(action), to: nil, from: nil)
        case .app: if now.isEnabled { item.perform() }
        }
    }

    private func refresh() {
        let now = Self.probe()
        if now != focus { focus = now }
    }
}

/// An Edit item that gives way to a focused text field (`MenuCommand.givingWay(to:)`).
public struct TextFieldEditItem: View {
    let command: TextEditCommand
    let item: MenuCommand

    public var body: some View {
        let entry = TextFieldEditRouting.item(
            command, focus: SuiteTextFocus.shared.focus, appEnabled: item.isEnabled, appHelp: item.help)
        let command = command, item = item
        MenuCommand(
            item.title, systemImage: item.systemImage, shortcut: item.shortcut, help: entry.help,
            isEnabled: entry.isEnabled, role: item.role
        ) { SuiteTextFocus.run(command, item: item) }
    }
}

extension MenuCommand {
    /// This item, handing `command` to a focused text field: on while the field has focus, and acting on its text.
    public func givingWay(to command: TextEditCommand) -> TextFieldEditItem {
        TextFieldEditItem(command: command, item: self)
    }
}
