// DesignFramingTests.swift: View > Zoom to Selection on the live services
// (LiveFraming) against the `cards` frames (blueprint 4): one layer frames
// itself, two frame their union, a hidden layer frames nothing and the help
// says why, and the help is nil exactly when there is a rect. Runs on Linux
// and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignFramingTests {
    /// The part of `cards` these checks read: Desktop holding A, C and the hidden layer.
    let page: DesignPage = {
        var page = DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024)
        page.nodes = [
            DesignNode(id: "Desktop", name: "Desktop", kind: .frame, frame: rc(0, 0, 1440, 1024), children: [
                DesignNode(id: "A", name: "A", kind: .rectangle, frame: rc(100, 100, 100, 80)),
                DesignNode(id: "C", name: "C", kind: .rectangle, frame: rc(700, 100, 100, 120)),
                DesignNode(id: "Hidden", name: "Hidden", kind: .rectangle, frame: rc(600, 600, 100, 100), isHidden: true),
            ])
        ]
        return page
    }()
    let framing = LiveFraming()

    @Test func oneLayerFramesItsOwnFrame() {
        #expect(framing.rectToShow(["C"], on: page) == rc(700, 100, 100, 120))
        #expect(framing.framingHelp(["C"], on: page) == nil)
    }

    @Test func twoLayersFrameTheirUnion() {
        #expect(framing.rectToShow(["A", "C"], on: page) == rc(100, 100, 700, 120))
        #expect(framing.framingHelp(["A", "C"], on: page) == nil)
    }

    @Test func aHiddenLayerFramesNothingAndSaysWhy() {
        #expect(framing.rectToShow(["Hidden"], on: page) == nil)
        #expect(framing.framingHelp(["Hidden"], on: page) == "Select a layer first.")
    }

    @Test func nothingSelectedFramesNothing() {
        #expect(framing.rectToShow([], on: page) == nil)
        #expect(framing.framingHelp([], on: page) == "Select a layer first.")
    }
}
