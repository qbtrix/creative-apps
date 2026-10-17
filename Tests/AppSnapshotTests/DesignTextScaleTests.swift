// DesignTextScaleTests.swift: the inline editor sits exactly where the committed text draws
// (style-rows ST-5t, QD-V7, #268). On `cards` with Title (node-5) at 32 pt Bold, at 25%, 50%,
// 100% and 200%: the editor's box (DesignTextOverlay.box) is the frame the artwork draws the
// committed text in (the node's frame times the canvas zoom) within 1 pt, and the editor's font
// is the artwork's font at the style's size × the zoom. macOS only.
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignTextScaleTests {
    private let zooms = [0.25, 0.5, 1, 2]

    /// Title on `cards`, `.fake`, set to 32 pt Bold, edited and committed as "Big title".
    private func title() throws -> DesignNode {
        var model = DesignWorkspace()
        model.useServices(.fake)
        #expect(model.openFixture("cards"))
        model.selectItem("node-5")
        var style = try #require(model.selectedNode).textStyle
        style.size = 32
        style.weight = 700
        try model.setStyle(.textStyle(style))
        model.endEditRun()
        try model.beginTextEdit("node-5")
        model.setTextDraft("Big title")
        model.commitTextEdit()
        let node = try #require(model.findNode("node-5"))
        #expect(node.text == "Big title" && node.textStyle == style)
        return node
    }

    @Test func theEditorsFrameIsTheCommittedFrameAtEveryZoom() throws {
        let node = try title()
        for zoom in zooms {
            let committed = node.frame.cgRect.applying(CGAffineTransform(scaleX: usable(zoom), y: usable(zoom)))
            let editor = DesignTextOverlay.box(for: node, zoom: zoom)
            #expect(abs(editor.minX - committed.minX) <= 1, "left at \(zoom)")
            #expect(abs(editor.minY - committed.minY) <= 1, "top at \(zoom)")
            #expect(abs(editor.width - committed.width) <= 1, "width at \(zoom)")
            #expect(abs(editor.height - committed.height) <= 1, "height at \(zoom)")
        }
    }

    @Test func theEditorsFontIsTheStyleSizeTimesTheZoom() throws {
        let node = try title()
        let committed = DesignTextFont.nsFont(node.textStyle)
        for zoom in zooms {
            #expect(DesignTextOverlay.fontSize(for: node, zoom: zoom) == node.textStyle.size * zoom, "zoom \(zoom)")
            let editor = DesignTextFont.nsFont(node.textStyle, scale: DesignWorkspace.textEditScale(zoom: zoom))
            #expect(editor.pointSize == node.textStyle.size * zoom, "zoom \(zoom)")
            #expect(editor.fontName == committed.fontName, "zoom \(zoom)")
        }
    }

    @Test func aZoomThatIsntUsableCountsAsOne() throws {
        let node = try title()
        for zoom in [0, -1, Double.nan, .infinity] {
            #expect(DesignTextOverlay.box(for: node, zoom: zoom) == node.frame.cgRect)
            #expect(DesignTextOverlay.fontSize(for: node, zoom: zoom) == node.textStyle.size)
        }
    }
}
