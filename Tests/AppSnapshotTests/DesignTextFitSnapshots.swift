// DesignTextFitSnapshots.swift: a text box fits its text (canvas-basics CB-6). On a new file, a
// Text click typed "A longer line of text" commits with the draft's measured extent
// (DesignTextFont.measure) and hugs it, wider than the 120 pt default and one line tall; a Text
// drag 150 pt wide typed two sentences keeps W 150, wraps and grows down. Both drawn on the
// canvas at 100% in Light and Dark (design-text-fit-{light,dark}.png). The hosted check opens
// `cards` in the real window with a placed text being edited and presses the canvas's blank
// area: by the time the press reaches the workspace the edit is committed with the box fitted.
// It reads DesignWindow.lastWorkspace, a static, so it nests in BodyCountSuites. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

/// A Text click (`to` nil) or drag from `from` typed `draft`, committed with its measured extent.
@MainActor private func placeText(
    _ model: inout DesignWorkspace, from: DesignPoint, to: DesignPoint? = nil, draft: String
) throws -> DesignNode {
    model.selectTool(.text)
    model.drag(from: from, to: to ?? from)
    model.endDrag()
    let id = try #require(model.editingTextID)
    model.setTextDraft(draft)
    let placed = try #require(model.selectedNode)
    let wrap = placed.textStyle.fixedWidth == true ? placed.frame.width : nil
    model.commitTextEdit(extent: DesignTextFont.measure(draft, placed.textStyle, wrapWidth: wrap))
    #expect(model.undoActionName == "Undo Add Text")
    return try #require(model.findNode(id))
}

@MainActor
@Suite struct DesignTextFitSnapshots {
    static let sentences = "The first sentence runs past the box. The second one wraps below it."

    @Test func autoHugsAndFixedWraps() throws {
        var model = DesignWorkspace()
        model.newFile()
        let auto = try placeText(&model, from: DesignPoint(x: 200, y: 200), draft: "A longer line of text")
        let line = DesignTextFont.measure("A longer line of text", auto.textStyle, wrapWidth: nil)
        #expect(auto.textStyle.fixedWidth != true)
        #expect(auto.frame.width == line.width.rounded(.up) && auto.frame.width > 120, "auto box \(auto.frame)")
        #expect(auto.frame.height == line.height.rounded(.up) && auto.frame.height >= 16)

        let fixed = try placeText(
            &model, from: DesignPoint(x: 200, y: 300), to: DesignPoint(x: 350, y: 324), draft: Self.sentences)
        #expect(fixed.textStyle.fixedWidth == true)
        #expect(fixed.frame.width == 150, "a wrapped box widened: \(fixed.frame)")
        #expect(fixed.frame.height > 2 * auto.frame.height - 1, "the sentences didn't wrap: \(fixed.frame)")
        // Wrapped at the frame, every line fits inside it.
        let wrapped = DesignTextFont.measure(Self.sentences, fixed.textStyle, wrapWidth: 150)
        #expect(wrapped.width <= 150 && fixed.frame.height == wrapped.height.rounded(.up))

        model.selectItem(auto.id)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignCanvas(model: model, zoom: 1), name: "design-text-fit-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct DesignTextFitWindowTests {
        @Test(.timeLimit(.minutes(2))) func aCanvasPressCommitsAFittedBoxFirst() async throws {
            #if DEBUG
            var seed = DesignFixtures.cards
            seed.useServices(.fake)
            seed.selectTool(.text)
            let spot = DesignPoint(x: 72, y: 870)
            seed.drag(from: spot, to: spot)
            seed.endDrag()
            let id = try #require(seed.editingTextID)
            seed.setTextDraft("A longer line of text")
            let style = try #require(seed.selectedNode).textStyle
            let fit = DesignTextFont.measure("A longer line of text", style, wrapWidth: nil)

            let w = RenderBudgetWindow(DesignWindow(seed: seed))
            defer { w.close() }
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            let page = CGSize(width: 1440, height: 1024)
            let blank = w.point(CGPoint(x: 864, y: 921), on: page, in: board)
            DesignWindow.lastWorkspace = nil
            // The press alone: what the workspace holds once it has the press is what it committed.
            try await w.drag(from: blank, samples: 1, release: false) { _ in blank }
            try await w.settle(100)
            let pressed = try #require(DesignWindow.lastWorkspace, "the press never reached the window")
            #expect(pressed.editingTextID == nil)
            let node = try #require(pressed.findNode(id), "the placed text was dropped")
            #expect(node.text == "A longer line of text")
            #expect(node.frame.width == fit.width.rounded(.up) && node.frame.width > 120, "committed \(node.frame)")
            #expect(node.frame.height == fit.height.rounded(.up))
            w.send(.leftMouseUp, at: blank)
            try await w.settle(100)
            let after = try #require(DesignWindow.lastWorkspace)
            #expect(after.findNode(id)?.frame == node.frame)
            #expect(after.undoActionName == "Undo Add Text")
            #endif
        }
    }
}
#endif

#if canImport(AppKit)
/// What SwiftUI's resolved text measures `text` at in `style`, wrapped at `wrap` (nil: one line per
/// paragraph): the size DesignTextArtwork draws it at, read from a Canvas rendered off screen.
@MainActor func drawnTextSize(_ text: String, _ style: DesignTextStyle, wrap: Double?) -> CGSize {
    final class Box { var size = CGSize.zero }
    let box = Box()
    let canvas = Canvas { context, _ in
        let resolved = context.resolve(Text(text).font(DesignTextFont.font(style)))
        box.size = resolved.measure(in: CGSize(width: wrap ?? .infinity, height: .infinity))
    }.frame(width: 10, height: 10)
    _ = ImageRenderer(content: canvas).nsImage
    return box.size
}

@MainActor
@Suite struct DesignTextMeasureTests {
    /// The extent a box commits with holds every line the canvas draws: no wrapped line is cut off
    /// or ends in an ellipsis because the measure and the drawing disagree on line height.
    @Test(arguments: [10.0, 12, 13, 16, 18, 24, 32, 48, 72])
    func measureHoldsTheDrawnText(size: Double) {
        let text = DesignTextFitSnapshots.sentences
        for weight in [400, 700] {
            var style = DesignTextStyle.default
            style.size = size
            style.weight = weight
            for wrap in [nil, 150.0, 400] {
                let drawn = drawnTextSize(text, style, wrap: wrap)
                let measured = DesignTextFont.measure(text, style, wrapWidth: wrap)
                #expect(measured.height >= drawn.height, "size \(size) w\(weight) wrap \(String(describing: wrap)): measured \(measured.height), drawn \(drawn.height)")
                #expect(measured.width >= drawn.width.rounded(.down), "size \(size) w\(weight) wrap \(String(describing: wrap)): measured \(measured.width), drawn \(drawn.width)")
            }
        }
    }
}
#endif
