// LibraryToolTests.swift: the loupe's tool follows its crop draft (#6022):
// `view` in the loupe, `crop` once R opens a draft, `view` again once it is
// applied or cancelled. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

@Suite
struct LibraryToolTests {
    @Test func toolFollowsTheCropDraft() {
        var catalog = cropLiveLoupe()
        #expect(catalog.loupeTool == .view)
        catalog.toggleCrop()
        #expect(catalog.loupeTool == .crop)
        catalog.cancelCrop()
        #expect(catalog.loupeTool == .view)
        catalog.toggleCrop()
        catalog.toggleCrop()
        #expect(catalog.loupeTool == .view)
    }
}
