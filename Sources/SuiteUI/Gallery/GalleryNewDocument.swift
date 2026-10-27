// GalleryNewDocument.swift (document-setup DS-6): the gallery's `new-document` page, NewDocumentSheet inline on
// Flare's presets with a 1200 × 800 clipboard image and timed limits, a New / Settings switch, and a log line that
// reads the command the sheet would run. `GalleryNewDocumentSheet` is the snapshot: each mode beside the other.
import SuiteKernel
import SuiteModel
import SwiftUI

enum GalleryNewDocument {
    static let name = "new-document"
    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryNewDocumentPage()) }]
    static let limits = DocumentLimits(rates: FrameRate.common, maxSeconds: 600)
    static let start = DocumentSetup(width: 1920, height: 1080, frameRate: FrameRate(whole: 24), durationSeconds: 10)
    static var new: NewDocumentMode { .new(presets: SuiteCreating.presets[.flare] ?? [], clipboard: (width: 1200, height: 800)) }

    /// The log line for a finished sheet: the command and the values it carries.
    static func line(_ mode: NewDocumentMode, _ setup: DocumentSetup, _ anchor: BoxAnchor) -> String {
        let size = "\(NewDocumentForm.text(setup.width)) × \(NewDocumentForm.text(setup.height)) \(setup.unit.rawValue)"
        let tail = if case .settings = mode { " anchor \(anchor.rawValue)" } else { "" }
        return "\(mode.command) \(size) at \(NewDocumentForm.text(setup.resolution)) ppi\(tail)"
    }
}

struct GalleryNewDocumentPage: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    @State private var settings = false
    @State private var log: [String] = []

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        let mode = settings ? NewDocumentMode.settings : GalleryNewDocument.new
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("New document").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            SegmentedTabs(
                "Mode", tabs: [InspectorOption(id: false, title: "New"), InspectorOption(id: true, title: "Settings")],
                selection: settings, id: "suite.gallery.newdoc-mode"
            ) { settings = $0 }
            .fixedSize()
            NewDocumentSheet(mode, setup: GalleryNewDocument.start, limits: GalleryNewDocument.limits,
                             onDone: { log.append(GalleryNewDocument.line(mode, $0, $1)) }, onCancel: { log.append("cancel") })
                .id(settings)
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityValue(log.joined(separator: "\n")).accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The snapshot: `new` on its presets, and `settings` with the anchor grid, on a setup that shows a problem.
struct GalleryNewDocumentSheet: View {
    let settings: Bool

    var body: some View {
        NewDocumentSheet(settings ? .settings : GalleryNewDocument.new,
                         setup: settings ? DocumentSetup(width: 4, height: 6, unit: .inch, resolution: 300, background: .transparent,
                                                         frameRate: FrameRate(whole: 30), durationSeconds: 12) : GalleryNewDocument.start,
                         limits: GalleryNewDocument.limits, onDone: { _, _ in }, onCancel: {})
    }
}
