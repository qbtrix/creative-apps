// SuiteEyedropperSnapshots.swift (eyedropper EY-4): the eyedropper's screens in Light and Dark. Writes
// suiteui-eyedropper-row-{light,dark}.png (colour rows with their eyedropper button, at the ideal inspector width
// and at the editor panel width), suiteui-eyedropper-loupe-{light,dark}.png (the ring over green with its hex),
// suiteui-eyedropper-loupe-empty-{light,dark}.png (the ring hollow, "No colour here") and
// suiteui-eyedropper-sizes-{light,dark}.png (the size chips, 3 × 3 chosen). macOS only.
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteEyedropperSnapshots {
    @Test func screens() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(EyedropperRows(), name: "suiteui-eyedropper-row-\(scheme.name)", scheme: scheme)
            try snapshot(EyedropperLoupeSample(color: HexColor(0, 255, 0)),
                         name: "suiteui-eyedropper-loupe-\(scheme.name)", scheme: scheme)
            try snapshot(EyedropperLoupeSample(color: nil),
                         name: "suiteui-eyedropper-loupe-empty-\(scheme.name)", scheme: scheme)
            try snapshot(SampleSizeChips(size: .threeByThree) { _ in }.frame(width: SuiteSize.inspectorWidth.ideal)
                .padding(SuiteSpacing.xxl).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                         name: "suiteui-eyedropper-sizes-\(scheme.name)", scheme: scheme)
        }
    }
}

/// The apps' colour row labels at the ideal inspector width, and "Background" at the editor panel's.
private struct EyedropperRows: View {
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            column(["Fill", "Color", "Stroke"], width: SuiteSize.inspectorWidth.ideal)
            column(["Background"], width: SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m)
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func column(_ labels: [String], width: CGFloat) -> some View {
        InspectorSection("Fill") {
            ForEach(labels, id: \.self) { label in
                InspectorColorWellRow(label, color: HexColor(0x18, 0x77, 0xF2), onChange: { _ in })
            }
        }
        .frame(width: width)
        .background(SuiteColor.panel)
    }
}

/// A red, green and black canvas with the loupe over the green swatch, or past the canvas's edge.
private struct EyedropperLoupeSample: View {
    let color: HexColor?

    var body: some View {
        let side = SuiteSize.toolButton * 4
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Rectangle().fill(HexColor(255, 0, 0).color)
                Rectangle().fill(HexColor(0, 255, 0).color)
                Rectangle().fill(HexColor.black.color)
            }
            .frame(width: side * 3, height: side)
            SampleLoupe(color: color, at: CGPoint(x: color == nil ? side * 3 + side / 2 : side * 1.5, y: side / 2))
        }
        .frame(width: side * 4, height: side * 2, alignment: .topLeading)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
