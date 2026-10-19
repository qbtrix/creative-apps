// LibraryLayoutSnapshots.swift: layout spec 7.3 checked against SuiteUI
// (status-and-layout SL-7). LibraryModel can't import SuiteUI, so
// LibraryLayout stores its tokens as values; here they meet the real ones.
// For every window width of 7.3, inspector 200, 240 and 360 and cell 80 to
// 320 in 40 pt steps, LibraryLayout's column count equals GridSelection's
// over the padded content width; its defaults equal SuiteSize and
// SuiteSpacing. Writes library-layout-1280, library-layout-1440 and
// library-layout-1920.png: the Library grid and status bar on the shoot
// fixture at those widths. The offscreen host draws no toolbar, sidebar or
// inspector (system split-view and glass chrome), so those columns come out
// blank; the journey's `layout-<w>` shots are the whole window. macOS only.
import AppKit
import Foundation
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryLayoutSnapshots {
    /// The window widths of layout spec 7.3.
    nonisolated static let widths: [Double] = [880, 1024, 1280, 1440, 1920]
    nonisolated static let inspectors: [Double] = [200, 240, 360]
    nonisolated static let cells: [Double] = Array(stride(from: 80.0, through: 320, by: 40))

    @Test func gridColumnsMatchGridSelection() {
        let m = Double(SuiteSpacing.m), xs = Double(SuiteSpacing.xs)
        #expect(Self.cells.count == 7)
        for window in Self.widths {
            for inspector in Self.inspectors {
                var layout = LibraryLayout()
                layout.inspector = inspector
                let content = layout.contentWidth(window: window)
                for cell in Self.cells {
                    let expected = GridSelection.columns(width: content - 2 * m, minimum: cell + 2 * xs, spacing: m)
                    let actual = layout.gridColumns(contentWidth: content, cell: cell)
                    #expect(
                        actual == expected,
                        "window \(window), inspector \(inspector), cell \(cell): \(actual) columns, SuiteUI \(expected)")
                }
            }
        }
    }

    @Test func defaultsMatchTheTokens() {
        let layout = LibraryLayout()
        #expect(layout.sidebar == Double(SuiteSize.sidebarWidth.ideal))
        #expect(layout.inspector == Double(SuiteSize.inspectorWidth.ideal))
        #expect(layout.gridPadding == Double(SuiteSpacing.m))
        #expect(layout.gridSpacing == Double(SuiteSpacing.m))
        #expect(layout.cellInset == Double(SuiteSpacing.xs))
        #expect(layout.canvasInset == Double(SuiteSize.canvasInset))
    }

    /// The Library window on the shoot fixture at 1280 × 800, 1440 × 900 and
    /// 1920 × 1080. Only the grid and status bar draw here; read the window
    /// chrome from the journey's `layout-<w>` shots (ui-screens).
    @Test func windowAtWidths() throws {
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let host = SnapshotHost(appearance: .light)
        for size in [CGSize(width: 1280, height: 800), CGSize(width: 1440, height: 900), CGSize(width: 1920, height: 1080)] {
            let window = LibraryWindow(arguments: ["Library", "-LibraryFixture", "shoot"])
            let image = try #require(host.render(window, size: size))
            #expect(image.pixelsWide == Int(size.width * SnapshotHost.scale))
            let png = try #require(image.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "library-layout-\(Int(size.width)).png"))
        }
    }
}
