// DesignEyedropperOverlayTests.swift (eyedropper DY-3): the Eyedropper's overlay on the canvas (DesignSampleLoupe).
// With the Eyedropper active the canvas's own pointer handler (DesignCanvasFeedback.onPointer, the call its
// continuous hover makes) moves the loupe to the pointer, at the canvas's zoom; with any other tool there is no
// loupe. A click sends exactly one pick to the window, onto the fill; an Option-click exactly one, onto the
// stroke. The hover store is a fresh one bound around each test, so the app's shared one is never touched.
// macOS only.
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

    @Test func theSizeChipsSetTheSampleSize() {
        let model = Self.eyedropper()
        let store = DesignCanvasHover()
        #expect(store.sampleSize == .point)
        store.setSampleSize(.fiveByFive, on: model)
        #expect(store.sampleSize == .fiveByFive)
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
#endif
