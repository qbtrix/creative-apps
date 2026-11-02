// GalleryFontPicker.swift: the gallery's `font-picker` page (packet
// docs/blueprints/suiteui/features/font-picker.md, FP-1). It shows FontPicker
// on FakeText's three families, the first family's first face picked at 12 pt;
// each pick lands in the log (`suite.gallery.log`) as
// "pick(<family>, <face>, <size>)". FP-6: with live services the page lists
// the live families instead. SuiteUI can't reach SuiteShell's LiveText, so a
// host passes its font list as `.environment(\.suiteFontListing, services.text)`;
// under -SuiteGalleryFakes, or with no list set, the page keeps FakeText's.
//
// A debug-only `bodyRuns` counts the page's bodies for FP-4's render budget.
import SuiteModel
import SwiftUI

enum GalleryFontPicker {
    static let name = "font-picker"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryFontPickerSource()) }]

    /// FakeText's families: the page's list on fakes.
    static var families: [FontFamily] { FakeText().families() }

    /// The families the page lists: the live list's, or FakeText's under fakes or with no live list.
    static func families(fakes: Bool, live: (any FontListing)?) -> [FontFamily] {
        guard !fakes, let live else { return families }
        return live.families()
    }

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

/// Picks the page's families from the gallery request and the host's font list.
private struct GalleryFontPickerSource: View {
    @Environment(\.galleryRequest) private var request
    @Environment(\.suiteFontListing) private var live

    var body: some View {
        GalleryFontPickerPage(families: GalleryFontPicker.families(fakes: request?.fakes == true, live: live))
    }
}

extension EnvironmentValues {
    /// The host's live font list (`services.text`); nil runs the gallery's font picker page on FakeText.
    public var suiteFontListing: (any FontListing)? {
        get { self[SuiteFontListingKey.self] }
        set { self[SuiteFontListingKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as in Glass.swift.
private struct SuiteFontListingKey: EnvironmentKey {
    static let defaultValue: (any FontListing)? = nil
}

/// Internal, not private, so FP-4's snapshots and render budget can build it.
struct GalleryFontPickerPage: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
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
        let _ = bodyTally.ran(Self.self)
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
