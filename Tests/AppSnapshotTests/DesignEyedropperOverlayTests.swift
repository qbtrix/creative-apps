// DesignEyedropperOverlayTests.swift (eyedropper DY-3): the Eyedropper's overlay on the canvas (DesignSampleLoupe).
// With the Eyedropper active the canvas's own pointer handler (DesignCanvasFeedback.onPointer, the call its
// continuous hover makes) moves the loupe to the pointer, at the canvas's zoom; with any other tool there is no
// loupe. A click sends exactly one pick to the window, onto the fill; an Option-click exactly one, onto the
// stroke; with Stroke chosen in the inspector the two swap. The loupe reads the Model's sample size, and the
// options (DesignSampleOptions) sit in the inspector, inside the window and clear of the artboard. The hover
// store is a fresh one bound around each test, so the app's shared one is never touched. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor @Suite struct DesignEyedropperOverlayTests {
    /// The cards fixture with the Eyedropper active.
    static func eyedropper() -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.selectTool(.eyedropper)
        return model
    }

    /// The picks a click at `location` (artboard points at `zoom`) with `modifiers` sends.
    static func picks(_ model: DesignWorkspace, at location: CGPoint, zoom: Double, _ modifiers: DesignModifiers)
        -> [(point: DesignPoint, toStroke: Bool)]
    {
        var sent: [DesignIntent] = []
        let overlay = DesignSampleLoupe(model: model, zoom: zoom, perform: { sent.append($0) })
        overlay.pick(at: location, modifiers: modifiers)
        return sent.map { intent in
            if case .pick(let point, let toStroke) = intent { return (point, toStroke) }
            return (DesignPoint(x: -1, y: -1), false)
        }
    }

    @Test func theLoupeTracksThePointer() throws {
        let model = Self.eyedropper()
        let store = DesignCanvasHover()
        try DesignCanvasHover.$bound.withValue(store) {
            let handler = try #require(DesignCanvasFeedback(model: model, zoom: 2).onPointer)
            for (x, y) in [(150.0, 140.0), (310.0, 160.0), (40.0, 900.0)] {
                handler(CGPoint(x: x, y: y))
                let loupe = try #require(store.loupe(for: model), "no loupe at \(x), \(y)")
                #expect(loupe.point == DesignPoint(x: x, y: y))
                #expect(DesignSampleLoupe.place(loupe, zoom: 2) == CGPoint(x: x * 2, y: y * 2))
            }
            handler(nil)
            #expect(store.loupe(for: model) == nil, "the loupe stayed after the pointer left")
        }
    }

    @Test func noLoupeWithAnotherTool() {
        var model = Self.eyedropper()
        model.selectTool(.move)
        let store = DesignCanvasHover()
        store.record(DesignPoint(x: 150, y: 140), modifiers: [], on: model)
        #expect(store.loupe(for: model) == nil)
        #expect(Self.picks(model, at: CGPoint(x: 150, y: 140), zoom: 1, []).isEmpty, "a Move click picked a colour")
    }

    /// #3989: the size is the Model's, so the loupe the store shows reads the square the inspector chose.
    @Test func theLoupeFollowsTheModelsSampleSize() {
        var model = Self.eyedropper()
        let store = DesignCanvasHover()
        store.record(DesignPoint(x: 150, y: 140), modifiers: [], on: model)
        model.setSampleSize(.fiveByFive)
        #expect(store.loupe(for: model) == model.loupe(at: DesignPoint(x: 150, y: 140), modifiers: []))
    }

    /// #3993: with Stroke chosen in the inspector a plain click picks the stroke, and Option the fill.
    @Test func theStrokeOptionTurnsAPlainClickOntoTheStroke() {
        var model = Self.eyedropper()
        model.setSampleTarget(toStroke: true)
        #expect(Self.picks(model, at: CGPoint(x: 150, y: 140), zoom: 1, []).map(\.toStroke) == [true])
        #expect(Self.picks(model, at: CGPoint(x: 150, y: 140), zoom: 1, .option).map(\.toStroke) == [false])
    }

    @Test func aClickSendsOneFillPick() {
        let picks = Self.picks(Self.eyedropper(), at: CGPoint(x: 300, y: 280), zoom: 2, [])
        #expect(picks.count == 1, "a click sent \(picks.count) picks")
        #expect(picks.first?.point == DesignPoint(x: 150, y: 140))
        #expect(picks.first?.toStroke == false)
    }

    @Test func anOptionClickSendsOneStrokePick() {
        let picks = Self.picks(Self.eyedropper(), at: CGPoint(x: 150, y: 140), zoom: 1, .option)
        #expect(picks.count == 1, "an Option-click sent \(picks.count) picks")
        #expect(picks.first?.point == DesignPoint(x: 150, y: 140))
        #expect(picks.first?.toStroke == true)
    }
}

extension BodyCountSuites {
    /// #3985, #3986: the Eyedropper's options sit in the inspector, inside the window and clear of the artboard,
    /// each control big enough to click and the two apart. The real window counts its bodies in statics, so this
    /// runs with the other body-count suites, one at a time.
    @MainActor @Suite struct DesignEyedropperOptionsLayoutTests {
        @Test(.timeLimit(.minutes(1))) func theOptionsSitInTheInspector() async throws {
            let window = CGRect(x: 0, y: 0, width: 1440, height: 900)
            let w = RenderBudgetWindow(DesignWindow(seed: DesignEyedropperOverlayTests.eyedropper()), size: window.size)
            defer { w.close() }
            try await w.settle(500)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            let inspector = try #require(await w.element("design.properties"), "no inspector")
            let chip = try #require(await w.element("suite.sample.size.1"), "no size chip")
            let target = try #require(await w.element("design.sample.target"), "no Fill/Stroke picker")
            for (name, frame) in [("size chip", chip), ("Fill/Stroke picker", target)] {
                #expect(window.contains(frame), "the \(name) \(frame) leaves the window")
                #expect(inspector.insetBy(dx: -1, dy: -1).contains(frame), "the \(name) \(frame) is outside the inspector")
                #expect(!frame.intersects(board), "the \(name) \(frame) covers the artboard \(board)")
                #expect(frame.height >= 20 && frame.width >= 24, "the \(name) \(frame) is too small to click")
            }
            #expect(!chip.intersects(target), "the size chips overlap the Fill/Stroke picker")
        }
    }
}
#endif
