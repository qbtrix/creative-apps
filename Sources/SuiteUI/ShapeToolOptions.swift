// ShapeToolOptions.swift (shape-tools SH-2 placeholder, SH-3 view): the shape
// tool's options. The placeholder shows the six kind chips, each sending
// `.kind`, and the spec's help; SH-3 adds each kind's rows.
import SuiteKernel
import SwiftUI

public struct ShapeToolOptions: View {
    let spec: ShapeSpec, help: String?, onIntent: @MainActor (ShapeIntent) -> Void

    public init(spec: ShapeSpec, help: String?, onIntent: @escaping @MainActor (ShapeIntent) -> Void) {
        (self.spec, self.help, self.onIntent) = (spec, help, onIntent)
    }

    nonisolated static let kinds = ShapeKind.allCases.map {
        InspectorOption(id: $0, title: $0.rawValue.capitalized, identifier: "suite.shape.chip-\($0.rawValue)")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ChoiceChips(options: Self.kinds, selected: spec.kind) { onIntent(.kind($0)) }
            if let help { Text(help).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText) }
        }
    }
}
