// DesignPlaceUISnapshots.swift (placed-images PD-u, PD-4): Design's place surfaces around a placed picture.
// The 400 × 400 frame with the photo beside the Picture section, the same frame empty, and the drop ring. Writes
// design-image-inspector{,-empty}- and design-place-drop-{light,dark}.png from `DesignPlaceSeed`. macOS only.
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

    @Test func inspectorEmpty() throws {
        let model = DesignPlaceSeed.page(DesignNode(id: "node-1", name: "Frame", kind: .frame,
                                                    frame: DesignRect(x: 100, y: 100, width: 400, height: 400), cornerRadius: 24))
        #expect(model.selectedNode?.kind == .frame && model.placedSelection == nil)
        #expect(model.placeNote == DesignWorkspace.placeNotBuilt)
        try shoot(PlaceSample(model: model), "design-image-inspector-empty")
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
