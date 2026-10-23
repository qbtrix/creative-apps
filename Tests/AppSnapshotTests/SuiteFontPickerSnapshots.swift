// SuiteFontPickerSnapshots.swift (font-picker FP-4): the font picker in Light
// and Dark. The gallery's `font-picker` page on FakeText's families, Mono
// picked at 12 pt, writes suiteui-font-picker-{light,dark}.png; the picker with
// "sys" typed writes suiteui-font-picker-search-{light,dark}.png; System UI
// Bold at 36 pt writes suiteui-font-picker-faces-{light,dark}.png. An open
// Face menu is a separate window a static render can't show: the journey's
// font-picker-faces shot does.
import SuiteModel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteFontPickerSnapshots {
    static let families = FakeText().families()

    @Test func galleryPage() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryFontPickerPage(), name: "suiteui-font-picker-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func search() throws {
        let pick = GalleryFontPicker.start(Self.families)
        for scheme in [ColorScheme.light, .dark] {
            let picker = FontPicker(families: Self.families, pick: pick, query: "sys") { _ in }
            try snapshot(Self.framed(picker), name: "suiteui-font-picker-search-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func boldAt36() throws {
        let pick = FontPick(family: "System UI", face: FontFace(name: "Bold", weight: 700, italic: false), size: 36)
        for scheme in [ColorScheme.light, .dark] {
            let picker = FontPicker(families: Self.families, pick: pick) { _ in }
            try snapshot(Self.framed(picker), name: "suiteui-font-picker-faces-\(scheme.name)", scheme: scheme)
        }
    }

    /// The picker at the gallery page's width, padded like a panel.
    static func framed(_ picker: FontPicker) -> some View {
        picker.frame(width: SuiteSize.editorPanelWidth).padding(SuiteSpacing.l)
    }
}
