// CanvasPointMarksTests.swift: CanvasPointMark (CM-7, #706, #737) keeps its
// on-screen size at every zoom while its centre follows the point, draws a
// ring and a cross, survives a silly zoom or point, takes no hit and is
// hidden from accessibility. macOS only.
import SuiteUI
import SwiftUI
import Testing

private let point = CGPoint(x: 40, y: 25)

@Test func thePointMarkKeepsItsSizeAtEveryZoom() throws {
    let sizes = try [0.25, 1, 4, 32].map { try #require(CanvasPointMark.ring(point: point, zoom: $0)).size }
    #expect(sizes.allSatisfy { $0 == CGSize(width: SuiteSize.pointMarkRing, height: SuiteSize.pointMarkRing) })
    let one = CanvasPointMark.path(point: point, zoom: 1).boundingRect.size
    let four = CanvasPointMark.path(point: point, zoom: 4).boundingRect.size
    #expect(abs(one.width - four.width) < 0.01 && abs(one.height - four.height) < 0.01)
    #expect(abs(one.width - SuiteSize.pointMarkRing) < 0.01)
}

@Test func thePointMarkCentresOnThePointAtTheZoom() throws {
    let one = try #require(CanvasPointMark.ring(point: point, zoom: 1))
    let four = try #require(CanvasPointMark.ring(point: point, zoom: 4))
    #expect(one.midX == 40 && one.midY == 25)
    #expect(four.midX == 160 && four.midY == 100)
}

@Test func thePointMarkDrawsARingAndACross() {
    var elements = 0
    var moves = 0
    CanvasPointMark.path(point: point, zoom: 2).forEach { element in
        elements += 1
        if case .move = element { moves += 1 }
    }
    // The ring's subpath and the cross's two strokes each start with a move.
    #expect(moves == 3)
    #expect(elements > moves)
}

@Test func aSillyZoomCountsAsOneAndASillyPointDrawsNothing() throws {
    for zoom in [0, -2, .nan, .infinity] {
        let ring = try #require(CanvasPointMark.ring(point: point, zoom: zoom))
        #expect(ring.midX == 40 && ring.midY == 25 && ring.width == SuiteSize.pointMarkRing)
    }
    #expect(CanvasPointMark.ring(point: CGPoint(x: CGFloat.nan, y: 0), zoom: 1) == nil)
    #expect(CanvasPointMark.path(point: CGPoint(x: 0, y: CGFloat.infinity), zoom: 1).isEmpty)
}

@Test func thePointMarkTakesNoHitAndIsHiddenFromAccessibility() {
    #expect(!CanvasPointMark.takesHits)
    #expect(CanvasPointMark.hiddenFromAccessibility)
}
