// SuiteAnchorSnapshots.swift (anchor-parenting AN-5): suite-gallery-anchor-{light,dark}.png,
// Box 1's anchor on its top left corner (an open menu can't be snapshotted). macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteAnchorSnapshots {
    @Test func screens() throws {
        var board = GalleryAnchorBoard()
        _ = board.send(AnchorRows.command(at: .topLeft, layer: "box-1"))
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryAnchorPage(board: board), name: "suite-gallery-anchor-\(scheme.name)", scheme: scheme)
        }
    }
}
