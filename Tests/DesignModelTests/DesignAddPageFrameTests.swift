// DesignAddPageFrameTests.swift: Page > Add Page seeds its page with the same
// "Desktop" frame File > New File gives Page 1. Runs on Linux and macOS.
import DesignModel
import Testing

/// The node with every field but its id, so frames seeded on different pages compare equal.
private func shape(_ node: DesignNode) -> DesignNode {
    DesignNode(
        id: "", name: node.name, kind: node.kind, frame: node.frame, children: node.children,
        isHidden: node.isHidden, isLocked: node.isLocked, fill: node.fill, text: node.text)
}

@Test func addedPageHoldsTheSameDesktopFrameAsNewFile() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let first = try #require(workspace.pages.first?.nodes.first)
    workspace.addPage()
    let added = try #require(workspace.selectedPage)
    #expect(added.id == "page-2")
    #expect(added.nodes.count == 1)
    let frame = try #require(added.nodes.first)
    #expect(frame.name == "Desktop")
    #expect(frame.kind == .frame)
    #expect(frame.frame == DesignRect(x: 0, y: 0, width: added.frameWidth, height: added.frameHeight))
    #expect(frame.id != first.id)
    #expect(shape(frame) == shape(first))
}

@Test func undoingAddPageRemovesItsFrameWithThePage() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    workspace.undo()
    #expect(workspace.pages.map(\.id) == ["page-1"])
    #expect(workspace.pages.first?.nodes.map(\.name) == ["Desktop"])
}
