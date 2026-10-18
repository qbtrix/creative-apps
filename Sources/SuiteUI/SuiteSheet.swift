// SuiteSheet.swift: the one frame every app sheet (New, Export, Image Size,
// Straighten) is drawn in: the title, the app's fields, an optional caption
// note and an optional problem (error color, exclamation circle), then Cancel
// (Escape) and the confirm button (Return), right-aligned. A confirm that
// can't act is disabled, its help saying why. `.standard` is the narrow
// settings sheet (headline title, inspector width); `.wide` the New Document
// sheet (title type, content width, more air). The app passes each button's
// identifier, so journeys keep finding them.
import SwiftUI

public struct SuiteSheet<Content: View>: View {
    public enum Width: Sendable {
        case standard, wide
    }

    /// The confirm button: its title, identifier, help and whether it can act.
    public struct Confirm {
        public let title: String
        public let identifier: String
        public let help: String
        public let isEnabled: Bool
        public let perform: @MainActor () -> Void

        public init(
            _ title: String, identifier: String, help: String, isEnabled: Bool = true,
            perform: @escaping @MainActor () -> Void
        ) {
            self.title = title
            self.identifier = identifier
            self.help = help
            self.isEnabled = isEnabled
            self.perform = perform
        }
    }

    private let title: String
    private let width: Width
    private let note: String?
    private let problem: String?
    private let cancelIdentifier: String
    private let confirm: Confirm?
    private let onCancel: @MainActor () -> Void
    private let content: Content

    public init(
        _ title: String, width: Width = .standard, note: String? = nil, problem: String? = nil,
        cancelIdentifier: String, confirm: Confirm? = nil, onCancel: @escaping @MainActor () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.width = width
        self.note = note
        self.problem = problem
        self.cancelIdentifier = cancelIdentifier
        self.confirm = confirm
        self.onCancel = onCancel
        self.content = content()
    }

    public var body: some View {
        let wide = width == .wide
        VStack(alignment: .leading, spacing: wide ? SuiteSpacing.l : SuiteSpacing.m) {
            Text(title).font(wide ? SuiteFont.title : SuiteFont.headline)
            content
            if let note {
                Text(note)
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
            if let problem {
                Label(problem, systemImage: "exclamationmark.circle")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.stateError)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(cancelIdentifier)
                if let confirm {
                    Button(confirm.title, action: confirm.perform)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!confirm.isEnabled)
                        .help(confirm.help)
                        .accessibilityIdentifier(confirm.identifier)
                }
            }
        }
        .padding(wide ? SuiteSpacing.xl : SuiteSpacing.l)
        .frame(width: wide ? SuiteSize.contentMinimum.width : SuiteSize.inspectorWidth.max)
    }
}
