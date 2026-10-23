// DesignTextSelectionSnapshots.swift: a new text box opens with its whole draft selected (#3338),
// and that highlight must leave the draft readable. The page is document content, white in both
// themes, and the draft draws in the layer's own ink; in Dark the field's highlight was the dark
// one, so black text sat on near-black (design-text-editing-dark.png). The test draws the editor
// over a white page at 200% and reads the highlight behind "Hello world": light behind black ink
// in Light and Dark. Writes design-text-selected-{light,dark}.png. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignTextSelectionSnapshots {
    @Test(arguments: [ColorScheme.light, .dark])
    func theSelectedDraftStaysReadable(scheme: ColorScheme) throws {
        var model = DesignWorkspace()
        model.newFile()
        model.selectTool(.text)
        let click = DesignPoint(x: 100, y: 100)
        model.drag(from: click, to: click)
        model.endDrag()
        model.setTextDraft("Hello world")
        let node = try #require(model.selectedNode)
        #expect(model.editingTextID == node.id && node.fill == .black)
        let zoom = 2.0
        let view = DesignTextOverlay(model: model, zoom: zoom).background(Color.white)
        try snapshot(view, name: "design-text-selected-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        let image = try #require(render(view, scheme: scheme))
        // The highlight's band: the box's middle half, short of the em the field keeps for the caret.
        let box = DesignTextOverlay.box(for: node, zoom: zoom)
        let field = DesignTextOverlay.field(for: node, draft: model.textDraft, zoom: zoom)
        let em = DesignTextOverlay.fontSize(for: node, zoom: zoom)
        let xs = Int(box.minX) + 3..<Int(box.minX + field.width - em) - 3
        let ys = Int(box.minY + box.height / 4)..<Int(box.minY + box.height * 3 / 4)
        var light = 0
        var total = 0
        for y in ys {
            for x in xs {
                guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                total += 1
                if (c.redComponent + c.greenComponent + c.blueComponent) / 3 > 0.6 { light += 1 }
            }
        }
        #expect(total > 0)
        #expect(Double(light) >= Double(total) * 0.5, "\(light) of \(total) pixels behind the draft are light (\(scheme))")
    }
}
#endif
