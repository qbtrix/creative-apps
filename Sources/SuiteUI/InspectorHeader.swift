// InspectorHeader.swift: the top of a pro inspector: the selection's name and
// one metadata line per fact (size, color space, frame rate), on a flat raised
// band that ends in a hairline. It replaces the floating SurfaceCard at the
// top of an inspector; content stays flat, so no glass and no rounded card.
import SwiftUI

public struct InspectorHeader: View {
    private let title: String
    private let details: [String]

    /// `details` are short lines drawn under the name in order, for example
    /// ["1920 × 1080 px", "sRGB · 8 bits per channel"]. Empty lines are skipped.
    public init(_ title: String, details: [String] = []) {
        self.title = title
        self.details = details.filter { !$0.isEmpty }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SuiteSpacing.xxs) {
                Text(title)
                    .font(SuiteFont.inspectorTitle)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ForEach(Array(details.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(SuiteFont.inspectorMeta)
                        .foregroundStyle(SuiteColor.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, SuiteSpacing.s)
            .padding(.horizontal, SuiteSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SuiteColor.panelRaised)
            Divider()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
