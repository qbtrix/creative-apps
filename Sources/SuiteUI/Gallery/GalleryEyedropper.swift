// GalleryEyedropper.swift (eyedropper EY-2 page, EY-7 live): the gallery's `eyedropper` page. A colour row (blue,
// sampleable, its hex field `suite.gallery.eyedropper.hex`) over a small canvas of a red, a green and a half-transparent black
// swatch, the sample-size chips and the page's log, which shows each change and end the row reports and each size
// picked. EY-7 adds the page's eyedropper tool, sampling the canvas through `color.sample`.
import SuiteKernel
import SwiftUI

enum GalleryEyedropper {
    static let name = "eyedropper"
    static let logID = "suite.gallery.eyedropper.log"

    @MainActor static let pages: GalleryPages = [name: { AnyView(EyedropperPage()) }]

    /// The canvas's swatches: identifier suffix, colour and opacity.
    static let swatches: [(id: String, color: HexColor, opacity: Double)] = [
        ("red", HexColor(255, 0, 0), 1), ("green", HexColor(0, 255, 0), 1), ("black", .black, 0.5),
    ]
}

private struct EyedropperPage: View {
    @State private var color = HexColor(0, 0, 255)
    @State private var size = SampleSize.point
    @State private var lines: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            InspectorColorWellRow("Fill", color: color, sampleable: true, onChange: { next in
                color = next
                lines.append("change \(next.text)")
            }, onEnd: { lines.append("end") })
            .hexIdentifier("suite.gallery.eyedropper.hex")
            HStack(spacing: SuiteSpacing.s) {
                ForEach(GalleryEyedropper.swatches, id: \.id) { swatch in
                    Rectangle()
                        .fill(swatch.color.color.opacity(swatch.opacity))
                        .frame(width: SuiteSize.inspectorField, height: SuiteSize.inspectorField)
                        .accessibilityElement()
                        .accessibilityLabel(swatch.id)
                        .accessibilityIdentifier("suite.gallery.eyedropper.\(swatch.id)")
                }
            }
            .padding(SuiteSpacing.s)
            .background(SuiteColor.overlayPaper)
            SampleSizeChips(size: size) { next in
                size = next
                lines.append("size \(next.title)")
            }
            Text(lines.last ?? "Nothing yet")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
                .accessibilityIdentifier(GalleryEyedropper.logID)
                .accessibilityLabel(lines.joined(separator: "\n"))
                .accessibilityValue(lines.joined(separator: "\n"))
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
