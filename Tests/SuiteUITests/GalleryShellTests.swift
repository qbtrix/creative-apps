// GalleryShellTests.swift: the gallery's `shell` page is registered, owns its
// back button (the gallery skips its back row for it), and its model counts
// bodies per instance and toggles nothing before a controller exists. macOS only.
@testable import SuiteUI
import Testing

@MainActor @Suite struct GalleryShellTests {
    @Test func theShellPageIsListedAndOwnsItsBackButton() {
        #expect(SuiteGallery.pageNames.contains(GalleryShell.name))
        #expect(SuiteGallery.resolve(GalleryShell.name) == .page(GalleryShell.name))
        #expect(SuiteGallery.ownsBackButton(GalleryShell.name))
        #expect(!SuiteGallery.ownsBackButton(GalleryEditorWindow.name))
        #expect(!SuiteGallery.ownsBackButton(GalleryIndex.name))
    }

    @Test func theModelCountsItsOwnBodiesAndTogglesNothingWithoutAController() {
        let model = ShellSpikeModel()
        #expect(model.rootBodies == 0)
        model.countBody()
        model.countBody()
        #expect(model.rootBodies == 2)
        #expect(ShellSpikeModel().rootBodies == 0)
        model.toggleSidebar()
        model.toggleInspector()
        #expect(model.controller == nil)
    }
}
