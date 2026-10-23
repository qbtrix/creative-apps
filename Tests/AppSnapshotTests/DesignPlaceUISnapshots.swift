// DesignPlaceUISnapshots.swift (placed-images PD-u, PD-4): Design's place surfaces around a placed picture.
// The 400 × 400 frame showing the photo beside the inspector's Image section (name, size, Place…), and the
// canvas under the drop ring a picture dragged over it shows. Writes design-image-inspector- and
// design-place-drop-{light,dark}.png from `DesignPlaceSeed.framed()`. macOS only.
import AppKit
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignPlaceUISnapshots {
    @Test func inspector() throws {
        let model = try DesignPlaceSeed.framed()
        #expect(model.placedSelection?.asset.name == "photo-1200x800.jpg")
        try shoot(PlaceSample(model: model), "design-image-inspector")
    }

    @Test func drop() throws {
        let model = try DesignPlaceSeed.framed()
        // The drop's own ring is private to SuiteUI's modifier and shows only while a drag is over it; this draws it the same way.
        let ring = RoundedRectangle(cornerRadius: SuiteRadius.medium).stroke(SuiteColor.accent, lineWidth: SuiteSize.focusRing)
        try shoot(DesignCanvas(model: model, zoom: 0.5).overlay { ring.padding(SuiteSpacing.xxl) }, "design-place-drop")
    }

    private func shoot(_ view: some View, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

/// The canvas at 50% beside the inspector at the editor's panel width.
private struct PlaceSample: View {
    let model: DesignWorkspace
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            DesignCanvas(model: model, zoom: 0.5)
            DesignInspector(model: model, perform: { _ in })
                .frame(width: SuiteSize.editorPanelWidth)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(SuiteSpacing.xxl)
        }
    }
}
