// SuiteFontPickerOwnFaceSnapshots.swift (finding #4777): the font picker on
// families every Mac ships, so each row shows in its own face. FakeText's Mono
// and Serif aren't installed names, so its rows fall back to the body font and
// can't show that. Writes suiteui-font-picker-own-face-{light,dark}.png.
import SuiteModel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteFontPickerOwnFaceSnapshots {
    static let regular = FontFace(name: "Regular", weight: 400, italic: false)
    static let families = ["Courier", "Georgia", "Helvetica"].map { FontFamily(name: $0, faces: [regular]) }

    @Test func ownFaces() throws {
        let pick = FontPick(family: "Georgia", face: Self.regular, size: 12)
        for scheme in [ColorScheme.light, .dark] {
            let picker = FontPicker(families: Self.families, pick: pick) { _ in }
            try snapshot(
                SuiteFontPickerSnapshots.framed(picker), name: "suiteui-font-picker-own-face-\(scheme.name)",
                scheme: scheme)
        }
    }
}
