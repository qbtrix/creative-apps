// GalleryExportPack.swift: the gallery's `export-pack` page (packet
// docs/blueprints/suiteui/features/export-pack.md, XP-3 page, XP-8 live). It
// shows SuiteExportSheet in place for a 1000 × 1250 artwork: Format, Size
// (1080 × 1350 px), Quality and Metadata (All) rows. The page drives a local
// export target, GalleryExportBoard: each edit applies to its run's pick, and
// Export plans the pick through ExportRules and runs a fake export through
// FakeMedia that writes a still at exactly the planned pixels, or fails with
// the rules' refusal. Every move writes one line to `suite.gallery.log`. The
// page is its own area in `SuiteGallery.areas`.
import SuiteKernel
import SuiteModel
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

/// The page's local export target: the run the sheet reads and the fake writer its Export runs through.
struct GalleryExportBoard {
    /// The longest side the page's fake writer fills a frame for.
    static let fakeMaxSide = 4096

    private(set) var run: ExportRun<ExportPick> = .editing(GalleryExportPack.pick)
    /// The fake writer: every still the page wrote, with its frame's pixels.
    let media = FakeMedia()

    /// The pick the run holds; the page's own when idle.
    var pick: ExportPick {
        switch run {
        case .idle: GalleryExportPack.pick
        case .editing(let p), .running(let p, _, _), .finished(let p, _), .failed(let p, _): p
        }
    }

    /// The kernel's options for `pick` as the sheet shows it: a vector format at Scale only, All when no policy.
    static func options(_ pick: ExportPick) -> SuiteExportOptions {
        var size = pick.size ?? .scale(pick.scale)
        if ExportFormats.spec(pick.format)?.kind == .vector, ExportSheetRows.sizeMode(of: size) != .scale { size = .scale(1) }
        return SuiteExportOptions(format: pick.format, size: size, quality: pick.quality, metadata: pick.metadata ?? .all)
    }

    /// The exact pixels ExportRules writes for `pick` on the artwork; throws the rules' refusal.
    static func plan(_ pick: ExportPick) throws -> (width: Int, height: Int) {
        let o = options(pick)
        if let why = ExportRules.refusal(o, source: GalleryExportPack.source, formats: ExportFormats.all) {
            throw ExportOptionRefusal.invalid(why)
        }
        let even = ExportFormats.spec(o.format)?.needsEvenSize ?? false
        return try ExportRules.pixels(of: GalleryExportPack.source, o.size, evenSize: even)
    }

    /// An edit from the sheet: the pick changes and the sheet edits again. The log line.
    mutating func edit(_ line: String, _ change: (inout ExportPick) -> Void) -> String {
        var next = pick
        change(&next)
        _ = run.begin(next)
        return line
    }

    /// Cancel (while editing) or Done (after a run): the sheet stays open on the same pick. The log line.
    mutating func close() -> String {
        var line = "done"
        if case .editing = run { line = "cancel" }
        _ = run.begin(pick)
        return line
    }

    /// Export: plans the pick, then writes a still of exactly that size through the fake writer. The log line.
    mutating func export() -> String {
        let p = pick
        _ = run.begin(p)
        _ = run.start(total: 1)
        do {
            let (w, h) = try Self.plan(p)
            let spec = ExportFormats.spec(p.format)
            guard let format = StillFormat(rawValue: p.format) else {
                throw ExportOptionRefusal.invalid(
                    "The page's fake writer writes stills only; \(spec?.name ?? p.format) would be \(w) × \(h) px.")
            }
            guard w <= Self.fakeMaxSide, h <= Self.fakeMaxSide else {
                throw ExportOptionRefusal.invalid(
                    "The page's fake writer stops at \(Self.fakeMaxSide) px a side; the plan is \(w) × \(h) px.")
            }
            let frame = try MediaFrame(width: w, height: h, rgba: Array(repeating: 255, count: w * h * 4))
            _ = try media.still(frame, as: format, quality: p.quality)
            let name = "export-pack." + (spec?.fileExtension ?? p.format)
            run.progressed(done: 1)
            run.end(.success([name]))
            return "export \(p.format): wrote \(name) at \(w) × \(h) px"
        } catch {
            run.end(.failure(error))
            return "export \(p.format): refused, \(error)"
        }
    }
}

/// Internal, not private, so XP-5's snapshots and render budget can build it.
struct GalleryExportPackPage: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    @State private var board = GalleryExportBoard()
    @State private var log: [String] = []

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        let text = log.joined(separator: "\n")
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            SuiteExportSheet(
                ExportSheetRows(board.run, formats: GalleryExportPack.formats, source: GalleryExportPack.source) { $0 },
                formats: GalleryExportPack.formats,
                onFormat: { f in edit("format \(f)") { $0.format = f } }, onScale: { s in edit("scale \(s)") { $0.scale = s } },
                onQuality: { q in edit("quality \(q)") { $0.quality = q } }, onExport: { note(board.export()) },
                onClose: { note(board.close()) },
                onSize: { s in edit("size \(s)") { $0.size = s } }, onMetadata: { m in edit("metadata \(m.rawValue)") { $0.metadata = m } })
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(text).accessibilityValue(text)
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func edit(_ line: String, _ change: (inout ExportPick) -> Void) {
        note(board.edit(line, change))
    }

    private func note(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
