// PhotoTransformLiveTests.swift: which Free Transform edits change only the
// draft (`editsDraftOnly`, finding #4247), so the window can run a handle
// drag's or a Rotation scrub's steps on a live copy and take it back once.
// A set, turn or scale while a draft is up is draft-only;
// a flip, Reset, or any edit with no draft up is not. A draft-only edit run
// on a copy leaves every pixel and layer as it was, and adopting the copy
// gives the workspace the edits made in place would. Runs on Linux and macOS.
import CoreRaster
import Foundation
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoTransformLiveTests {
    /// A 64 x 48 image under a 20 x 10 pasted layer, selected.
    private func pasted() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .live)
        try workspace.newCanvas(width: 64, height: 48)
        let bytes = [UInt8](repeating: 200, count: 20 * 10 * 4)
        workspace.paste(ClipboardImage(image: DecodedImage(rgba8: bytes, width: 20, height: 10),
                                       source: PixelRect(x: 8, y: 6, width: 20, height: 10)),
                        viewCenter: Mask.Point(x: 32, y: 24))
        return workspace
    }

    private func run(_ edit: TransformIntent, on workspace: inout PhotoWorkspace) throws {
        let (id, params) = edit.command
        _ = try PhotoWorkspace.catalog.run(id, params: params, on: &workspace)
    }

    @Test func noDraftEditsMoreThanTheDraft() throws {
        let workspace = try pasted()
        let box = try #require(workspace.transformSelection)
        #expect(!workspace.editsDraftOnly(.rotate(by: 10, drag: "t")))
        #expect(!workspace.editsDraftOnly(.set(box, drag: "t")))
        #expect(!workspace.editsDraftOnly(.scale(sx: 2, sy: 2, anchor: .center, drag: "t")))
    }

    @Test func turnSetAndScaleOnADraftAreDraftOnly() throws {
        var workspace = try pasted()
        try workspace.beginTransform()
        var box = try #require(workspace.transformSelection)
        box.box = Rect(minX: box.box.minX, minY: box.box.minY, maxX: box.box.maxX + 30, maxY: box.box.maxY + 20)
        #expect(workspace.editsDraftOnly(.rotate(by: 10, drag: "t")))
        #expect(workspace.editsDraftOnly(.set(box, drag: "t")))
        #expect(workspace.editsDraftOnly(.scale(sx: 2, sy: 2, anchor: .center, drag: nil)))
    }

    @Test func flipsAndResetAreNotDraftOnly() throws {
        var workspace = try pasted()
        try workspace.beginTransform()
        #expect(!workspace.editsDraftOnly(.flip(.horizontal)))
        #expect(!workspace.editsDraftOnly(.flip(.vertical)))
        #expect(!workspace.editsDraftOnly(.reset))
    }

    @Test func aLiveCopyMatchesEditsInPlace() throws {
        var workspace = try pasted()
        try workspace.beginTransform()
        let start = try #require(workspace.transformSelection)
        var grown = start
        grown.box = Rect(minX: start.box.minX, minY: start.box.minY, maxX: start.box.maxX + 12, maxY: start.box.maxY + 8)
        let edits: [TransformIntent] = [.set(grown, drag: "drag"), .rotate(by: 5, drag: "scrub"), .rotate(by: 5, drag: "scrub")]
        var inPlace = workspace
        var live = workspace
        for edit in edits {
            #expect(live.editsDraftOnly(edit))
            try run(edit, on: &inPlace)
            try run(edit, on: &live)
        }
        #expect(live.pixels == workspace.pixels && live.layers == workspace.layers)
        #expect(live.transformSelection?.degrees == 10)
        var adopted = workspace
        adopted.adoptLiveStroke(live)
        #expect(adopted == inPlace)
        #expect(adopted.transformSelection == inPlace.transformSelection)
    }
}
