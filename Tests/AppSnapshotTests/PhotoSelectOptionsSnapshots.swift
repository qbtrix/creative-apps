// PhotoSelectOptionsSnapshots.swift: the Tool Options section with the Select tool on the `sample` fixture
// (800 x 600, its image layer picked): Select's hint over the Transform rows, the state the canvas shots can't
// show since the inspector is AppKit chrome. Writes photo-select-options-light/-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoSelectOptionsSnapshots {
    @Test func hintAndTransformRows() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.select)
        #expect(model.canMoveSelection, "the picked layer can't move: \(model.moveHint)")
        #expect(model.transformSelection != nil, "no Transform rows to show")
        for scheme in [ColorScheme.light, .dark] {
            let view = ToolOptionsSection(model: model, perform: { _ in })
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "photo-select-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
