// GalleryExportPack.swift: the gallery's `export-pack` page (packet
// docs/blueprints/suiteui/features/export-pack.md, XP-3). It shows
// SuiteExportSheet in place on a local ExportPick for a 1000 × 1250 artwork:
// Format, Size (1080 × 1350 px), Quality and Metadata (All) rows. XP-3's Size
// and Metadata rows are placeholders that read the pick; XP-4 makes them
// controls. Each edit applies to the local pick and writes one line to
// `suite.gallery.log`; Export and Cancel only log. XP-8 plans each pick
// through ExportRules on a local target instead. The page is its own area in
// `SuiteGallery.areas`.
import SuiteKernel
import SwiftUI

enum GalleryExportPack {
    static let name = "export-pack"
    /// The artwork's pixels at 1x.
    static let source = (width: 1000, height: 1250)
    /// The kernel's still and vector formats; the suite names its formats once (FormatListRatchetTests).
    static let formats = ExportFormats.all.filter { $0.kind == .still || $0.kind == .vector }
        .map { FormatChoice(id: $0.id, name: $0.name, hasQuality: $0.hasQuality) }
    static let pick = ExportPick(format: "jpeg", quality: 0.9, metadata: .all, size: .pixels(width: 1080, height: 1350))

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryExportPackPage()) }]
}

/// Internal, not private, so XP-5's snapshots and render budget can build it.
struct GalleryExportPackPage: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    @State private var pick = GalleryExportPack.pick
    @State private var log: [String] = []

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        let text = log.joined(separator: "\n")
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            SuiteExportSheet(
                ExportSheetRows(.editing(pick), formats: GalleryExportPack.formats, source: GalleryExportPack.source) { $0 },
                formats: GalleryExportPack.formats,
                onFormat: { f in edit("format \(f)") { $0.format = f } }, onScale: { s in edit("scale \(s)") { $0.scale = s } },
                onQuality: { q in edit("quality \(q)") { $0.quality = q } }, onExport: { note("export") }, onClose: { note("cancel") })
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(text).accessibilityValue(text)
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func edit(_ line: String, _ change: (inout ExportPick) -> Void) {
        change(&pick)
        note(line)
    }

    private func note(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
