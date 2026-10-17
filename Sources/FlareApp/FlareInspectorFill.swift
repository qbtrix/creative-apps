// FlareInspectorFill.swift: the FILL stub (IT-4; IT-5 replaces it): `model.paint`
// as plain read-only rows, "Mixed" where the layers differ. No controls.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareInspectorFill: View {
    let paint: PaintReadout

    var body: some View {
        InspectorSection("Fill") {
            InspectorRow("Fill") { Text(paint.fillIsGradient ? "Gradient" : Self.hex(paint.fillHex)) }
            InspectorRow("Stroke") { Text(Self.hex(paint.strokeHex)) }
            InspectorRow("Width") {
                Text(paint.strokeWidth.map { NumericInput.text($0, decimals: 1, unit: "pt") } ?? "Mixed")
            }
        }
        .accessibilityIdentifier("flare.inspector.fill")
    }

    /// "#RRGGBB" for a hex, or "Mixed" for nil.
    private static func hex(_ hex: String?) -> String {
        guard let hex else { return "Mixed" }
        return hex.hasPrefix("#") ? hex : "#" + hex
    }
}
