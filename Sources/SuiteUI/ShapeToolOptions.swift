// ShapeToolOptions.swift (shape-tools SH-2 placeholder, SH-3 view): the shape
// tool's options panel. The placeholder shows the six kind chips and the
// spec's help; each chip sends `.kind`. SH-3 adds each kind's rows.
import SuiteKernel
import SwiftUI

public struct ShapeToolOptions: View {
    private let spec: ShapeSpec
    private let help: String?
    private let onIntent: @MainActor (ShapeIntent) -> Void

    public init(spec: ShapeSpec, help: String?, onIntent: @escaping @MainActor (ShapeIntent) -> Void) {
        (self.spec, self.help, self.onIntent) = (spec, help, onIntent)
    }

    /// One chip per kind, in ShapeKind's order, each identified `suite.shape.chip-<kind>`.
    nonisolated static let kinds = ShapeKind.allCases.map {
        InspectorOption(id: $0, title: $0.rawValue.capitalized, identifier: "suite.shape.chip-\($0.rawValue)")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ChoiceChips(options: Self.kinds, selected: spec.kind) { onIntent(.kind($0)) }
            if let help {
                Text(help)
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
        }
    }
}
