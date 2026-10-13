// PhotoNoImageStateAdversarialTests.swift: tries to knock Photo out of, or
// wrongly into, its "No Image Open" empty state with bad sizes and bad bytes,
// and checks the shared title, symbol and message stay usable. Runs on Linux
// and macOS.
import PhotoModel
import Testing

@Test(arguments: [(0, 0), (0, 10), (10, 0), (-1, 5), (5, -1), (Int.min, 1), (1, Int.min)])
func badNewCanvasSizesKeepTheNoImageState(width: Int, height: Int) {
    var workspace = PhotoWorkspace()
    try? workspace.newCanvas(width: width, height: height)
    #expect(workspace.inspectorContent == .noImage)
    #expect(workspace.canvas == nil)
}

@Test(arguments: [
    ([UInt8](), 1, 1),
    ([UInt8](repeating: 255, count: 3), 1, 1),
    ([UInt8](repeating: 255, count: 5), 1, 1),
    ([UInt8](repeating: 255, count: 4), 0, 1),
    ([UInt8](repeating: 255, count: 4), 2, 2),
])
func badBytesKeepTheNoImageState(bytes: [UInt8], width: Int, height: Int) {
    var workspace = PhotoWorkspace()
    try? workspace.open(rgba8: bytes, width: width, height: height, name: "bad.png")
    #expect(workspace.inspectorContent == .noImage)
    #expect(workspace.documentName == nil)
}

@Test func aFailedOpenOverAnOpenImageKeepsThatImage() throws {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 4, height: 3)
    try? workspace.open(rgba8: [1, 2, 3], width: 1, height: 1, name: "bad.png")
    try? workspace.newCanvas(width: 0, height: 0)
    let layer = try #require(workspace.selectedLayer)
    #expect(workspace.inspectorContent == .layer(layer, width: 4, height: 3))
}

@Test func aOnePixelImageLeavesTheNoImageState() throws {
    var workspace = PhotoWorkspace()
    try workspace.open(rgba8: [0, 0, 0, 0], width: 1, height: 1, name: "dot.png")
    guard case .layer(_, let width, let height) = workspace.inspectorContent else {
        Issue.record("expected a layer, got \(workspace.inspectorContent)")
        return
    }
    #expect(width == 1 && height == 1)
}

@Test func noImageTitleSymbolAndMessageAreUsableText() {
    for text in [PhotoInspectorContent.noImageTitle, PhotoInspectorContent.noImageSymbol, PhotoInspectorContent.noImageMessage] {
        #expect(!text.isEmpty)
        #expect(text.first?.isWhitespace == false && text.last?.isWhitespace == false)
        #expect(!text.contains { $0.isNewline })
    }
    // An SF Symbol name is lowercase dot-separated words, no spaces.
    #expect(PhotoInspectorContent.noImageSymbol.allSatisfy { $0.isLowercase || $0 == "." })
    // The message is a sentence; the title is not one.
    #expect(PhotoInspectorContent.noImageMessage.hasSuffix("."))
    #expect(!PhotoInspectorContent.noImageTitle.hasSuffix("."))
}
