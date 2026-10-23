// PhotoHistoryInspectorSnapshots.swift (history-panel PH-a, Mac finish): the
// inspector itself on the History tab, at the inspector's width. The window
// snapshots can't show it: the offscreen render draws the split view's
// columns blank, so the History tab only appears here. Over an opened
// "portrait.jpg" with 12 edits: `historyInspector`, the last step current;
// `historyInspectorJumped`, the image walked back to step 2 so the ten rows
// past it read "not applied". Light and Dark. Writes
// photo-history-inspector-{light,dark}.png and
// photo-history-inspector-jumped-{light,dark}.png. `rowsSitOnTheInspectorInset`
// checks the current row's tint stops at the inspector's 12 pt inset, the
// edge the header card and every Adjust card share, rather than running to
// the column's edges. macOS only.
import CoreRaster
import PhotoModel
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

@MainActor
@Suite struct PhotoHistoryInspectorSnapshots {
    /// An opened 640 x 480 "portrait.jpg" with 12 edits, each its own step.
    private func edited() throws -> PhotoWorkspace {
        let (w, h) = (640, 480)
        var model = PhotoWorkspace()
        try model.open(rgba8: [UInt8](repeating: 210, count: w * h * 4), width: w, height: h, name: "portrait.jpg")
        model.selectTool(.brush)
        for row in 0..<8 {
            let y = Double(60 + row * 45)
            model.drag(from: Mask.Point(x: 80, y: y), to: Mask.Point(x: 560, y: y))
            model.endDrag()
        }
        model.adjust(.exposure(0.4))
        model.endAdjust()
        model.adjust(.curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.6), CurvePoint(x: 1, y: 1)]))
        model.endAdjust()
        model.rotateImage(.degrees90)
        model.rotateImage(.degrees90)
        return model
    }

    /// The inspector at its ideal width on the History tab, as tall as the window's inspector column.
    private func inspector(_ model: PhotoWorkspace) -> some View {
        PhotoPanel(model: model)
            .environment(\.photoInspectorTab, .history)
            .frame(width: SuiteSize.inspectorWidth.ideal, height: 900 - 2 * SuiteSpacing.xxl, alignment: .topLeading)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
    }

    private func snapshots(_ model: PhotoWorkspace, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(inspector(model), name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func historyInspector() throws {
        let model = try edited()
        #expect(model.historyListing.steps.count == 12 && model.historyListing.index == 12)
        try snapshots(model, name: "photo-history-inspector")
    }

    @Test func historyInspectorJumped() throws {
        var model = try edited()
        model.jumpToHistoryStep(2)
        #expect(model.historyListing.index == 2 && model.historyListing.steps.count == 12)
        try snapshots(model, name: "photo-history-inspector-jumped")
    }

    @Test func rowsSitOnTheInspectorInset() throws {
        var model = try edited()
        model.jumpToHistoryStep(2)
        let image = try #require(render(inspector(model), scheme: .light))
        // The render centres the padded inspector in the 1440 pt frame.
        let width = Int(SuiteSize.inspectorWidth.ideal)
        let left = (image.pixelsWide - width) / 2
        func rgb(_ x: Int, _ y: Int) -> [CGFloat] {
            guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return [] }
            return [c.redComponent, c.greenComponent, c.blueComponent].map { ($0 * 255).rounded() }
        }
        // The panel's own fill, well below the last row; the current row is the first
        // tinted line down the panel's middle under the tabs.
        let panel = rgb(left + 120, 800)
        let middle = left + width / 2
        let top = try #require((200..<700).first { rgb(middle, $0) != panel }, "no tinted row")
        let row = top + Int(SuiteSize.studioRow / 2)
        #expect(rgb(middle, row) != panel)
        #expect(rgb(left + 4, row) == panel, "the row's tint reaches the inspector's left edge")
        #expect(rgb(left + width - 4, row) == panel, "and its right edge")
    }
}
