// PhotoToolbarSnapshots.swift: Photo's Delete Layer toolbar item with one
// layer left (shown, disabled) beside the same item with two layers
// (enabled), in Light and Dark. The window toolbar doesn't render here, so
// the items are drawn in a row. Writes photo-toolbar-light.png and
// photo-toolbar-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoToolbarSnapshots {
    @Test func deleteLayerDisabledWithOneLayer() throws {
        var one = PhotoWorkspace()
        try one.newCanvas(width: 1920, height: 1080)
        var two = one
        two.addLayer()
        #expect(!one.canRemoveLayer && two.canRemoveLayer)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                ToolbarStates(one: one, two: two), name: "photo-toolbar-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }
}

private struct ToolbarStates: View {
    let one: PhotoWorkspace
    let two: PhotoWorkspace
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            row("One layer", model: one)
            row("Two layers", model: two)
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ title: String, model: PhotoWorkspace) -> some View {
        HStack(spacing: SuiteSpacing.m) {
            Text(title).font(SuiteFont.headline)
            DeleteLayerCommand(isEnabled: model.canRemoveLayer && model.selectedLayerID != nil)
                .labelStyle(.titleAndIcon)
        }
    }
}
