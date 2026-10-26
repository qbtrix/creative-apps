// InlineNotice.swift: the one notice row every app shows in place, at the top
// of a content area (Library's import result, catalog problem and refused cull
// change; the AfterGlow home's missing or removed file). A kind's symbol in
// its state color (docs/design.md, States), one sentence, the caller's
// buttons, an optional close, and optional detail lines under the sentence
// (an import's `name: reason` failures). Content layer, flat, never glass.
//
// `band` draws it as a full-width row with its own inset on the panel fill,
// for a notice that sits on a content area's top edge; false draws it bare,
// for a notice inside an already padded column (the home's recents).
//
// The caller's buttons go in the `actions` slot so each keeps its own
// identifier and control listing (a MenuCommand, a `.suiteControl` button).
// The close is drawn here from its ToolbarAction: icon only, disabled with
// its reason while unavailable, registered in `suite.controls`. The row is
// one containing accessibility element named `identifier`, so a journey finds
// the sentence and the buttons inside it.
import SwiftUI

/// What a notice reports: its symbol and state color.
public enum NoticeKind: Sendable, Hashable {
    case info, success, warning, error

    public var symbol: String {
        switch self {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "exclamationmark.octagon"
        }
    }

    public var color: Color {
        switch self {
        case .info: SuiteColor.textSecondary
        case .success: SuiteColor.stateSuccess
        case .warning: SuiteColor.stateWarning
        case .error: SuiteColor.stateError
        }
    }
}

public struct InlineNotice<Actions: View>: View {
    nonisolated public static var closeHelp: String { "Close the notice." }

    public let message: String
    public let kind: NoticeKind
    public let systemImage: String
    public let identifier: String
    public let close: ToolbarAction?
    public let detail: [String]
    public let band: Bool
    private let actions: Actions

    /// `systemImage` replaces the kind's symbol (the home's removed file shows a trash can).
    public init(
        _ message: String, kind: NoticeKind, systemImage: String? = nil, identifier: String,
        close: ToolbarAction? = nil, detail: [String] = [], band: Bool = true, @ViewBuilder actions: () -> Actions
    ) {
        self.message = message
        self.kind = kind
        self.systemImage = systemImage ?? kind.symbol
        self.identifier = identifier
        self.close = close
        self.detail = detail
        self.band = band
        self.actions = actions()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            HStack(spacing: SuiteSpacing.s) {
                Label(message, systemImage: systemImage)
                    .font(SuiteFont.caption)
                    .foregroundStyle(kind.color)
                    .lineLimit(2)
                Spacer(minLength: SuiteSpacing.s)
                actions
                if let close {
                    Button(close.title, systemImage: close.systemImage, action: close.perform)
                        .labelStyle(.iconOnly)
                        .help(close.isEnabled ? Self.closeHelp : close.help)
                        .disabled(!close.isEnabled)
                        .suiteControl(close)
                }
            }
            ForEach(Array(detail.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .modifier(Band(on: band))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private struct Band: ViewModifier {
        let on: Bool

        func body(content: Content) -> some View {
            if on {
                content
                    .padding(.horizontal, SuiteSpacing.m)
                    .padding(.vertical, SuiteSpacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SuiteColor.panel)
            } else {
                content
            }
        }
    }
}

extension InlineNotice where Actions == EmptyView {
    /// A notice with no buttons of the caller's own.
    public init(
        _ message: String, kind: NoticeKind, systemImage: String? = nil, identifier: String,
        close: ToolbarAction? = nil, detail: [String] = [], band: Bool = true
    ) {
        self.init(message, kind: kind, systemImage: systemImage, identifier: identifier, close: close,
                  detail: detail, band: band) { EmptyView() }
    }
}
