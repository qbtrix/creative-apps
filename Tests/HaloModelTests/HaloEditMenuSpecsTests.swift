// HaloEditMenuSpecsTests.swift: clipboard-interop CB-halo. Halo's Edit pasteboard group is built from specs:
// Paste follows the catalog's `edit.paste` and then the pasteboard's refusal, Copy Frame follows `edit.copy-frame`,
// and Cut, Copy and Select All are always off with the reason (a focused text field takes them in the App).
// Linux-safe.
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloEditMenuSpecsTests {
    private func comp() -> HaloProject {
        var project = HaloProject()
        _ = project.newComposition(CompositionSettings(name: "Comp 1"))
        return project
    }

    @Test func pasteSaysThePasteboardsRefusalOnlyWhenTheCatalogAllowsIt() {
        let refusal = "Halo can't paste plain text."
        let open = HaloEditMenuSpecs(menu: HaloMenuState(project: comp()), pasteRefusal: refusal)
        #expect(HaloEditMenuSpecs.paste.availability(open) == .unavailable(refusal))
        let clear = HaloEditMenuSpecs(menu: HaloMenuState(project: comp()), pasteRefusal: nil)
        #expect(HaloEditMenuSpecs.paste.availability(clear) == .available)
        let none = HaloEditMenuSpecs(menu: HaloMenuState(project: nil), pasteRefusal: refusal)
        #expect(HaloEditMenuSpecs.paste.availability(none) == .unavailable(HaloMenuState.noWindow))
    }

    @Test func copyFrameFollowsTheCatalog() {
        let open = HaloEditMenuSpecs(menu: HaloMenuState(project: comp()), pasteRefusal: nil)
        #expect(HaloEditMenuSpecs.copyFrame.availability(open) == open.menu.availability("edit.copy-frame"))
        let none = HaloEditMenuSpecs(menu: HaloMenuState(project: nil), pasteRefusal: nil)
        #expect(HaloEditMenuSpecs.copyFrame.availability(none) == .unavailable(HaloMenuState.noWindow))
    }

    @Test func cutCopyAndSelectAllAreOffWithWhy() {
        let open = HaloEditMenuSpecs(menu: HaloMenuState(project: comp()), pasteRefusal: nil)
        for (id, title) in [("edit.cut", "Cut"), ("edit.copy", "Copy"), ("edit.select-all", "Select All")] {
            let spec = HaloEditMenuSpecs.textOnly(id, title: title)
            #expect(spec.title == title)
            #expect(spec.availability(open) == .unavailable(HaloEditMenuSpecs.textOnly))
        }
    }
}
