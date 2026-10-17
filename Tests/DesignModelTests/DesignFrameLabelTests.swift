// DesignFrameLabelTests.swift: where the canvas puts a frame's name (#1387).
// Above the frame when the artboard has room for it, inside otherwise, and
// never above the artboard's top. Runs on Linux and macOS.
import DesignModel
import Testing

/// The name is 14 points tall, 2 above the frame or 4 inside it.
private func place(frameTop: Double, artboardTop: Double) -> DesignFrameLabel {
    DesignFrameLabel.place(frameTop: frameTop, artboardTop: artboardTop, labelHeight: 14, gap: 2, inset: 4)
}

@Test func aFrameAtThePageTopKeepsItsNameInsideOnAnOffsetArtboard() {
    // The frame sits at page y = 0; the artboard's top is 120 points down the view.
    let label = place(frameTop: 120, artboardTop: 120)
    #expect(label == .inside(top: 124))
    #expect(label.isInside)
}

@Test func aFrameJustBelowThePageTopStillHasNoRoomAbove() {
    // 10 points down: a 14-point name and its gap would cross the artboard's top.
    #expect(place(frameTop: 130, artboardTop: 120) == .inside(top: 134))
}

@Test func aFrameWellBelowThePageTopTakesItsNameAbove() {
    let label = place(frameTop: 320, artboardTop: 120)
    #expect(label == .above(bottom: 318))
    #expect(!label.isInside)
}

@Test func theNameGoesAboveExactlyWhenItAndTheGapFit() {
    // 16 points of room: 14 of name and 2 of gap fit; one point less does not.
    #expect(place(frameTop: 136, artboardTop: 120) == .above(bottom: 134))
    #expect(place(frameTop: 135, artboardTop: 120) == .inside(top: 139))
}

@Test func aFrameCrossingThePageTopShowsItsNameBelowTheArtboardTop() {
    // The frame starts 30 points above the artboard, which clips the canvas there.
    #expect(place(frameTop: 90, artboardTop: 120) == .inside(top: 124))
}

@Test func aFrameAtAnUnusableTopKeepsItsNameInside() {
    #expect(place(frameTop: .nan, artboardTop: 0).isInside)
    #expect(place(frameTop: .infinity, artboardTop: 0).isInside)
}
