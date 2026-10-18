// SuiteEditorKernelChromeSnapshots.swift: EK-30's chrome in Light and Dark:
// the export sheet editing, at 4 of 10 and finished; the stroke pad with the
// brush ring. Writes suiteui-editor-kernel-{export,stroke}-{light,dark}.png.
import Foundation
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteEditorKernelChromeSnapshots {
    @Test func exportSheetAndStrokePad() throws {
        for (scheme, name) in [(ColorScheme.light, "light"), (.dark, "dark")] {
            try snapshot(ExportSheets(), name: "suiteui-editor-kernel-export-\(name)", scheme: scheme)
            try snapshot(StrokePadSheet(), name: "suiteui-editor-kernel-stroke-\(name)", scheme: scheme)
        }
    }
}

private struct ExportSheets: View {
    var body: some View {
        let png = GalleryEditorKernelChrome.pick, formats = GalleryEditorKernelChrome.formats
        let runs: [ExportRun<ExportPick>] = [
            .editing(ExportPick(format: "jpeg", scale: 2, quality: 0.8)), .running(png, done: 4, total: 10), .finished(png, ["editor-kernel.png"]),
        ]
        HStack(alignment: .top, spacing: SuiteSpacing.l) {
            ForEach(runs, id: \.self) { run in
                SuiteExportSheet(
                    ExportSheetRows(run, formats: formats) { $0 }, formats: formats,
                    onFormat: { _ in }, onScale: { _ in }, onQuality: { _ in }, onExport: {}, onClose: {}
                ).background(SuiteColor.panel)
            }
        }
        .padding(SuiteSpacing.xxl).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct StrokePadSheet: View {
    var body: some View {
        let dots = (0..<40).map { i in
            GalleryStrokePad.Dot(
                point: CGPoint(x: 40 + Double(i) * 9, y: 180 + 60 * sin(Double(i) / 6)), pressure: 0.2 + 0.8 * Double(i) / 39, starts: i == 0)
        }
        GalleryStrokePad(dots: dots, hover: dots.last?.point)
            .padding(SuiteSpacing.xxl).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
