// InspectorHeader.swift: the top of an inspector: the file or selection name
// in the 12 pt semibold title, one line truncated in the middle, then the info
// card: a filled rounded card (the Studio rows' fill and radius, inset 8 by 12) of
// facts, labels on the left in secondary text and values on the right in
// semibold tabular figures. The older `details:` init draws its lines in the
// same card, one per line. Not interactive; flat, never glass.
import SwiftUI

/// One fact in an InspectorHeader's card: "Size" and "1920 × 1080 px".
public struct InspectorFact: Hashable, Sendable {
    public let label: String
    public let value: String

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

public struct InspectorHeader: View {
    private let title: String
    private let facts: [InspectorFact]
    private let details: [String]

    /// `facts` fill the card in order; facts with an empty value are skipped.
    public init(_ title: String, facts: [InspectorFact]) {
        self.title = title
        self.facts = facts.filter { !$0.value.isEmpty }
        self.details = []
    }

    /// `details` are short lines drawn in the card in order, for example
    /// ["1920 × 1080 px", "sRGB · 8 bits per channel"]. Empty lines are skipped.
    public init(_ title: String, details: [String] = []) {
        self.title = title
        self.facts = []
        self.details = details.filter { !$0.isEmpty }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text(title)
                .font(SuiteFont.inspectorTitle)
                .foregroundStyle(SuiteColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            if !facts.isEmpty || !details.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: SuiteSpacing.s, verticalSpacing: SuiteSpacing.xxs) {
                    ForEach(facts, id: \.self) { fact in
                        GridRow {
                            Text(fact.label).foregroundStyle(SuiteColor.textSecondary)
                            Text(fact.value)
                                .font(SuiteFont.inspectorValue)
                                .foregroundStyle(SuiteColor.textPrimary)
                                .gridColumnAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    ForEach(Array(details.enumerated()), id: \.offset) { _, line in
                        Text(line).foregroundStyle(SuiteColor.textSecondary).monospacedDigit()
                    }
                }
                .font(SuiteFont.inspectorLabel)
                .lineLimit(1)
                .padding(SuiteInset.card)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SuiteColor.panelRaised, in: .rect(cornerRadius: SuiteRadius.row))
            }
        }
        .padding(.horizontal, SuiteSpacing.m)
        .padding(.top, SuiteSpacing.m)
        // One header element reading "name, fact, fact", as the journeys look it up.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
