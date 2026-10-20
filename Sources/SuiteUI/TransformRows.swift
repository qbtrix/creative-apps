// TransformRows.swift (transform-tools TT-2 placeholder, TT-3 view): the
// inspector's X, Y, W, H and Rotation rows for the selection's TransformBox.
// The placeholder reads the box out, one row per value with its identifier
// (`suite.transform.x` ... `suite.transform.rotation`); it edits nothing and
// draws no flip buttons yet, so it shows no dead control. TT-3 makes the rows
// fields, adds Flip Horizontal and Flip Vertical, and sends `onIntent`.
import SuiteKernel
import SwiftUI

/// X, Y, W, H, Rotation and the two flip buttons for the selection; `nil` shows the rows disabled with `help`.
public struct TransformRows: View {
    private let selection: TransformBox?
    private let help: String?
    private let flipHelp: String?
    private let onIntent: @MainActor (TransformIntent) -> Void

    /// `selection` is the box the rows read; `help` says why it can't transform, `flipHelp` why it can't mirror.
    /// `onIntent` gets each edit the rows ask for (none until TT-3).
    public init(selection: TransformBox?, help: String?, flipHelp: String?,
                onIntent: @escaping @MainActor (TransformIntent) -> Void) {
        self.selection = selection
        self.help = help
        self.flipHelp = flipHelp
        self.onIntent = onIntent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            ForEach(Self.rows(selection), id: \.id) { row in
                InspectorRow(row.title) {
                    Text(row.value)
                        .monospacedDigit()
                        .accessibilityIdentifier("suite.transform.\(row.id)")
                        .accessibilityValue(Text(row.value))
                }
            }
        }
        .disabled(selection == nil || help != nil)
        .help(help ?? "")
    }

    /// The five rows as the placeholder reads them: whole document points and whole degrees; "–" with no selection.
    nonisolated static func rows(_ t: TransformBox?) -> [(id: String, title: String, value: String)] {
        let whole = { (v: Double) in t == nil ? "–" : "\(Int(v.rounded()))" }
        let b = t?.box ?? Rect(minX: 0, minY: 0, maxX: 0, maxY: 0)
        return [("x", "X", whole(b.minX)), ("y", "Y", whole(b.minY)), ("w", "W", whole(b.width)),
                ("h", "H", whole(b.height)), ("rotation", "Rotation", whole(t?.degrees ?? 0) + (t == nil ? "" : "°"))]
    }
}
