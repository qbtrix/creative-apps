// SuiteExportPackSnapshots.swift (export-pack XP-5): SuiteExportSheet's Size and
// Metadata rows on the gallery page's 1000 × 1250 artwork, in Light and Dark,
// once per way the Size row reads: Scale 2x, Pixels locked at 1080 × 1350,
// Pixels unlocked and stretched to 1080 × 1351, a locked 1080 × 1351 the rules
// refuse (the readout in the error color, Export disabled with that reason), Long
// edge 2048, and SVG (Scale only, no Metadata row). Each writes
// suiteui-export-pack-<state>-<light|dark>.png and checks the golden
// Golden/inspector/export-pack-<state>-<light|dark>.png (CI records a missing one).
// The render budget is RenderBudgetExportPackTests. macOS only.
#if canImport(AppKit)
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor @Suite struct SuiteExportPackSnapshots {
    /// Each state the Size row reads differently in: its file name, the pick, and the readout it shows.
    static let states: [(name: String, pick: ExportPick, readout: String)] = [
        ("scale", ExportPick(format: "jpeg", metadata: .all, size: .scale(2)), "2000 × 2500 px"),
        ("pixels", ExportPick(format: "jpeg", metadata: .noLocation, size: .pixels(width: 1080, height: 1350)), "1080 × 1350 px"),
        ("stretched", ExportPick(format: "png", metadata: ExportMetadata.none, size: .pixels(width: 1080, height: 1351, stretch: true)),
         "1080 × 1351 px, stretched"),
        ("refused", ExportPick(format: "jpeg", metadata: .all, size: .pixels(width: 1080, height: 1351)),
         "1080 × 1351 doesn't keep the artwork's 4:5 shape. Unlock the ratio to stretch."),
        ("long-edge", ExportPick(format: "heic", metadata: .noLocation, size: .longEdge(2048)), "1638 × 2048 px"),
        ("vector", ExportPick(format: "svg", metadata: .all, size: .scale(1)), "1000 × 1250 px"),
    ]

    static func rows(_ pick: ExportPick) -> ExportSheetRows {
        ExportSheetRows(.editing(pick), formats: GalleryExportPack.formats, source: GalleryExportPack.source) { $0 }
    }

    /// The sheet as the gallery page draws it, every row editable.
    static func sheet(_ pick: ExportPick) -> some View {
        SuiteExportSheet(
            rows(pick), formats: GalleryExportPack.formats, onFormat: { _ in }, onScale: { _ in }, onQuality: { _ in },
            onExport: {}, onClose: {}, onSize: { _ in }, onMetadata: { _ in })
    }

    @Test func screens() throws {
        for state in Self.states {
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(Self.sheet(state.pick), name: "suiteui-export-pack-\(state.name)-\(scheme.name)", scheme: scheme)
                assertGolden(Self.sheet(state.pick), name: "export-pack-\(state.name)", area: "inspector", scheme: scheme)
            }
        }
    }

    /// What each snapshot shows: the readout under Size, the modes offered, and a Metadata row unless SVG.
    @Test func eachStateReadsItsSize() {
        for state in Self.states {
            guard let size = state.pick.size else { Issue.record("\(state.name) has no size"); continue }
            #expect(ExportSheetRows.readout(size, source: GalleryExportPack.source).text == state.readout, "\(state.name)")
            let rows = Self.rows(state.pick)
            let vector = state.pick.format == "svg"
            #expect(rows.sizeModes == (vector ? [.scale] : ExportSheetRows.SizeMode.allCases), "\(state.name)")
            #expect(rows.rows.contains(.pixels(size, source: 1000, 1250)), "\(state.name) shows no Size row")
            #expect(rows.rows.contains { if case .metadata = $0 { true } else { false } } == !vector, "\(state.name)")
        }
        #expect(ExportSheetRows.readout(.pixels(width: 1080, height: 1351), source: GalleryExportPack.source).refused)
        for state in Self.states { #expect((Self.rows(state.pick).startHelp(blocked: nil) != nil) == (state.name == "refused"), "\(state.name)") }
    }
}
#endif
