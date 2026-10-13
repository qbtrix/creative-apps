// DesignDrawSnapshots.swift: the three drawing tools at work on a new file: a frame drawn on the
// Desktop frame, a rectangle drawn inside that frame (so it becomes the frame's child) and an
// ellipse drawn beside it, with the ellipse, the last thing drawn, selected. Shows the nested
// frame's name above its corner, the Desktop's name inside its own, and the hairline that keeps a
// white frame visible on a white one. Writes design-draw-shapes-light.png and -dark.png.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignDrawSnapshots {
    @Test func frameRectangleAndEllipse() throws {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .frame, from: (160, 160), to: (760, 560))
        drawOnCanvas(&model, .rectangle, from: (220, 240), to: (480, 440))
        drawOnCanvas(&model, .ellipse, from: (860, 300), to: (1200, 700))
        let desktop = try #require(model.selectedPage?.nodes.first)
        #expect(desktop.children.map(\.kind) == [.frame, .ellipse])
        #expect(desktop.children.first?.children.map(\.kind) == [.rectangle])
        #expect(model.selectedNode?.kind == .ellipse)
        try shootCanvas(model, "design-draw-shapes")
    }
}
