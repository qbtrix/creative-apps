// DesignTrackOffsetTests.swift: a moved copy keeps its animation (one-document OD-6, rule 2 of 4). Duplicate, paste,
// Option-drag and a rest-pose move shift a keyed node's x and y keys with its frame, so the node shows at the same
// offset at every frame; opacity keys stay. On `animated(50)` node-2 rests at 30, 30 and shows 47, 40 at frame 60
// (its frame node-1 keys x 10 to 20). Copy as SVG draws the rest pose. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignTrackOffsetTests {
    static let page = DesignFixtures.animated(50).selectedPage!

    /// Node `id` of `nodes` as it shows at `frame`.
    static func shown(_ nodes: [DesignNode], _ id: String, at frame: Double) -> DesignPoint {
        var page = Self.page
        page.nodes = nodes
        let node = page.sampled(at: frame).nodes.node(id)!
        return DesignPoint(x: node.frame.x, y: node.frame.y)
    }

    static func near(_ a: DesignPoint, _ x: Double, _ y: Double) -> Bool { abs(a.x - x) < 0.01 && abs(a.y - y) < 0.01 }

    @Test func aDuplicateShowsAtItsOffsetAtEveryFrame() throws {
        var mint = DesignIDMint(taken: [], after: 1000)
        let edit = try LiveDuplicating().duplicate(["node-2"], offset: DesignPoint(x: 10, y: 10), on: Self.page, mint: &mint)
        let copy = try #require(edit.selection.first)
        #expect(Self.near(Self.shown(edit.nodes, copy, at: 60), 57, 50))
        #expect(Self.near(Self.shown(edit.nodes, copy, at: 0), 40, 40))
        let (old, new) = (Self.page.nodes.node("node-2")!.time!, edit.nodes.node(copy)!.time!)
        #expect(new.tracks.mapValues(\.count) == old.tracks.mapValues(\.count))
        #expect(new.tracks[.opacity] == old.tracks[.opacity])
    }

    @Test func aPasteOnItsOriginalOffsetsItsKeysAndAcrossPagesKeepsThem() throws {
        let data = try LiveClipboard().encode(["node-2"], on: Self.page)
        var mint = DesignIDMint(taken: [], after: 1000)
        let here = try LiveClipboard().paste(data, into: nil, on: Self.page, mint: &mint)
        let copy = try #require(here.selection.first)
        #expect(Self.near(Self.shown(here.nodes, copy, at: 60), 57, 50))
        #expect(Self.near(Self.shown(here.nodes, copy, at: 0), 40, 40))
        let other = DesignPage(id: "page-2", name: "Page 2", frameWidth: 1440, frameHeight: 1024, nodes: [])
        let there = try LiveClipboard().paste(data, into: nil, on: other, mint: &mint)
        #expect(there.nodes.first?.time == Self.page.nodes.node("node-2")?.time)
    }

    @Test func aRestMoveCarriesTheKeysOfTheNodeAndItsChildren() throws {
        // node-1 keys x only: a y move at 60 moves its rest pose, and node-2's y keys move with it.
        let y = try LiveTransforming().move(["node-1"], by: DesignPoint(x: 0, y: 5), on: Self.page, at: 60)
        #expect(Self.near(Self.shown(y.nodes, "node-2", at: 60), 47, 45))
        #expect(Self.near(Self.shown(y.nodes, "node-2", at: 0), 30, 35))
        // No playhead: the whole animation moves with the rest pose.
        let still = try LiveTransforming().move(["node-2"], by: DesignPoint(x: 100, y: 0), on: Self.page)
        #expect(Self.near(Self.shown(still.nodes, "node-2", at: 60), 147, 40))
        #expect(Self.near(Self.shown(still.nodes, "node-2", at: 0), 130, 30))
        // `writing` x with no playhead moves the frame's keys and node-2's by 90.
        let x = Self.page.nodes.node("node-1")!.writing(.x, 100, at: nil)
        #expect(x.time?.tracks[.x]?.map(\.value) == [100, 110])
        #expect(x.children.node("node-2")?.time?.tracks[.x]?.map(\.value) == [120, 144])
    }

    @Test func anOptionDragCopyShowsAtTheDragOffsetAtEveryFrame() throws {
        var workspace = DesignFixtures.animated(50)
        workspace.useServices(.live)
        workspace.playhead = 60
        workspace.selectItem("node-2")
        workspace.drag(from: DesignPoint(x: 51, y: 44), to: DesignPoint(x: 151, y: 44), modifiers: [.option])
        workspace.endDrag()
        let nodes = try #require(workspace.selectedPage?.nodes)
        let copy = try #require(workspace.selectedNodeIDs.first)
        #expect(copy != "node-2")
        let (at60, at0) = (Self.shown(nodes, copy, at: 60), Self.shown(nodes, copy, at: 0))
        #expect(at60.x - 47 > 50)
        #expect(abs((at60.x - 47) - (at0.x - 30)) < 0.01)
        #expect(nodes.node("node-2") == Self.page.nodes.node("node-2"))
    }

    @Test func copyAsArtDrawsTheRestPose() throws {
        var workspace = DesignFixtures.animated(50)
        workspace.playhead = 60
        workspace.selectItem("node-2")
        #expect(try workspace.selectionArt().box.x == 30)
    }
}
