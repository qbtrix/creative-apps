// InspectorNote.swift: the one short note under an inspector's or a panel's
// rows: secondary help ("Select a layer to edit its properties.") or a refused
// edit's message, in the error state's color with its symbol (docs/design.md,
// States). It wraps to as many lines as it needs and fills the row's width.
// By default it is inset like the rows (SuiteSpacing.m); `column` instead
// starts it at a value column, an x measured in a named coordinate space the
// caller sets up (Design's style hint starts at the X field, #276).
import SwiftUI

public struct InspectorNote: View {
    public enum Kind: Sendable {
        /// Secondary help text.
        case secondary
        /// A refused edit's message: error color and symbol.
        case error
    }

    public let text: String
    public let kind: Kind
    public let identifier: String?
    /// The value column's leading x in the named space; nil insets like the rows.
    public let column: (x: CGFloat, space: String)?
    @State private var origin: CGFloat = .zero

    public init(_ text: String, kind: Kind = .secondary, identifier: String? = nil, column: (x: CGFloat, space: String)? = nil) {
        self.text = text
        self.kind = kind
        self.identifier = identifier
        self.column = column
    }

    public var body: some View {
        content
            .accessibilityIdentifier(identifier ?? "")
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .modifier(Inset(column: column, origin: $origin))
            .padding(.vertical, SuiteSpacing.xs)
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .secondary:
            Text(text)
                .font(SuiteFont.inspectorMeta)
                .foregroundStyle(SuiteColor.secondaryText)
        case .error:
            Label(text, systemImage: "exclamationmark.circle")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.stateError)
        }
    }

    /// The row inset, or the distance from this note's own leading x to the column.
    private struct Inset: ViewModifier {
        let column: (x: CGFloat, space: String)?
        @Binding var origin: CGFloat

        func body(content: Content) -> some View {
            if let column {
                content
                    .padding(.leading, Swift.max(column.x - origin, .zero))
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(column.space)).minX } action: { origin = $0 }
            } else {
                content.padding(.horizontal, SuiteSpacing.m)
            }
        }
    }
}
