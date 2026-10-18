// EmptyStateView.swift: what a pane shows when it has nothing to show. Built
// on the system ContentUnavailableView. Says what to do next and, when there
// is one, offers the button that does it: the one primary button, the system
// bordered prominent style filled with `accentFill` (white text at 5.05:1),
// listed in `suite.controls` with role "primary" when it has an identifier;
// disabled, saying why, while it can't run. With no action there is no button.
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

    /// The role the button registers with in `suite.controls`.
    static let primaryRole = "primary"

    /// The action the primary button runs; nil when the view draws no button.
    var primaryAction: ToolbarAction? { action }

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
                    .tint(SuiteColor.accentFill)
                    .controlSize(.large)
                    .disabled(!action.isEnabled)
                    .help(action.help)
                    .suiteControl(action, role: Self.primaryRole)
            }
        }
    }
}
