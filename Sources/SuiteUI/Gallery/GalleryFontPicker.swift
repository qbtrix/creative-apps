// GalleryFontPicker.swift: the gallery's `font-picker` page (packet
// docs/blueprints/suiteui/features/font-picker.md, FP-1). It shows FontPicker
// on FakeText's three families, the first family's first face picked at 12 pt;
// each pick lands in the log (`suite.gallery.log`) as
// "pick(<family>, <face>, <size>)". FP-6 swaps in the live families when the
// gallery runs with live services.
//
// A debug-only `bodyRuns` counts the page's bodies for FP-4's render budget.
import SuiteModel
import SwiftUI

enum GalleryFontPicker {
    static let name = "font-picker"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryFontPickerPage()) }]

    /// The families the page lists: FakeText's.
    static var families: [FontFamily] { FakeText().families() }

    /// The page's first pick: the first family's first face at 12 pt.
    static func start(_ families: [FontFamily]) -> FontPick {
        let family = families.first
        let face = family.flatMap { FontPickerRules.orderedFaces($0).first } ?? FontFace(name: "Regular", weight: 400, italic: false)
        return FontPick(family: family?.name ?? "", face: face, size: 12)
    }

    /// The log line for a pick: "pick(System UI, Bold, 36)"; a whole size has no decimals.
    static func line(_ pick: FontPick) -> String {
        let whole = pick.size.isFinite && pick.size.rounded() == pick.size && abs(pick.size) < 1_000_000
        let size = whole ? String(Int(pick.size)) : String(pick.size)
        return "pick(\(pick.family), \(pick.face.name), \(size))"
    }
}

/// Internal, not private, so FP-4's snapshots and render budget can build it.
struct GalleryFontPickerPage: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    private let families: [FontFamily]
    @State private var pick: FontPick
    @State private var log: [String] = []

    init(families: [FontFamily] = GalleryFontPicker.families) {
        self.families = families
        _pick = State(initialValue: GalleryFontPicker.start(families))
    }

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        let text = log.joined(separator: "\n")
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Font picker").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            FontPicker(families: families, pick: pick) { picked in
                pick = picked
                log.append(GalleryFontPicker.line(picked))
                if log.count > 40 { log.removeFirst(log.count - 40) }
            }
            .frame(width: SuiteSize.editorPanelWidth, alignment: .leading)
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(text).accessibilityValue(text)
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
