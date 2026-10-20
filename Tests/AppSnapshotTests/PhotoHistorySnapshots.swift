// PhotoHistorySnapshots.swift (history-panel PH-4): the Photo window with its
// inspector on the History tab, over an opened "portrait.jpg" and 12 edits
// (8 brush strokes, Exposure, Curves, two rotations). `historyTab`: "Open"
// and the 12 steps, the last current. `historyTabJumped`: the image jumped
// back to step 2, the current row moved there and the ten rows past it dimmed
// ("not applied"), the step count unchanged. Light and Dark. Writes
// photo-history-tab-light.png, photo-history-tab-dark.png,
// photo-history-tab-jumped-light.png and photo-history-tab-jumped-dark.png.
// The jump goes through the Model's `jumpToHistoryStep`, the undo and redo
// walk the tab already follows (PhotoHistoryTabTests). macOS only.
import CoreRaster
import PhotoModel
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

@MainActor
@Suite struct PhotoHistorySnapshots {
    /// An opened 640 x 480 "portrait.jpg" with 12 edits, each its own step.
    private func edited() throws -> PhotoWorkspace {
        let (w, h) = (640, 480)
        var model = PhotoWorkspace()
        try model.open(rgba8: [UInt8](repeating: 210, count: w * h * 4), width: w, height: h, name: "portrait.jpg")
        model.selectTool(.brush)
        model.setToolOption(.size(24))
        for row in 0..<8 {
            let y = Double(60 + row * 45)
            model.drag(from: Mask.Point(x: 80, y: y), to: Mask.Point(x: 80, y: y))
            model.drag(from: Mask.Point(x: 80, y: y), to: Mask.Point(x: 560, y: y))
            model.endDrag()
        }
        model.adjust(.exposure(0.4))
        model.endAdjust()
        model.adjust(.curvePoints([(0, 0), (0.25, 0.15), (0.75, 0.85), (1, 1)].map { CurvePoint(x: $0.0, y: $0.1) }))
        model.endAdjust()
        model.rotateImage(.degrees90)
        model.rotateImage(.degrees90)
        return model
    }

    /// The window's editor with the inspector on the History tab.
    private func window(_ model: PhotoWorkspace) throws -> some View {
        PhotoEditor(model: model, tiles: try photoTiles(model), renderMilliseconds: 8, zoom: 1)
            .environment(\.photoInspectorTab, .history)
    }

    @Test func historyTab() throws {
        let model = try edited()
        let listing = model.historyListing
        #expect(listing.base == "Open" && listing.steps.count == 12 && listing.index == 12, "\(listing)")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                window(model), name: "photo-history-tab-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func historyTabJumped() throws {
        var model = try edited()
        model.jumpToHistoryStep(2)
        let listing = model.historyListing
        #expect(listing.index == 2 && listing.steps.count == 12, "\(listing)")
        let third = listing.steps.dropFirst(2).first ?? ""
        #expect(HistoryPanel.label(at: 3, in: listing) == "Step 3 of 12, \(third), not applied")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                window(model), name: "photo-history-tab-jumped-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
