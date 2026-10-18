// EditorSaveStatus.swift: the one save status an editor shows (EC-4, #339):
// "Saved" in secondary text, an accent dot and the title while unsaved, and a
// triangle and the title in the error color after a failed save. It is inset
// like a bar button and never truncates. The app passes the title, the tooltip
// (what the status means and what to do next, also the accessibility hint)
// and its identifier; journeys read the label, which is the title.
import SwiftUI

public struct EditorSaveStatus: View {
    public enum State: Sendable {
        case saved, edited, notSaved
    }

    public let state: State
    public let title: String
    public let help: String
    public let identifier: String

    public init(_ state: State, title: String, help: String, identifier: String) {
        self.state = state
        self.title = title
        self.help = help
        self.identifier = identifier
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            switch state {
            case .saved: EmptyView()
            case .edited:
                Image(systemName: "circle.fill")
                    .resizable()
                    .frame(width: SuiteSize.statusDot, height: SuiteSize.statusDot)
                    .foregroundStyle(SuiteColor.accent)
            case .notSaved: Image(systemName: "exclamationmark.triangle.fill")
            }
            Text(title)
        }
        .foregroundStyle(state == .notSaved ? SuiteColor.stateError : SuiteColor.textSecondary)
        .padding(SuiteInset.barButton)
        .fixedSize()
        .help(help)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(title)
        .accessibilityHint(help)
        .accessibilityIdentifier(identifier)
    }
}
