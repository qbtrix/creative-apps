// FlareNewSheetSnapshots.swift: the New Animation sheet (layers-files LF-3)
// in three states: Vertical 9:16 picked (flare-new-sheet.png), a typed
// 800 × 600 that makes it Custom (flare-new-sheet-custom.png), and width 0,
// whose problem shows under the fields and disables Create
// (flare-new-sheet-invalid.png). macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareNewSheetSnapshots {
    @Test func preset() throws {
        let sheet = FlareNewAnimationSheet(spec: NewDocumentSpec(preset: .vertical))
        try snapshot(sheet, name: "flare-new-sheet", scheme: .light)
    }

    @Test func custom() throws {
        var spec = NewDocumentSpec(preset: .hd1080)
        spec.setSize(width: 800, height: 600)
        #expect(spec.preset == nil && spec.problem == nil)
        try snapshot(FlareNewAnimationSheet(spec: spec), name: "flare-new-sheet-custom", scheme: .light)
    }

    @Test func invalid() throws {
        var spec = NewDocumentSpec(preset: .web)
        spec.setSize(width: 0, height: 400)
        #expect(spec.problem != nil)
        try snapshot(FlareNewAnimationSheet(spec: spec), name: "flare-new-sheet-invalid", scheme: .light)
    }
}
