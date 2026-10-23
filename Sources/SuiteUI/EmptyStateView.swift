// EmptyStateView.swift: what a pane shows when it has nothing to show. Built
// on the system ContentUnavailableView. Says what to do next and, when there
// is one, offers the button that does it: the one primary button, the system
// bordered prominent style filled with `accentFill` (white text at 5.05:1),
// listed in `suite.controls` with role "primary" when it has an identifier;
// disabled, saying why, while it can't run. With no action there is no button.
// An optional `secondary` action (a quieter way in, such as sample content)
// sits beside it as a plain bordered button, listed with no role. With
// `onDrop` the whole pane is a drop target for files and folders: while a
// drag hovers it, an accent outline lights its edge, and `onDrop` gets the
// dropped file URLs and says whether it took them.
import SwiftUI

public struct EmptyStateView: View {
    private let title: String
    private let systemImage: String
    private let message: String
    private let action: ToolbarAction?
    private let secondary: ToolbarAction?
    private let onDrop: (@MainActor ([URL]) -> Bool)?
    @State private var dropTargeted = false

    public init(
        _ title: String, systemImage: String, message: String, action: ToolbarAction? = nil,
        secondary: ToolbarAction? = nil, onDrop: (@MainActor ([URL]) -> Bool)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.action = action
        self.secondary = secondary
        self.onDrop = onDrop
    }

    /// The role the primary button registers with in `suite.controls`.
    static let primaryRole = "primary"

    /// The action the primary button runs; nil when the view draws no button.
    var primaryAction: ToolbarAction? { action }

    public var body: some View {
        // Only a pane that takes drops is a drop destination; the rest don't show the copy pointer.
        if let onDrop {
            pane
                .overlay {
                    if dropTargeted {
                        RoundedRectangle(cornerRadius: SuiteRadius.large)
                            .strokeBorder(SuiteColor.accent, lineWidth: SuiteSize.focusRing)
                            .padding(SuiteSpacing.m)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    let files = urls.filter(\.isFileURL)
                    return !files.isEmpty && onDrop(files)
                } isTargeted: { dropTargeted = $0 }
        } else {
            pane
        }
    }

    private var pane: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            // The system description color measured 3.95:1 on the window background.
            Text(message).foregroundStyle(SuiteColor.secondaryText)
        } actions: {
            // One button stays bare, so a single action lays out as it always has.
            if let secondary {
                HStack(spacing: SuiteSpacing.s) {
                    primaryButton
                    Button(secondary.title, action: secondary.perform)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(!secondary.isEnabled)
                        .help(secondary.help)
                        .suiteControl(secondary)
                }
            } else {
                primaryButton
            }
        }
    }

    @ViewBuilder private var primaryButton: some View {
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
