// MenuCommand.swift: the one menu item every app's command menus are built
// from (docs/design.md, no dead controls): a title with an optional symbol, an
// optional key equivalent, and help that says what it does or why it can't.
// A command that can't run is disabled, never hidden. Apps map their own
// command and reason types onto it with an `init` in an extension.
import SwiftUI

public struct MenuCommand: View {
    public let title: String
    public let systemImage: String?
    public let shortcut: KeyboardShortcut?
    public let help: String
    public let isEnabled: Bool
    public let perform: @MainActor () -> Void

    public init(
        _ title: String, systemImage: String? = nil, shortcut: KeyboardShortcut? = nil, help: String,
        isEnabled: Bool = true, perform: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.help = help
        self.isEnabled = isEnabled
        self.perform = perform
    }

    public var body: some View {
        Button(action: perform) {
            if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
        }
        .keyboardShortcut(shortcut)
        .disabled(!isEnabled)
        .help(help)
    }
}
