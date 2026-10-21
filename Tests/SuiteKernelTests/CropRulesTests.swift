// CropRulesTests.swift (orientation-crop OC-2, turned on by OC-4): an aspect's ratio with an
// orientation, the largest centred frame, a handle drag clamped with the aspect kept, swap and nudge.
import Testing
import SuiteKernel

@Suite struct CropRulesTests {
    static let photo = Rect(minX: 0, minY: 0, maxX: 6000, maxY: 4000)

    /// 4:5 portrait on a 6000 x 4000 photo is 3200 x 4000, centred; the chosen orientation wins
    /// over the photo's, and none follows the photo (Library's old rule).
    @Test(.disabled("waits on OC-4")) func portraitFourFiveIsCentred() {
        #expect(CropAspect.ratio(width: 4, height: 5).ratio(for: (6000, 4000), orientation: .portrait) == 0.8)
        #expect(CropAspect.ratio(width: 4, height: 5).ratio(for: (6000, 4000), orientation: .landscape) == 1.25)
        #expect(CropAspect.ratio(width: 4, height: 5).ratio(for: (6000, 4000), orientation: nil) == 1.25)
        #expect(CropAspect.ratio(width: 4, height: 5).ratio(for: (4000, 6000), orientation: nil) == 0.8)
        #expect(CropAspect.ratio(width: 1, height: 1).ratio(for: (6000, 4000), orientation: .portrait) == 1)
        #expect(CropAspect.original.ratio(for: (6000, 4000), orientation: .portrait) == 1.5)
        #expect(CropAspect.free.ratio(for: (6000, 4000), orientation: nil) == nil)
        #expect(CropRules.largest(.ratio(width: 4, height: 5), orientation: .portrait, in: Self.photo)
            == Rect(minX: 1400, minY: 0, maxX: 4600, maxY: 4000))
        #expect(CropRules.largest(.free, orientation: nil, in: Self.photo) == Self.photo)
    }

    /// Swap turns the 4:5 frame into 5:4 about its centre, clamped to 5000 x 4000 inside the photo;
    /// a smaller frame keeps the share of the photo it fills (an eighth here) and stays inside.
    @Test(.disabled("waits on OC-4")) func swapGivesFiveFour() {
        let portrait = Rect(minX: 1400, minY: 0, maxX: 4600, maxY: 4000)
        #expect(CropRules.swapped(portrait, in: Self.photo) == Rect(minX: 500, minY: 0, maxX: 5500, maxY: 4000))
        let small = Rect(minX: 0, minY: 0, maxX: 400, maxY: 500)
        #expect(CropRules.swapped(small, in: Self.photo) == Rect(minX: 0, minY: 0, maxX: 625, maxY: 500))
    }

    /// A corner dragged past the photo's edge stops at it with the ratio kept within 1 px; the
    /// opposite corner stays; an edge drag keeps the centre; inside moves without resizing.
    @Test(.disabled("waits on OC-4")) func cornerDragStopsAtTheEdge() {
        let frame = Rect(minX: 2000, minY: 1000, maxX: 3600, maxY: 3000)
        let r = CropRules.drag(frame, handle: .bottomRight, to: Point(x: 7000, y: 5000), aspect: 0.8, bounds: Self.photo)
        #expect(r.minX == 2000 && r.minY == 1000 && r.maxX <= 6000 && r.maxY <= 4000)
        #expect(r.maxY == 4000 && abs(r.width - r.height * 0.8) <= 1)
        let free = CropRules.drag(frame, handle: .topLeft, to: Point(x: -50, y: 500), aspect: nil, bounds: Self.photo)
        #expect(free == Rect(minX: 0, minY: 500, maxX: 3600, maxY: 3000))
        let edge = CropRules.drag(frame, handle: .right, to: Point(x: 4400, y: 2000), aspect: 0.8, bounds: Self.photo)
        #expect(edge.width == 2400 && edge.height == 3000 && edge.minX == 2000 && (edge.minY + edge.maxY) / 2 == 2000)
        let moved = CropRules.drag(frame, handle: .inside, to: Point(x: 5900, y: 2000), aspect: 0.8, bounds: Self.photo)
        #expect(moved == Rect(minX: 4400, minY: 1000, maxX: 6000, maxY: 3000))
    }
}
