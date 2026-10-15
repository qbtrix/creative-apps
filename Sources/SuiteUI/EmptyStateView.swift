// EmptyStateView.swift: what a pane shows when it has nothing to show. Built
// on the system ContentUnavailableView. Says what to do next and, when there
// is one, offers the button that does it (the one prominent action, listed in
// `suite.controls` with role "primary" when it has an identifier; disabled,
// saying why, while it can't run).
import SwiftUI

public struct EmptyStateView: View {
    private let title: String
    private let systemImage: String
    private let message: String
    private let action: ToolbarAction?

    public init(_ title: String, systemImage: String, message: String, action: ToolbarAction? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            // The system description color measured 3.95:1 on the window background.
            Text(message).foregroundStyle(SuiteColor.secondaryText)
        } actions: {
            if let action {
                Button(action.title, action: action.perform)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!action.isEnabled)
                    .help(action.help)
                    .suiteControl(action, role: "primary")
            }
        }
    }
}
