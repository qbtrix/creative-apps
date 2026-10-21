// MenuCommand+Catalog.swift (command-catalog CC-9): the one way a menu item
// or toolbar button is built from an app's command catalog. The spec gives
// the title; the spec's availability on the target decides whether it is
// enabled; the help is the spec's summary, or "<title>: <why>" when the
// command can't run, so a disabled item always says why (no dead controls).
// `title` overrides the spec's when the item names more, as an Edit menu's
// "Undo Add Rectangle" does.
import SuiteKernel
import SwiftUI

extension MenuCommand {
    public init<T>(
        _ spec: CommandSpec<T>, on target: T, title: String? = nil, systemImage: String? = nil,
        shortcut: KeyboardShortcut? = nil, role: ButtonRole? = nil, perform: @escaping @MainActor () -> Void
    ) {
        let name = title ?? spec.title
        let why = spec.availability(target).why
        self.init(name, systemImage: systemImage, shortcut: shortcut, help: why.map { "\(name): \($0)" } ?? spec.summary,
                  isEnabled: why == nil, role: role, perform: perform)
    }
}
