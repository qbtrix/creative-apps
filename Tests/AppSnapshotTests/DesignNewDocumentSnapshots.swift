// DesignNewDocumentSnapshots.swift (document-setup DS-design): Design's File > New sheet as DesignCommands builds
// it, the shared NewDocumentSheet on Design's frame presets and its opening setup (1440 × 1024, white). The
// opening values are the Desktop preset's, so its menu reads Desktop (design-new-document-light.png, -dark.png).
// macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct DesignNewDocumentSnapshots {
    @Test func sheetOnDesignPresets() throws {
        let sheet = NewDocumentSheet(.new(presets: DesignWorkspace.newDocumentPresets, clipboard: nil),
                                     setup: DesignWorkspace.newDocumentSetup, limits: DesignWorkspace.newDocumentLimits,
                                     onDone: { _, _ in }, onCancel: {})
        try snapshot(sheet, name: "design-new-document-light", scheme: .light)
        try snapshot(sheet, name: "design-new-document-dark", scheme: .dark)
    }
}
